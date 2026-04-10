variable "cluster_name" { type = string }
variable "node_group_name" { type = string }
variable "tags" { type = map(string) }

locals {
  iam_path = "/sentinel/"
}

data "aws_iam_policy_document" "fis_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["fis.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fis" {
  name               = "${var.cluster_name}-fis"
  path               = local.iam_path
  assume_role_policy = data.aws_iam_policy_document.fis_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "fis_eks" {
  role       = aws_iam_role.fis.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "fis_ec2" {
  role       = aws_iam_role.fis.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Spot instance termination experiment — validates node remediation Lambda
resource "aws_fis_experiment_template" "spot_termination" {
  description = "Terminate a random spot node to validate self-healing Lambda"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "terminate-spot-node"
    action_id = "aws:ec2:terminate-instances"

    target {
      key   = "Instances"
      value = "spot-nodes"
    }
  }

  target {
    name           = "spot-nodes"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "kubernetes.io/cluster/${var.cluster_name}"
      value = "owned"
    }

    resource_tag {
      key   = "eks:nodegroup-name"
      value = var.node_group_name
    }

    filter {
      path   = "State.Name"
      values = ["running"]
    }
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-spot-termination" })
}

# Memory pressure experiment — validates that Karpenter scales out before OOM
resource "aws_fis_experiment_template" "memory_pressure" {
  description = "Inject memory stress on a node to validate Karpenter scale-out"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "memory-stress"
    action_id = "aws:ssm:send-command"

    parameter {
      key   = "documentArn"
      value = "arn:aws:ssm:us-east-1::document/AWSFIS-Run-Memory-Stress"
    }

    parameter {
      key   = "documentParameters"
      value = jsonencode({ DurationSeconds = "120", Workers = "4", Percent = "80" })
    }

    parameter {
      key   = "duration"
      value = "PT3M"
    }

    target {
      key   = "Instances"
      value = "general-nodes"
    }
  }

  target {
    name           = "general-nodes"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "eks:nodegroup-name"
      value = var.node_group_name
    }
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-memory-pressure" })
}

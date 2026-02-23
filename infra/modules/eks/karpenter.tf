# Karpenter controller — Pod Identity grants EC2/pricing/SSM permissions at runtime.
# The karpenter.sh/discovery tag on the general node group (set in main.tf) is how
# Karpenter discovers which instances it is allowed to manage.

# --- Controller IAM ---

resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = local.tags
}

resource "aws_iam_policy" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
        ]
        Resource = "*"
      },
      {
        Sid      = "Pricing"
        Effect   = "Allow"
        Action   = ["pricing:GetProducts"]
        Resource = "*"
      },
      {
        Sid    = "SSM"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        # Scoped to EKS optimised AMI parameters only
        Resource = "arn:aws:ssm:*:*:parameter/aws/service/eks/optimized-ami/*"
      },
      {
        Sid    = "PassNodeRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        # Karpenter passes the node role to EC2 when launching instances
        Resource = aws_iam_role.node_group.arn
        Condition = {
          StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" }
        }
      },
      {
        Sid    = "InterruptionQueue"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}

# Instance profile so Karpenter-provisioned nodes can assume the node IAM role.
# Managed node groups create their own profiles automatically; Karpenter needs one explicitly.
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node"
  role = aws_iam_role.node_group.name
}

# --- Spot Interruption Queue ---

resource "aws_sqs_queue" "karpenter_interruption" {
  name = "${var.cluster_name}-karpenter-interruption"

  # 5 minutes — interruption notices are only actionable for a brief window
  message_retention_seconds = 300

  tags = local.tags
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# --- EventBridge Rules ---
# Karpenter watches this queue and drains the node gracefully before AWS terminates it.

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "EC2 Spot Instance interruption warning"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${var.cluster_name}-karpenter-rebalance"
  description = "EC2 Instance Rebalance Recommendation"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule = aws_cloudwatch_event_rule.karpenter_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state" {
  name        = "${var.cluster_name}-karpenter-instance-state"
  description = "EC2 Instance State-change Notification"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Instance State-change Notification"]
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state" {
  rule = aws_cloudwatch_event_rule.karpenter_instance_state.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  name        = "${var.cluster_name}-karpenter-scheduled-change"
  description = "AWS Health EC2 scheduled maintenance event"

  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
    detail = {
      service           = ["EC2"]
      eventTypeCategory = ["scheduledChange"]
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  rule = aws_cloudwatch_event_rule.karpenter_scheduled_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # sentinel/ IAM path prefix — all remediation roles grouped for audit visibility
  iam_path            = "/sentinel/"
  ssm_remediation_key = "/${var.environment}/${var.project}/remediation/nodes"
  ssm_advice_key      = "/${var.environment}/${var.project}/advice/scaling"
  ssm_savings_key     = "/${var.environment}/${var.project}/savings"
}

# --- IAM ---

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node_remediation" {
  name               = "${var.cluster_name}-node-remediation"
  path               = local.iam_path
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "node_remediation_basic" {
  role       = aws_iam_role.node_remediation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "node_remediation" {
  name = "${var.cluster_name}-node-remediation"
  path = local.iam_path

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EKS"
        Effect   = "Allow"
        Action   = ["eks:DescribeNodegroup", "eks:UpdateNodegroupConfig"]
        Resource = "arn:aws:eks:*:*:nodegroup/${var.cluster_name}/${var.node_group_name}/*"
      },
      {
        Sid    = "CloudTrail"
        Effect = "Allow"
        Action = ["cloudtrail:LookupEvents"]
        Resource = "*"
      },
      {
        Sid    = "SSM"
        Effect = "Allow"
        Action = ["ssm:PutParameter", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter${local.ssm_remediation_key}/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_remediation" {
  role       = aws_iam_role.node_remediation.name
  policy_arn = aws_iam_policy.node_remediation.arn
}

resource "aws_iam_role" "scaling_advisor" {
  name               = "${var.cluster_name}-scaling-advisor"
  path               = local.iam_path
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "scaling_advisor_basic" {
  role       = aws_iam_role.scaling_advisor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "scaling_advisor" {
  name = "${var.cluster_name}-scaling-advisor"
  path = local.iam_path

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SSM"
      Effect = "Allow"
      Action = ["ssm:PutParameter", "ssm:GetParameter"]
      Resource = "arn:aws:ssm:*:*:parameter${local.ssm_advice_key}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "scaling_advisor" {
  role       = aws_iam_role.scaling_advisor.name
  policy_arn = aws_iam_policy.scaling_advisor.arn
}

# --- Lambda Functions ---

data "archive_file" "node_remediation" {
  type        = "zip"
  source_dir  = "${path.root}/../../../lambda/node_remediation"
  output_path = "${path.module}/.build/node_remediation.zip"
}

data "archive_file" "scaling_advisor" {
  type        = "zip"
  source_dir  = "${path.root}/../../../lambda/scaling_advisor"
  output_path = "${path.module}/.build/scaling_advisor.zip"
}

resource "aws_lambda_function" "node_remediation" {
  function_name    = "${var.cluster_name}-node-remediation"
  role             = aws_iam_role.node_remediation.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.node_remediation.output_path
  source_code_hash = data.archive_file.node_remediation.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      CLUSTER_NAME          = var.cluster_name
      NODE_GROUP_NAME       = var.node_group_name
      SSM_REMEDIATION_KEY   = local.ssm_remediation_key
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "scaling_advisor" {
  function_name    = "${var.cluster_name}-scaling-advisor"
  role             = aws_iam_role.scaling_advisor.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.scaling_advisor.output_path
  source_code_hash = data.archive_file.scaling_advisor.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      CLUSTER_NAME    = var.cluster_name
      SSM_ADVICE_KEY  = local.ssm_advice_key
    }
  }

  tags = local.tags
}

# --- EventBridge Rules ---

resource "aws_cloudwatch_event_rule" "node_not_ready" {
  name        = "${var.cluster_name}-node-not-ready"
  description = "EKS node NotReady event — triggers remediation Lambda"

  event_pattern = jsonencode({
    source      = ["aws.eks"]
    "detail-type" = ["EKS Managed Node Group Health Issue"]
    detail = {
      issueCode = ["NodeCreationFailure", "NodeTerminationFailure"]
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "node_remediation" {
  rule = aws_cloudwatch_event_rule.node_not_ready.name
  arn  = aws_lambda_function.node_remediation.arn
}

resource "aws_lambda_permission" "node_remediation_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.node_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.node_not_ready.arn
}

resource "aws_cloudwatch_event_rule" "alarm_state_change" {
  name        = "${var.cluster_name}-alarm-state-change"
  description = "CloudWatch alarm state change — triggers scaling advisor"

  event_pattern = jsonencode({
    source        = ["aws.cloudwatch"]
    "detail-type" = ["CloudWatch Alarm State Change"]
    detail = {
      state = { value = ["ALARM"] }
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "scaling_advisor" {
  rule = aws_cloudwatch_event_rule.alarm_state_change.name
  arn  = aws_lambda_function.scaling_advisor.arn
}

resource "aws_lambda_permission" "scaling_advisor_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scaling_advisor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarm_state_change.arn
}

# --- Spot Savings Report ---

resource "aws_iam_role" "spot_savings" {
  name               = "${var.cluster_name}-spot-savings"
  path               = local.iam_path
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "spot_savings_basic" {
  role       = aws_iam_role.spot_savings.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "spot_savings" {
  name = "${var.cluster_name}-spot-savings"
  path = local.iam_path

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CostExplorer"
        Effect = "Allow"
        Action = ["ce:GetCostAndUsage"]
        Resource = "*"
      },
      {
        Sid    = "SSM"
        Effect = "Allow"
        Action = ["ssm:PutParameter", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter${local.ssm_savings_key}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "spot_savings" {
  role       = aws_iam_role.spot_savings.name
  policy_arn = aws_iam_policy.spot_savings.arn
}

data "archive_file" "spot_savings" {
  type        = "zip"
  source_dir  = "${path.root}/../../../lambda/spot_savings"
  output_path = "${path.module}/.build/spot_savings.zip"
}

resource "aws_lambda_function" "spot_savings" {
  function_name    = "${var.cluster_name}-spot-savings"
  role             = aws_iam_role.spot_savings.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.spot_savings.output_path
  source_code_hash = data.archive_file.spot_savings.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      CLUSTER_NAME    = var.cluster_name
      SSM_SAVINGS_KEY = local.ssm_savings_key
    }
  }

  tags = local.tags
}

resource "aws_scheduler_schedule" "spot_savings_weekly" {
  name       = "${var.cluster_name}-spot-savings-weekly"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  # Every Monday at 08:00 UTC
  schedule_expression = "cron(0 8 ? * MON *)"

  target {
    arn      = aws_lambda_function.spot_savings.arn
    role_arn = aws_iam_role.spot_savings.arn
    input    = jsonencode({ source = "scheduler" })
  }
}

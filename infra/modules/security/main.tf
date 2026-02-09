locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  secret_prefix = "/${var.environment}/${var.project}"
}

# --- GuardDuty ---

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    kubernetes {
      audit_logs { enable = true }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes { enable = true }
      }
    }
  }

  tags = local.tags
}

# EKS Runtime Monitoring deploys a GuardDuty DaemonSet — ensure system node group
# has capacity before this runs. EKS_ADDON_MANAGEMENT lets GuardDuty manage its own agent.
resource "aws_guardduty_detector_feature" "runtime_monitoring" {
  detector_id = aws_guardduty_detector.main.id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}

# --- Secrets Manager ---
# Shell resources only — secret values are populated out-of-band, never via Terraform.
# ESO pulls live values from here at runtime.

resource "aws_secretsmanager_secret" "argocd_admin" {
  name                    = "${local.secret_prefix}/argocd/admin-password"
  description             = "ArgoCD initial admin password — rotated via Secrets Manager, read by ESO"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn

  tags = local.tags
}

resource "aws_secretsmanager_secret" "github_oauth" {
  name                    = "${local.secret_prefix}/argocd/github-oauth"
  description             = "GitHub OAuth client secret for ArgoCD SSO"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn

  tags = local.tags
}

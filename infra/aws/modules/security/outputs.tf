output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}

output "argocd_admin_secret_arn" {
  value = aws_secretsmanager_secret.argocd_admin.arn
}

output "github_oauth_secret_arn" {
  value = aws_secretsmanager_secret.github_oauth.arn
}

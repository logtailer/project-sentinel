variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "gitops_repo_url" {
  type        = string
  description = "HTTPS URL of the GitOps repo — ArgoCD pulls manifests from here"
}

variable "github_org" {
  type        = string
  description = "GitHub org or username — used for Dex connector and RBAC policy"
}

variable "argocd_hostname" {
  type        = string
  description = "Hostname ArgoCD is reachable at — used in the Dex redirect URL"
}

variable "github_oauth_client_id" {
  type        = string
  description = "GitHub OAuth App client ID for ArgoCD SSO"
}

variable "github_oauth_secret_arn" {
  type        = string
  description = "Secrets Manager ARN containing the GitHub OAuth client secret"
}

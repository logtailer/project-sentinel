variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to reach the EKS public endpoint — set to your VPN or home IP"
}

variable "gitops_repo_url" {
  type        = string
  description = "HTTPS URL of the project-sentinel GitHub repo"
}

variable "github_org" {
  type        = string
  description = "GitHub org or username for ArgoCD SSO and RBAC"
}

variable "argocd_hostname" {
  type        = string
  description = "Hostname ArgoCD will be reachable at (used in Dex redirect URL)"
}

variable "github_oauth_client_id" {
  type        = string
  description = "GitHub OAuth App client ID for ArgoCD SSO — not a secret"
}

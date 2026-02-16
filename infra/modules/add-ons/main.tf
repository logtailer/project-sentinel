data "aws_secretsmanager_secret_version" "github_oauth" {
  secret_id = var.github_oauth_secret_arn
}

# --- ArgoCD ---
# Helm installs ArgoCD and its CRDs. The root Application below then points ArgoCD
# at the GitOps repo so it manages everything else from that point on.
#
# Two-phase apply:
#   Phase 1 — terraform apply: EKS cluster created, ArgoCD deployed via helm_release
#   Phase 2 — terraform apply: kubernetes_manifest creates root Application now that
#              the argoproj.io CRDs exist in the cluster

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.4.5"
  namespace        = "argocd"
  create_namespace = true

  # wait=true ensures the ArgoCD CRDs are registered before kubernetes_manifest runs
  wait    = true
  timeout = 600

  values = [templatefile("${path.module}/argocd-values.yaml.tpl", {
    github_org      = var.github_org
    argocd_hostname = var.argocd_hostname
    oidc_client_id  = var.github_oauth_client_id
  })]

  set_sensitive {
    name  = "configs.secret.dex\\.github\\.clientSecret"
    value = data.aws_secretsmanager_secret_version.github_oauth.secret_string
  }
}

# The ONE ArgoCD Application that Terraform manages. All other Applications and
# ApplicationSets are discovered from gitops/bootstrap/ by this root App.
resource "kubernetes_manifest" "argocd_root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root"
      namespace = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = "main"
        path           = "gitops/bootstrap"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}

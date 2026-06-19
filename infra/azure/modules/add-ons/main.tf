terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.4.5"
  namespace        = "argocd"
  create_namespace = true

  values = [templatefile("${path.module}/argocd-values.yaml.tpl", {
    argocd_hostname        = var.argocd_hostname
    eso_client_id          = var.eso_identity_client_id
  })]
}

resource "kubectl_manifest" "root_app" {
  yaml_body = templatefile("${path.module}/root-app.yaml.tpl", {
    gitops_repo_url = var.gitops_repo_url
  })

  depends_on = [helm_release.argocd]
}

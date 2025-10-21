provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "hostaway"
}

locals {
  envs = ["prd-internal", "prd-external", "stg-internal", "stg-external", "argocd"]
}

resource "kubernetes_namespace" "envs" {
  for_each = toset(local.envs)

  metadata {
    name = each.value
  }
}
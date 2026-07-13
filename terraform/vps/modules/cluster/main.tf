locals {
  application_namespaces = toset([
    "fcs-identity",
    "fcs-campaigns",
    "fcs-donations",
    "fcs-donation-worker",
    "fcs-audit-logs"
  ])
}

resource "kubernetes_namespace_v1" "infra" {
  metadata {
    name = "fcs-infra"
    labels = {
      "app.kubernetes.io/part-of" = "fcs"
      "environment"               = "vps"
    }
  }
}

resource "kubernetes_namespace_v1" "infisical" {
  metadata {
    name = "infisical-operator-system"
  }
}

resource "kubernetes_namespace_v1" "application" {
  for_each = local.application_namespaces

  metadata {
    name = each.value
    labels = {
      "app.kubernetes.io/part-of" = "fcs"
      "environment"               = "vps"
    }
  }
}

resource "helm_release" "traefik" {
  name       = "fcs-traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "41.0.2"
  namespace  = "kube-system"

  values = [yamlencode({
    providers = {
      kubernetesIngress = { enabled = true }
      kubernetesCRD     = { enabled = true }
    }
    service = {
      type = "LoadBalancer"
    }
    ingressClass = {
      enabled        = true
      isDefaultClass = true
      name           = "fcs-traefik"
    }
    ports = {
      web = {
        port        = 8000
        exposedPort = 80
        expose      = { default = true }
      }
      websecure = {
        port        = 8443
        exposedPort = 443
        expose      = { default = true }
      }
    }
  })]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.20.3"
  namespace        = "cert-manager"
  create_namespace = true

  values = [yamlencode({ crds = { enabled = true } })]
}

resource "helm_release" "infisical_operator" {
  name       = "infisical-secrets-operator"
  repository = "https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/"
  chart      = "secrets-operator"
  version    = var.infisical_operator_chart_version
  namespace  = kubernetes_namespace_v1.infisical.metadata[0].name

  values = [yamlencode({
    # The shared InfisicalConnection and InfisicalAuth live with the operator,
    # while the synced secrets live in the FCS namespaces.
    scopedNamespaces = concat(["infisical-operator-system", "fcs-infra"], sort(tolist(local.application_namespaces)))
    scopedRBAC       = true
    installCRDs      = true
  })]
}

locals {
  manifest_directory = "${path.root}/manifests"
  manifest_files     = fileset(local.manifest_directory, "*.yaml")

  documents = flatten([
    for filename in local.manifest_files : [
      for document in split("\n---\n", trimspace(replace(file("${local.manifest_directory}/${filename}"), "\r\n", "\n"))) : yamldecode(document)
    ]
  ])

  manifests = {
    for manifest in local.documents :
    "${manifest.kind}-${try(manifest.metadata.namespace, "cluster")}-${manifest.metadata.name}" => manifest
  }
}

resource "kubernetes_manifest" "platform" {
  for_each = local.manifests

  manifest = each.value

  depends_on = [
    kubernetes_manifest.infisical_connection,
    kubernetes_manifest.infisical_auth,
    kubernetes_manifest.platform_runtime,
    kubernetes_manifest.datadog_api_key,
    kubernetes_manifest.database_admin_ui_credentials,
    kubernetes_manifest.developer_portal_minio
  ]
}

resource "kubernetes_manifest" "infisical_connection" {
  manifest = {
    apiVersion = "secrets.infisical.com/v1beta1"
    kind       = "InfisicalConnection"
    metadata = {
      name      = "infisical-cloud"
      namespace = "infisical-operator-system"
    }
    spec = { address = "https://app.infisical.com" }
  }
}

resource "kubernetes_manifest" "letsencrypt" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt-production" }
    spec = {
      acme = {
        email               = var.acme_email
        server              = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = { name = "letsencrypt-production-account" }
        solvers             = [{ http01 = { ingress = { ingressClassName = "fcs-traefik" } } }]
      }
    }
  }
}

resource "kubernetes_manifest" "infisical_auth" {
  manifest = {
    apiVersion = "secrets.infisical.com/v1beta1"
    kind       = "InfisicalAuth"
    metadata = {
      name      = "fcs-platform-auth"
      namespace = "infisical-operator-system"
    }
    spec = {
      infisicalConnectionRef = {
        name      = "infisical-cloud"
        namespace = "infisical-operator-system"
      }
      method = "universal"
      universal = {
        clientIdRef = {
          name      = "infisical-universal-auth"
          namespace = "infisical-operator-system"
          key       = "clientId"
        }
        clientSecretRef = {
          name      = "infisical-universal-auth"
          namespace = "infisical-operator-system"
          key       = "clientSecret"
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.infisical_connection]
}

resource "kubernetes_manifest" "platform_runtime" {
  manifest = {
    apiVersion = "secrets.infisical.com/v1beta1"
    kind       = "InfisicalStaticSecret"
    metadata = {
      name      = "fcs-infra-runtime"
      namespace = "fcs-infra"
    }
    spec = {
      infisicalAuthRef = {
        name      = "fcs-platform-auth"
        namespace = "infisical-operator-system"
      }
      syncOptions = { refreshInterval = "5m", instantUpdates = false }
      sources = [{
        projectSlug     = var.infisical_project_slug
        environmentSlug = var.infisical_environment_slug
        secretPath      = "/platform"
      }]
      targets = [{
        name           = "fcs-infra-runtime"
        namespace      = "fcs-infra"
        kind           = "Secret"
        creationPolicy = "Owner"
      }]
    }
  }

  depends_on = [kubernetes_manifest.infisical_auth]
}

resource "kubernetes_manifest" "datadog_api_key" {
  manifest = {
    apiVersion = "secrets.infisical.com/v1beta1"
    kind       = "InfisicalStaticSecret"
    metadata = {
      name      = "fcs-datadog-api-key"
      namespace = "fcs-infra"
    }
    spec = {
      infisicalAuthRef = {
        name      = "fcs-platform-auth"
        namespace = "infisical-operator-system"
      }
      syncOptions = { refreshInterval = "5m", instantUpdates = false }
      sources = [{
        projectSlug     = var.infisical_project_slug
        environmentSlug = var.infisical_environment_slug
        secretPath      = "/observability"
      }]
      targets = [{
        name           = "fcs-datadog-api-key"
        namespace      = "fcs-infra"
        kind           = "Secret"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v1"
          data          = { "api-key" = "{{ .DATADOG_API_KEY.Value }}" }
        }
      }]
    }
  }

  depends_on = [kubernetes_manifest.infisical_auth]
}

resource "kubernetes_manifest" "database_admin_ui_credentials" {
  manifest = {
    apiVersion = "secrets.infisical.com/v1beta1"
    kind       = "InfisicalStaticSecret"
    metadata = {
      name      = "fcs-database-admin-ui-credentials"
      namespace = "fcs-infra"
    }
    spec = {
      infisicalAuthRef = {
        name      = "fcs-platform-auth"
        namespace = "infisical-operator-system"
      }
      syncOptions = { refreshInterval = "5m", instantUpdates = false }
      sources = [{
        projectSlug     = var.infisical_project_slug
        environmentSlug = var.infisical_environment_slug
        secretPath      = "/platform"
      }]
      targets = [{
        name           = "fcs-database-admin-ui-credentials"
        namespace      = "fcs-infra"
        kind           = "Secret"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v1"
          data = {
            "cloudbeaver-admin-password" = "{{ .CLOUDBEAVER_ADMIN_PASSWORD.Value }}"
            "mongo-express-password"     = "{{ .MONGO_EXPRESS_PASSWORD.Value }}"
          }
        }
      }]
    }
  }

  depends_on = [kubernetes_manifest.infisical_auth]
}

resource "kubernetes_manifest" "developer_portal_minio" {
  manifest = {
    apiVersion = "secrets.infisical.com/v1beta1"
    kind       = "InfisicalStaticSecret"
    metadata = {
      name      = "developer-portal-minio"
      namespace = "fcs-developer-portal"
    }
    spec = {
      infisicalAuthRef = {
        name      = "fcs-platform-auth"
        namespace = "infisical-operator-system"
      }
      syncOptions = { refreshInterval = "5m", instantUpdates = false }
      sources = [{
        projectSlug     = var.infisical_project_slug
        environmentSlug = var.infisical_environment_slug
        secretPath      = "/developer-portal"
      }]
      targets = [{
        name           = "developer-portal-minio"
        namespace      = "fcs-developer-portal"
        kind           = "Secret"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v1"
          data = {
            MINIO_ROOT_USER           = "{{ secretFrom \"/developer-portal\" \"minio-root-user\" }}"
            MINIO_ROOT_PASSWORD       = "{{ secretFrom \"/developer-portal\" \"minio-root-password\" }}"
            MINIO_TECHDOCS_ACCESS_KEY = "{{ secretFrom \"/developer-portal\" \"minio-techdocs-access-key\" }}"
            MINIO_TECHDOCS_SECRET_KEY = "{{ secretFrom \"/developer-portal\" \"minio-techdocs-secret-key\" }}"
          }
        }
      }]
    }
  }

  depends_on = [kubernetes_manifest.infisical_auth]
}

resource "helm_release" "datadog" {
  name       = "fcs-datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "3.228.0"
  namespace  = "fcs-infra"

  values = [yamlencode({
    datadog = {
      apiKeyExistingSecret    = "fcs-datadog-api-key"
      site                    = "us5.datadoghq.com"
      clusterName             = "fcs-vps-k3s"
      tags                    = ["env:production", "environment:vps", "platform:fcs", "cluster:fcs-vps-k3s"]
      logs                    = { enabled = false, containerCollectAll = false }
      apm                     = { socketEnabled = false, portEnabled = false }
      processAgent            = { processCollection = false, containerCollection = true }
      kubeStateMetricsEnabled = false
      kubeStateMetricsCore    = { enabled = true }
      orchestratorExplorer    = { enabled = true }
      prometheusScrape        = { enabled = false, serviceEndpoints = false }
    }
    clusterAgent = { enabled = true, replicas = 1 }
    agents = {
      containers = {
        agent = {
          resources = {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }
        }
      }
    }
  })]

  depends_on = [kubernetes_manifest.datadog_api_key]
}

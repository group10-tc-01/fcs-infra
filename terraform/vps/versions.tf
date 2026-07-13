terraform {
  required_version = "~> 1.14"

  # The organization and workspace are supplied as backend configuration by CI.
  # Keeping this block partial prevents an HCP organization name from being
  # committed to the repository.
  backend "remote" {}

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    hostinger = {
      source  = "hostinger/hostinger"
      version = "0.1.22"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

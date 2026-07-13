module "host" {
  source = "./modules/host"

  enabled           = true
  vps_host          = var.vps_host
  vps_ssh_user      = var.vps_ssh_user
  vps_deploy_user   = var.vps_deploy_user
  vps_private_key   = var.vps_ssh_private_key
  domain            = var.domain
  k3s_version       = var.k3s_version
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
}

module "cluster" {
  count  = var.apply_cluster ? 1 : 0
  source = "./modules/cluster"

  infisical_operator_chart_version = var.infisical_operator_chart_version

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  depends_on = [module.host]
}

module "platform" {
  count  = var.apply_platform ? 1 : 0
  source = "./modules/platform"

  domain                     = var.domain
  acme_email                 = var.acme_email
  infisical_project_slug     = var.infisical_project_slug
  infisical_environment_slug = var.infisical_environment_slug

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  depends_on = [module.cluster]
}

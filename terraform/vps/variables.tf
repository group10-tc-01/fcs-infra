variable "hostinger_api_token" {
  description = "Hostinger API token. It is accepted only from CI and is never stored in state."
  type        = string
  sensitive   = true
}

variable "vps_host" {
  description = "Stable public IP or hostname of the retained Hostinger VPS."
  type        = string
}

variable "vps_ssh_user" {
  description = "Temporary administrative SSH user available after the hPanel re-image."
  type        = string
  default     = "root"
}

variable "vps_deploy_user" {
  description = "Least-privilege SSH user created by the bootstrap and used by CI after K3s is available."
  type        = string
  default     = "fcs-vps-deployer"
}

variable "vps_ssh_private_key" {
  description = "Dedicated bootstrap SSH private key from the GitHub production environment."
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Base domain that already resolves to the retained VPS IP."
  type        = string
  default     = "flaviojcf.com.br"
}

variable "k3s_version" {
  description = "Pinned K3s release installed by the host bootstrap."
  type        = string
  default     = "v1.34.1+k3s1"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig copied through the temporary SSH tunnel."
  type        = string
  default     = ".kube/fcs-vps.yaml"
}

variable "apply_cluster" {
  description = "Apply K3s foundation releases after the host bootstrap has completed."
  type        = bool
  default     = false
}

variable "apply_platform" {
  description = "Apply FCS platform manifests after the cluster and Infisical bootstrap are ready."
  type        = bool
  default     = false

  validation {
    condition     = !var.apply_platform || var.apply_cluster
    error_message = "apply_platform requires apply_cluster to be true."
  }
}

variable "acme_email" {
  description = "Email registered with Let's Encrypt. Required when apply_platform is true."
  type        = string
  default     = null
}

variable "infisical_project_slug" {
  description = "Production Infisical project slug that contains the platform secrets."
  type        = string
  default     = "fcs-platform"
}

variable "infisical_environment_slug" {
  description = "Infisical environment slug used by the VPS."
  type        = string
  default     = "prod"
}

variable "infisical_operator_chart_version" {
  description = "Pinned Infisical secrets-operator chart version selected during bootstrap."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to access SSH. GitHub-hosted runners need 0.0.0.0/0 unless a static egress or self-hosted runner is used."
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.ssh_allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every SSH allow-list entry must be a valid CIDR."
  }
}

variable "enabled" { type = bool }
variable "vps_host" { type = string }
variable "vps_ssh_user" { type = string }
variable "vps_deploy_user" { type = string }
variable "vps_private_key" {
  type      = string
  sensitive = true
}
variable "domain" { type = string }
variable "k3s_version" { type = string }
variable "ssh_allowed_cidrs" { type = list(string) }

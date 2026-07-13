variable "domain" { type = string }
variable "acme_email" {
  type     = string
  nullable = false
}
variable "infisical_project_slug" { type = string }
variable "infisical_environment_slug" { type = string }

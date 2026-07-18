output "vps_host" {
  value       = var.vps_host
  description = "Stable public address of the FCS VPS."
}

output "public_endpoint" {
  value       = "https://fcs-web.${var.domain}"
  description = "Public FCS web endpoint after the Traefik rollout."
}

output "platform_namespaces" {
  value       = ["fcs-infra", "fcs-identity", "fcs-campaigns", "fcs-donations", "fcs-donation-worker", "fcs-audit-logs", "fcs-notifications"]
  description = "Namespaces reserved for the FCS platform and applications."
}

output "cluster_foundation_enabled" {
  value       = var.apply_cluster
  description = "Whether the Helm-managed K3s foundation is included in this run."
}

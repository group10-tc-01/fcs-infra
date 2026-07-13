resource "terraform_data" "bootstrap" {
  count = var.enabled ? 1 : 0

  triggers_replace = {
    script_sha        = filesha256("${path.module}/scripts/bootstrap-host.sh")
    k3s_version       = var.k3s_version
    domain            = var.domain
    ssh_allowed_cidrs = join(",", var.ssh_allowed_cidrs)
    deploy_user       = var.vps_deploy_user
  }

  connection {
    type        = "ssh"
    host        = var.vps_host
    user        = var.vps_ssh_user
    private_key = var.vps_private_key
  }

  provisioner "file" {
    source      = "${path.module}/scripts/bootstrap-host.sh"
    destination = "/tmp/fcs-bootstrap-host.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0700 /tmp/fcs-bootstrap-host.sh",
      "sudo /tmp/fcs-bootstrap-host.sh '${var.k3s_version}' '${var.domain}' '${join(",", var.ssh_allowed_cidrs)}' '${var.vps_deploy_user}'",
      "rm -f /tmp/fcs-bootstrap-host.sh"
    ]
  }
}

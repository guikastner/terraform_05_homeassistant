resource "null_resource" "main_network" {
  triggers = {
    name = local.network_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      bash -lc 'docker network inspect "${self.triggers.name}" >/dev/null 2>&1 || docker network create --driver bridge --internal "${self.triggers.name}" >/dev/null'
    EOT
  }
}

resource "docker_image" "home_assistant" {
  name         = var.home_assistant_image
  keep_locally = true
}

resource "docker_image" "node_red" {
  name         = var.node_red_image
  keep_locally = true
}

resource "docker_image" "homebridge" {
  count        = var.homebridge_enabled ? 1 : 0
  name         = var.homebridge_image
  keep_locally = true
}

resource "docker_image" "cloudflared" {
  name         = var.cloudflared_image
  keep_locally = true
}

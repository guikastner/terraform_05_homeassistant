resource "null_resource" "home_assistant_data_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.home_assistant_data_dir}"
  }
}

resource "null_resource" "node_red_data_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.node_red_data_dir}"
  }
}

resource "null_resource" "homebridge_data_dir" {
  count = var.homebridge_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "mkdir -p ${local.homebridge_data_dir}"
  }
}

# Optional cleanup resources controlled by delete_data_on_destroy
resource "null_resource" "home_assistant_data_dir_cleanup" {
  count = var.delete_data_on_destroy ? 1 : 0

  triggers = {
    path = local.home_assistant_data_dir
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      bash -lc 'set -eu
      if [ -d "${self.triggers.path}" ]; then
        docker run --rm -v "${self.triggers.path}:/target" alpine:3.22 sh -c "rm -rf /target/* /target/.[!.]* /target/..?* 2>/dev/null || true"
        rmdir "${self.triggers.path}" 2>/dev/null || true
      fi'
    EOT
  }
}

resource "null_resource" "node_red_data_dirs_cleanup" {
  count = var.delete_data_on_destroy ? 1 : 0

  triggers = {
    path = local.node_red_data_dir
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      bash -lc 'set -eu
      if [ -d "${self.triggers.path}" ]; then
        docker run --rm -v "${self.triggers.path}:/target" alpine:3.22 sh -c "rm -rf /target/* /target/.[!.]* /target/..?* 2>/dev/null || true"
        rmdir "${self.triggers.path}" 2>/dev/null || true
      fi'
    EOT
  }
}

resource "null_resource" "homebridge_data_dir_cleanup" {
  count = var.delete_data_on_destroy && var.homebridge_enabled ? 1 : 0

  triggers = {
    path = local.homebridge_data_dir
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      bash -lc 'set -eu
      if [ -d "${self.triggers.path}" ]; then
        docker run --rm -v "${self.triggers.path}:/target" alpine:3.22 sh -c "rm -rf /target/* /target/.[!.]* /target/..?* 2>/dev/null || true"
        rmdir "${self.triggers.path}" 2>/dev/null || true
      fi'
    EOT
  }
}

resource "null_resource" "generated_dirs_cleanup" {
  count = var.delete_data_on_destroy ? 1 : 0

  triggers = {
    home_assistant_generated_dir = local.home_assistant_generated_dir
    node_red_generated_dir       = local.node_red_generated_dir
    cloudflare_generated_dir     = local.cloudflare_generated_dir
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      bash -lc 'set -eu
      rm -rf "${self.triggers.home_assistant_generated_dir}"
      rm -rf "${self.triggers.node_red_generated_dir}"
      rm -rf "${self.triggers.cloudflare_generated_dir}"'
    EOT
  }
}

resource "null_resource" "node_red_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.node_red_generated_dir}"
  }
}

resource "null_resource" "node_red_admin_password_hash" {
  triggers = {
    password          = sha256(var.node_red_admin_password)
    image             = var.node_red_image
    path              = local.node_red_admin_password_hash_path
    generator_version = "v2"
  }

  provisioner "local-exec" {
    command = <<-EOT
      bash -lc 'set -euo pipefail
      docker run --rm --entrypoint bash \
        -e NODE_RED_ADMIN_PASSWORD \
        -v ${local.node_red_generated_dir}:/work \
        ${var.node_red_image} \
        -lc '"'"'set -euo pipefail
        export PATH="/usr/src/node-red/node_modules/.bin:$PATH"
        hash="$(printf "%s\n%s\n" "$NODE_RED_ADMIN_PASSWORD" "$NODE_RED_ADMIN_PASSWORD" | node-red admin hash-pw | sed -n "s/^Password: //p" | tr -d "\r")"
        test -n "$hash"
        printf "%s\n" "$hash" > /work/admin-password.hash'"'"''
    EOT

    environment = {
      NODE_RED_ADMIN_PASSWORD = var.node_red_admin_password
    }
  }

  depends_on = [null_resource.node_red_dirs]
}

data "local_file" "node_red_admin_password_hash" {
  filename   = local.node_red_admin_password_hash_path
  depends_on = [null_resource.node_red_admin_password_hash]
}

resource "local_file" "node_red_settings" {
  filename        = local.node_red_settings_path
  file_permission = "0640"
  content = templatefile(
    "${path.module}/templates/node-red-settings.js.tmpl",
    {
      admin_user        = var.node_red_admin_username
      admin_pass_hash   = trimspace(data.local_file.node_red_admin_password_hash.content)
      credential_secret = var.node_red_credential_secret
      timezone          = var.timezone
    }
  )

  depends_on = [null_resource.node_red_dirs]
}

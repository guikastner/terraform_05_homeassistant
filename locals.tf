locals {
  network_name               = var.network_name
  home_assistant_name        = "${var.name_prefix}${var.home_assistant_name}"
  node_red_name              = "${var.name_prefix}${var.node_red_name}"
  homebridge_name            = "${var.name_prefix}${var.homebridge_name}"
  home_assistant_public_host = var.home_assistant_hostname != "" ? var.home_assistant_hostname : local.home_assistant_name
  node_red_public_host       = var.node_red_hostname != "" ? var.node_red_hostname : local.node_red_name
  homebridge_public_host     = var.homebridge_hostname != "" ? var.homebridge_hostname : local.homebridge_name

  home_assistant_instance = {
    name     = local.home_assistant_name
    hostname = var.base_domain != "" ? "${local.home_assistant_public_host}.${var.base_domain}" : local.home_assistant_public_host
  }

  node_red_instance = {
    name     = local.node_red_name
    hostname = var.base_domain != "" ? "${local.node_red_public_host}.${var.base_domain}" : local.node_red_public_host
  }

  homebridge_instance = {
    name     = local.homebridge_name
    hostname = var.base_domain != "" ? "${local.homebridge_public_host}.${var.base_domain}" : local.homebridge_public_host
  }

  data_root               = "/DATA/AppData"
  home_assistant_data_dir = abspath("${local.data_root}/${local.home_assistant_name}")
  node_red_data_dir       = abspath("${local.data_root}/${local.node_red_name}")
  homebridge_data_dir     = abspath("${local.data_root}/${local.homebridge_name}")

  home_assistant_generated_dir      = abspath("${path.module}/build/home-assistant")
  home_assistant_config_path        = abspath("${local.home_assistant_generated_dir}/configuration.yaml")
  node_red_generated_dir            = abspath("${path.module}/build/node-red")
  node_red_settings_path            = abspath("${local.node_red_generated_dir}/settings.js")
  node_red_admin_password_hash_path = abspath("${local.node_red_generated_dir}/admin-password.hash")

  cloudflare_generated_dir    = abspath("${path.module}/build/cloudflare")
  cloudflare_config_path      = abspath("${local.cloudflare_generated_dir}/config.yml")
  cloudflare_credentials_path = abspath("${local.cloudflare_generated_dir}/cloudflared-credentials.json")

  homebridge_ui_service = var.homebridge_network_mode == "host" ? "http://host.docker.internal:${var.homebridge_ui_port}" : "http://${local.homebridge_instance.name}:${var.homebridge_ui_port}"

  cloudflare_ingress_rules = concat(
    [
      {
        hostname = local.home_assistant_instance.hostname
        service  = "http://${local.home_assistant_instance.name}:8123"
      },
      {
        hostname = local.node_red_instance.hostname
        service  = "http://${local.node_red_instance.name}:1880"
      },
    ],
    var.homebridge_enabled && var.homebridge_publish && var.base_domain != "" ? [
      {
        hostname = local.homebridge_instance.hostname
        service  = local.homebridge_ui_service
      }
    ] : []
  )
}

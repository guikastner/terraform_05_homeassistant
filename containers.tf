resource "docker_container" "home_assistant" {
  name     = local.home_assistant_instance.name
  image    = docker_image.home_assistant.image_id
  restart  = "unless-stopped"
  hostname = local.home_assistant_instance.name

  env = [
    "TZ=${var.timezone}",
    "DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket",
  ]

  mounts {
    target = "/config"
    source = local.home_assistant_data_dir
    type   = "bind"
  }

  mounts {
    target    = "/config/configuration.yaml"
    source    = local.home_assistant_config_path
    type      = "bind"
    read_only = true
  }

  dynamic "mounts" {
    for_each = var.home_assistant_bluetooth_enabled ? [1] : []

    content {
      target    = "/run/dbus"
      source    = var.home_assistant_dbus_host_path
      type      = "bind"
      read_only = true
    }
  }

  capabilities {
    add = var.home_assistant_capabilities_add
  }

  networks_advanced {
    name    = local.network_name
    aliases = [local.home_assistant_instance.name]
  }

  # Keep outbound internet access available while preserving private service-to-service traffic.
  networks_advanced {
    name = "bridge"
  }

  depends_on = [
    local_file.home_assistant_configuration,
    null_resource.home_assistant_data_dir,
    null_resource.home_assistant_data_files,
  ]
}

resource "docker_container" "node_red" {
  name     = local.node_red_instance.name
  image    = docker_image.node_red.image_id
  restart  = "unless-stopped"
  hostname = local.node_red_instance.name

  env = [
    "TZ=${var.timezone}"
  ]

  mounts {
    target = "/data"
    source = local.node_red_data_dir
    type   = "bind"
  }

  mounts {
    target    = "/data/settings.js"
    source    = local.node_red_settings_path
    type      = "bind"
    read_only = true
  }

  networks_advanced {
    name    = local.network_name
    aliases = [local.node_red_instance.name]
  }

  # Keep internal service communication on main network and allow outbound internet via default bridge.
  networks_advanced {
    name = "bridge"
  }

  depends_on = [
    null_resource.main_network,
    local_file.node_red_settings,
    null_resource.node_red_data_dirs,
    null_resource.node_red_modules,
  ]
}

resource "docker_container" "homebridge" {
  count        = var.homebridge_enabled ? 1 : 0
  name         = local.homebridge_instance.name
  image        = docker_image.homebridge[0].image_id
  restart      = "unless-stopped"
  hostname     = local.homebridge_instance.name
  network_mode = var.homebridge_network_mode == "host" ? "host" : null

  env = compact([
    "TZ=${var.timezone}",
    "HOMEBRIDGE_CONFIG_UI=1",
    "HOMEBRIDGE_CONFIG_UI_PORT=${var.homebridge_ui_port}",
    "HOMEBRIDGE_PORT=${var.homebridge_port}",
    var.homebridge_insecure_mode ? "HOMEBRIDGE_INSECURE=1" : null,
  ])

  mounts {
    target = "/homebridge"
    source = local.homebridge_data_dir
    type   = "bind"
  }

  dynamic "networks_advanced" {
    for_each = var.homebridge_network_mode == "shared" ? [1] : []

    content {
      name    = local.network_name
      aliases = [local.homebridge_instance.name]
    }
  }

  # Keep outbound internet access available when running in the shared Docker network.
  dynamic "networks_advanced" {
    for_each = var.homebridge_network_mode == "shared" ? [1] : []

    content {
      name = "bridge"
    }
  }

  depends_on = [
    null_resource.main_network,
    null_resource.homebridge_data_dir,
  ]
}

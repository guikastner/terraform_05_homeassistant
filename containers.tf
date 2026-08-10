resource "docker_container" "home_assistant" {
  name         = local.home_assistant_instance.name
  image        = docker_image.home_assistant.image_id
  restart      = "unless-stopped"
  hostname     = local.home_assistant_instance.name
  network_mode = var.home_assistant_network_mode == "host" ? "host" : null
  log_driver   = var.docker_log_driver
  log_opts     = var.docker_log_opts

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

  healthcheck {
    test         = ["CMD", "curl", "-fsS", "http://127.0.0.1:8123/"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "2m0s"
  }

  labels {
    label = "autoheal"
    value = "true"
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

  dynamic "networks_advanced" {
    for_each = var.home_assistant_network_mode == "shared" ? [1] : []

    content {
      name    = local.network_name
      aliases = [local.home_assistant_instance.name]
    }
  }

  # Keep outbound internet access available while preserving private service-to-service traffic.
  dynamic "networks_advanced" {
    for_each = var.home_assistant_network_mode == "shared" ? [1] : []

    content {
      name = "bridge"
    }
  }

  depends_on = [
    local_file.home_assistant_configuration,
    null_resource.home_assistant_data_dir,
    null_resource.home_assistant_data_files,
    null_resource.main_network,
  ]
}

resource "docker_container" "node_red" {
  name       = local.node_red_instance.name
  image      = docker_image.node_red.image_id
  restart    = "unless-stopped"
  hostname   = local.node_red_instance.name
  log_driver = var.docker_log_driver
  log_opts   = var.docker_log_opts

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

  healthcheck {
    test         = ["CMD", "curl", "-fsS", "http://127.0.0.1:1880/"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "1m0s"
  }

  labels {
    label = "autoheal"
    value = "true"
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
  log_driver   = var.docker_log_driver
  log_opts     = var.docker_log_opts

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

  healthcheck {
    test         = ["CMD-SHELL", "curl -fsS http://127.0.0.1:${var.homebridge_ui_port}/ >/dev/null && node -e 'const net=require(\"net\"); const cfg=require(\"/homebridge/config.json\"); const port=Number(cfg.bridge&&cfg.bridge.port); if (!port) process.exit(0); const s=net.createConnection({host:\"127.0.0.1\",port,timeout:3000},()=>{s.end();process.exit(0)}); s.on(\"timeout\",()=>{s.destroy();process.exit(1)}); s.on(\"error\",()=>process.exit(1));'"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "1m30s"
  }

  labels {
    label = "autoheal"
    value = "true"
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

resource "docker_container" "autoheal" {
  count      = var.autoheal_enabled ? 1 : 0
  name       = "${var.name_prefix}autoheal1"
  image      = docker_image.autoheal[0].image_id
  restart    = "unless-stopped"
  hostname   = "${var.name_prefix}autoheal1"
  log_driver = var.docker_log_driver
  log_opts   = var.docker_log_opts

  env = [
    "AUTOHEAL_CONTAINER_LABEL=autoheal",
    "AUTOHEAL_INTERVAL=30",
    "AUTOHEAL_START_PERIOD=120",
  ]

  mounts {
    target = "/var/run/docker.sock"
    source = "/var/run/docker.sock"
    type   = "bind"
  }
}

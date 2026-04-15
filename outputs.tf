output "service_urls" {
  description = "Direct service URLs to use after deployment."
  value = {
    home_assistant_public = var.base_domain != "" ? "https://${local.home_assistant_instance.hostname}" : null
    node_red_public       = var.base_domain != "" ? "https://${local.node_red_instance.hostname}" : null
    homebridge_public     = var.homebridge_enabled && var.homebridge_publish && var.base_domain != "" ? "https://${local.homebridge_instance.hostname}" : null
  }
}

output "service_hostnames" {
  description = "Resolved public hostnames for the published services."
  value = {
    home_assistant = local.home_assistant_instance.hostname
    node_red       = local.node_red_instance.hostname
    homebridge     = var.homebridge_enabled && var.base_domain != "" ? local.homebridge_instance.hostname : null
  }
}

output "service_container_names" {
  description = "Docker container names created for the application services."
  value = {
    home_assistant = docker_container.home_assistant.name
    node_red       = docker_container.node_red.name
    homebridge     = var.homebridge_enabled ? docker_container.homebridge[0].name : null
    cloudflared    = docker_container.cloudflared.name
  }
}

output "service_data_dirs" {
  description = "Host bind-mount directories used to persist application data."
  value = {
    home_assistant = local.home_assistant_data_dir
    node_red       = local.node_red_data_dir
    homebridge     = var.homebridge_enabled ? local.homebridge_data_dir : null
  }
}

output "network_name" {
  description = "Internal Docker network used by all services."
  value       = local.network_name
}

output "cloudflare_tunnel" {
  description = "Cloudflare Tunnel identifiers created by OpenTofu."
  value = {
    id   = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
    name = cloudflare_zero_trust_tunnel_cloudflared.tunnel.name
  }
}

output "cloudflare_generated_files" {
  description = "Generated Cloudflare configuration files written on the host."
  value = {
    config      = local.cloudflare_config_path
    credentials = local.cloudflare_credentials_path
  }
}

output "deployment_summary" {
  description = "High-level deployment summary for quick inspection after apply."
  value = {
    base_domain = var.base_domain
    services = {
      home_assistant = {
        container_name = docker_container.home_assistant.name
        hostname       = local.home_assistant_instance.hostname
      }
      node_red = {
        container_name = docker_container.node_red.name
        hostname       = local.node_red_instance.hostname
      }
      homebridge = {
        container_name = var.homebridge_enabled ? docker_container.homebridge[0].name : null
        hostname       = var.homebridge_enabled && var.base_domain != "" ? local.homebridge_instance.hostname : null
      }
    }
    cloudflare = {
      tunnel_name = cloudflare_zero_trust_tunnel_cloudflared.tunnel.name
      tunnel_id   = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
    }
  }
}

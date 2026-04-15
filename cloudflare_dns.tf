resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  account_id = var.cloudflare_tunnel.account_id
  name       = var.cloudflare_tunnel.name
  secret     = random_password.tunnel_secret.result
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel" {
  account_id = var.cloudflare_tunnel.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id

  config {
    dynamic "ingress_rule" {
      for_each = local.cloudflare_ingress_rules

      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
      }
    }
    ingress_rule { service = "http_status:404" }
  }
}

resource "cloudflare_record" "home_assistant_cname" {
  zone_id = var.cloudflare_zone_id
  name    = local.home_assistant_instance.hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnel.id}.cfargotunnel.com"
  proxied = var.cloudflare_proxied
}

resource "cloudflare_record" "node_red_cname" {
  zone_id = var.cloudflare_zone_id
  name    = local.node_red_instance.hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnel.id}.cfargotunnel.com"
  proxied = var.cloudflare_proxied
}

resource "cloudflare_record" "homebridge_cname" {
  count   = var.homebridge_enabled && var.homebridge_publish && var.base_domain != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = local.homebridge_instance.hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnel.id}.cfargotunnel.com"
  proxied = var.cloudflare_proxied
}

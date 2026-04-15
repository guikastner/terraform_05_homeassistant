variable "docker_host" {
  description = "Docker host socket URL. Keep default for local Docker engine."
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "base_domain" {
  description = "Base domain used to build Cloudflare CNAMEs for published services (e.g. example.com)."
  type        = string
  default     = ""
}

variable "timezone" {
  description = "Timezone applied to containers that support TZ."
  type        = string
  default     = "UTC"
}

variable "name_prefix" {
  description = "Optional prefix applied to all container names, hostnames, and data directories (e.g., \"lab-\")."
  type        = string
  default     = ""
}

variable "network_name" {
  description = "Docker network name used to connect all project containers."
  type        = string
}

variable "node_red_name" {
  description = "Base name for the single Node-RED container (prefix will be prepended)."
  type        = string
  default     = "node1"
}

variable "home_assistant_name" {
  description = "Base name for the Home Assistant container (prefix will be prepended)."
  type        = string
  default     = "homeassistant1"
}

variable "home_assistant_hostname" {
  description = "Optional public hostname prefix for Home Assistant. When empty, the container name is used."
  type        = string
  default     = ""
}

variable "home_assistant_trusted_proxies" {
  description = "Trusted reverse-proxy CIDRs/IPs for Home Assistant when running behind Cloudflare Tunnel."
  type        = list(string)
  default     = ["172.17.0.0/16"]
}

variable "home_assistant_image" {
  description = "Container image for Home Assistant."
  type        = string
  default     = "homeassistant/home-assistant:stable"
}

variable "home_assistant_capabilities_add" {
  description = "Linux capabilities added to the Home Assistant container for local device integrations."
  type        = list(string)
  default     = ["NET_ADMIN", "NET_RAW"]
}

variable "home_assistant_bluetooth_enabled" {
  description = "Expose host D-Bus to the Home Assistant container so BlueZ/Bluetooth integrations can talk to the host adapter."
  type        = bool
  default     = true
}

variable "home_assistant_dbus_host_path" {
  description = "Host path for the system D-Bus runtime mounted into Home Assistant when Bluetooth support is enabled."
  type        = string
  default     = "/run/dbus"
}

variable "node_red_image" {
  description = "Container image for Node-RED."
  type        = string
  default     = "nodered/node-red:4.1.4-22"
}

variable "homebridge_image" {
  description = "Container image for Homebridge."
  type        = string
  default     = "homebridge/homebridge:latest"
}

variable "homebridge_name" {
  description = "Base name for the Homebridge container (prefix will be prepended)."
  type        = string
  default     = "homebridge1"
}

variable "homebridge_hostname" {
  description = "Optional public hostname prefix for Homebridge. When empty, the container name is used."
  type        = string
  default     = ""
}

variable "homebridge_enabled" {
  description = "Create the Homebridge container and its persistent data directory."
  type        = bool
  default     = true
}

variable "homebridge_publish" {
  description = "Publish the Homebridge web UI through Cloudflare Tunnel and create a DNS record when base_domain is set."
  type        = bool
  default     = true
}

variable "homebridge_network_mode" {
  description = "Network mode for Homebridge. Use \"shared\" to join the project Docker network or \"host\" for direct LAN exposure when HomeKit discovery requires it."
  type        = string
  default     = "shared"

  validation {
    condition     = contains(["shared", "host"], var.homebridge_network_mode)
    error_message = "homebridge_network_mode must be either \"shared\" or \"host\"."
  }
}

variable "homebridge_ui_port" {
  description = "Internal Homebridge Config UI port exposed by the container."
  type        = number
  default     = 8581
}

variable "homebridge_port" {
  description = "Homebridge service port used by HomeKit accessory communication."
  type        = number
  default     = 8581
}

variable "homebridge_insecure_mode" {
  description = "Enable Homebridge insecure mode to allow the initial web UI setup without a local PIN."
  type        = bool
  default     = false
}

variable "node_red_hostname" {
  description = "Optional public hostname prefix for Node-RED. When empty, the container name is used."
  type        = string
  default     = ""
}

variable "cloudflared_image" {
  description = "Container image for Cloudflare Tunnel agent."
  type        = string
  default     = "cloudflare/cloudflared:latest"
}

variable "node_red_admin_username" {
  description = "Admin username for Node-RED editor (basic auth)."
  type        = string
  default     = "admin"
}

variable "node_red_admin_password" {
  description = "Plain-text password for the Node-RED admin user. The bcrypt hash is generated during deployment."
  type        = string
  sensitive   = true
}

variable "node_red_credential_secret" {
  description = "Secret used by Node-RED to encrypt flow credentials (credentialSecret)."
  type        = string
  default     = "credential-secret"
  sensitive   = true
}

variable "node_red_extra_modules" {
  description = "List of npm packages (names or URLs) to install into each Node-RED data dir."
  type        = list(string)
  default = [
    "https://btcc.s3.dualstack.eu-west-1.amazonaws.com/widget-lab/npm/node-red-contrib-3dxinterfaces/dist/widget-lab-node-red-contrib-3dxinterfaces-6.5.1.tgz",
    "node-red-contrib-xlsx-to-json",
  ]
}

variable "delete_data_on_destroy" {
  description = "If true, persistent bind-mount directories and generated local build artifacts are deleted on destroy."
  type        = bool
  default     = true
}

variable "cloudflare_api_token" {
  description = "API token with permissions to manage tunnels and DNS records."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID in Cloudflare where CNAMEs will be created."
  type        = string
}

variable "cloudflare_proxied" {
  description = "Whether created DNS records should be proxied by Cloudflare."
  type        = bool
  default     = true
}

variable "cloudflare_tunnel" {
  description = "Cloudflare tunnel settings and secrets."
  type = object({
    name       = string
    account_id = string
  })
}

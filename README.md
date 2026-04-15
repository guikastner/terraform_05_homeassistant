# Home Assistant / Node-RED Base Infrastructure (OpenTofu)

Infrastructure as code to provision a base stack for Home Assistant and Node-RED using OpenTofu and the Docker provider. The environment exposes both services through a Cloudflare Tunnel and keeps persistent data on local bind mounts.

## Components
- 1× Home Assistant container (`homeassistant/home-assistant:stable`): name comes from `name_prefix` + `home_assistant_name` (default `lab-homeassistant1`) and stores its config in a bind mount.
- 1× Node-RED container (`nodered/node-red:4.1.4-22`): name comes from `name_prefix` + `node_red_name` (default `lab-node1`) on port `1880` inside the private mesh.
- 1× Homebridge container (`homebridge/homebridge:latest`): optional service named from `name_prefix` + `homebridge_name` (default `lab-homebridge1`) with persistent `/homebridge` storage and optional Cloudflare publication for the web UI.
- 1× Cloudflare Tunnel agent (`cloudflare/cloudflared:latest`): default `lab-cloudflared1`, routing external hostnames to Home Assistant and Node-RED. Tunnel and DNS records are created via the Cloudflare provider.
- Internal bridge network defined by `network_name` for private inter-container traffic.
- Node-RED and Cloudflared are attached to Docker `bridge` to keep outbound connectivity while preserving private service-to-service traffic on `network_name`.
- Home Assistant joins the shared project Docker network and the default Docker `bridge` network.
- Homebridge can run either on the shared Docker network or in host mode, controlled by `homebridge_network_mode`.

## Scope of this base
- Home Assistant is exposed to users through Cloudflare.
- Node-RED remains available for automation workflows connected to Home Assistant.
- Homebridge can be exposed through Cloudflare when `homebridge_publish = true` and `base_domain` is configured.
- This is a base deployment: specific Home Assistant integrations that depend on multicast, mDNS, USB passthrough, or host networking may require additional adjustments later.

## Home Assistant
- Home Assistant runs from `homeassistant/home-assistant:stable`.
- Persistent data is stored in `/DATA/AppData/<name_prefix><home_assistant_name>`.
- `configuration.yaml` is rendered by OpenTofu and mounted read-only into `/config/configuration.yaml`.
- The generated Home Assistant config enables reverse-proxy support using `use_x_forwarded_for` and `trusted_proxies`.
- Cloudflare creates a dedicated hostname for Home Assistant through the same tunnel used by Node-RED. The public label can be overridden with `home_assistant_hostname`.
- Cloudflare reaches Home Assistant through the shared Docker network on port `8123`.
- The container adds `NET_ADMIN` and `NET_RAW` by default to improve local Bluetooth/device integrations.
- Bluetooth support is enabled by default by bind-mounting the host `dbus` runtime (`/run/dbus`) into the container and exporting `DBUS_SYSTEM_BUS_ADDRESS`, which lets Home Assistant talk to the host BlueZ adapter.

## Node-RED security
- Admin auth uses `node_red_admin_username` and the plain-text `node_red_admin_password`; the bcrypt hash is generated during deployment and written into the rendered `settings.js`.
- Credentials encryption uses `node_red_credential_secret`; override it in your `terraform.tfvars`.
- `settings.js` is rendered to `build/node-red/settings.js` from `templates/node-red-settings.js.tmpl` and mounted read-only into the Node-RED container.
- Before the Node-RED container starts, the packages defined in `node_red_extra_modules` are installed into its data directory via the Node-RED image (`npm install ...`).

## Homebridge
- Homebridge runs from `homebridge/homebridge:latest`.
- Persistent data is stored in `/DATA/AppData/<name_prefix><homebridge_name>`.
- The container mounts that directory at `/homebridge`, which keeps the Homebridge config, database, and installed plugins.
- `homebridge_network_mode = "shared"` places the container on the same Docker network as the other services and also attaches it to Docker `bridge` for outbound access.
- `homebridge_network_mode = "host"` exposes Homebridge directly on the host network, which can be necessary for some HomeKit discovery flows.
- The Config UI can be published through Cloudflare using `homebridge_publish = true`; the ingress target changes automatically depending on the selected network mode.

## Cloudflare automation
- OpenTofu creates the tunnel using only the tunnel name and account ID; the tunnel secret is generated automatically.
- Ingress rules and CNAME records are generated for the Home Assistant and Node-RED hostnames.
- Public CNAME labels are configurable through `home_assistant_hostname` and `node_red_hostname`. When empty, the container names are used.

## Prerequisites
- Docker Engine running locally and accessible via `unix:///var/run/docker.sock` (default).
- OpenTofu ≥ 1.6.2 installed (`tofu` CLI).
- Cloudflare account with permissions to create tunnels and DNS records for your domain.

## Quick start
1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in real values.
2. Initialize and review the plan:
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

## terraform.tfvars guide
Supply real values in `terraform.tfvars` (keep it out of version control). Below are the expected inputs:

| Variable | Description | Example |
| --- | --- | --- |
| `base_domain` | Base domain used to build hostnames (CNAMEs) for Home Assistant and Node-RED. | `example.com` |
| `timezone` | Timezone injected into supported containers. | `America/Sao_Paulo` |
| `name_prefix` | Optional prefix applied to all names (containers, hostnames, data dirs). | `lab-` |
| `network_name` | Docker network name shared by all containers in this project. | `lab-net` |
| `delete_data_on_destroy` | When `true`, `tofu destroy` also removes persistent bind mounts and generated local files. | `true` |
| `home_assistant_hostname` | Optional public hostname label for Home Assistant. | `homeassistant` |
| `home_assistant_trusted_proxies` | Trusted proxy CIDRs/IPs written into Home Assistant HTTP config. | `["172.17.0.0/16"]` |
| `home_assistant_bluetooth_enabled` | Mount the host `dbus` runtime into Home Assistant for Bluetooth/BlueZ integrations. | `true` |
| `home_assistant_dbus_host_path` | Host path mounted as `/run/dbus` when Bluetooth support is enabled. | `/run/dbus` |
| `node_red_admin_password` | Plain-text password for the Node-RED admin user. The hash is generated during deploy. | `change-me-too` |
| `node_red_credential_secret` | Secret to encrypt Node-RED credentials. | `set-your-own-secret` |
| `node_red_hostname` | Optional public hostname label for Node-RED. | `node-red` |
| `node_red_extra_modules` | Optional extra Node-RED packages to install. | `["node-red-contrib-xlsx-to-json"]` |
| `homebridge_enabled` | Whether Homebridge is created. | `true` |
| `homebridge_name` | Base container name for Homebridge. | `homebridge1` |
| `homebridge_hostname` | Optional public hostname label for the Homebridge UI. | `homebridge` |
| `homebridge_publish` | Publish the Homebridge UI through Cloudflare and create a CNAME. | `true` |
| `homebridge_network_mode` | `shared` to join the project Docker network, or `host` for direct LAN exposure. | `shared` |
| `homebridge_ui_port` | Homebridge Config UI port. | `8581` |
| `homebridge_port` | Homebridge service port used by the container. | `8581` |
| `homebridge_insecure_mode` | Enable insecure bootstrap mode for the Homebridge UI. | `false` |
| `cloudflare_api_token` | API token with tunnel + DNS permissions. | `CLOUDFLARE_API_TOKEN` |
| `cloudflare_zone_id` | Cloudflare Zone ID where CNAMEs are created. | `CLOUDFLARE_ZONE_ID` |
| `cloudflare_tunnel.name` | Name of the tunnel to create. | `lab-tunnel` |
| `cloudflare_tunnel.account_id` | Cloudflare account ID. | `ACCOUNT_ID_FROM_CLOUDFLARE` |

## Cloudflare settings & CNAMEs
- The tunnel is created by OpenTofu (`cloudflare_zero_trust_tunnel_cloudflared`), and DNS CNAMEs for the Home Assistant and Node-RED hostnames are created automatically via `cloudflare_record`.
- When `homebridge_publish = true`, Homebridge is added to the same tunnel config and gets its own CNAME as well.
- The agent-side config is rendered from `templates/cloudflared-config.yml.tmpl`; it builds ingress entries for both services using `base_domain`.

## Project structure
- `main.tf` / `locals.tf` / `variables.tf`: Providers, shared locals, and input variables.
- `infrastructure.tf`: Network and base images.
- `containers.tf`: Home Assistant and Node-RED containers.
- `containers.tf`: Home Assistant, Node-RED, and optional Homebridge containers.
- `home_assistant_config.tf`: Home Assistant base config generation and `/config` bootstrap files.
- `cloudflare.tf`: Cloudflare tunnel config generation and container wiring.
- `cloudflare_dns.tf`: Tunnel resource, ingress rules, and DNS records.
- `node_red_settings.tf`: Node-RED admin password hash generation and `settings.js` rendering.
- `node_red_modules.tf`: Optional Node-RED module installation before container start.
- `terraform.tfvars.example`: Sample values.

## Operational notes
- Users access Home Assistant and Node-RED through Cloudflare CNAMEs; no application port is published to the host.
- Network model:
  - Home Assistant: `network_name` (private service traffic) + `bridge` (outbound internet).
  - Node-RED: `network_name` (private service traffic) + `bridge` (outbound internet).
  - Homebridge: `network_name` + `bridge` when `homebridge_network_mode = "shared"`, or `host` when `homebridge_network_mode = "host"`.
  - Cloudflared: `network_name` + `bridge`, with `host.docker.internal` mapped to the host gateway for Home Assistant ingress.
- Moving Home Assistant off `host` networking can affect integrations that rely on LAN broadcast/mDNS/UPnP or direct host network discovery.
- Cloudflare publication of the Homebridge UI is optional and intended for administration; HomeKit accessory discovery still depends on your local network topology.
- Bluetooth on Home Assistant depends on the host OS running BlueZ and exposing the system D-Bus socket under `/run/dbus/system_bus_socket`.
- Home Assistant and Node-RED data are stored in bind mounts under `/DATA/AppData/<name>` to persist across container recreations.
- `tofu destroy` also removes those bind mounts and the generated `build/` files when `delete_data_on_destroy = true`.
- Home Assistant startup depends on OpenTofu-generated config plus placeholder include files (`automations.yaml`, `scripts.yaml`, `scenes.yaml`, `themes/`) so the first boot works without manual file creation.
- The Cloudflare container runs with `--no-autoupdate`; update the image tag in `variables.tf` to control upgrades.

## Next steps
- Provide real tunnel credentials and domain values, then run `tofu apply`.
- Complete Home Assistant post-deployment setup inside `/config`, including integrations and dashboards.
- Add Node-RED flows or additional services by extending the locals and tunnel ingress configuration.

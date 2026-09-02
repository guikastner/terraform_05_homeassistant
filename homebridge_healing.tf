resource "null_resource" "homebridge_maintenance_dir" {
  count = var.homebridge_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "mkdir -p ${local.homebridge_maintenance_dir}"
  }

  depends_on = [null_resource.homebridge_data_dir]
}

# Mounted over /defaults/avahi-daemon.conf: the image's setup script copies that
# file to /etc/avahi/avahi-daemon.conf on every container start, so this is the
# only spot where the config survives restarts. Without allow-interfaces, Avahi
# in host network mode probes every Docker bridge/veth and the constant
# interface churn keeps it stuck in "registering", so the HAP bridge is never
# announced via mDNS and HomeKit shows "No Response".
resource "local_file" "homebridge_avahi_conf" {
  count           = var.homebridge_enabled ? 1 : 0
  filename        = local.homebridge_avahi_conf
  file_permission = "0644"
  content         = <<-CONF
    [server]
    #host-name=
    allow-interfaces=${var.homebridge_avahi_allow_interfaces}
    use-ipv4=yes
    use-ipv6=no
    enable-dbus=yes
    ratelimit-interval-usec=1000000
    ratelimit-burst=1000

    [wide-area]
    enable-wide-area=yes

    [rlimits]
    rlimit-core=0
    rlimit-data=4194304
    rlimit-fsize=0
    rlimit-nofile=768
    rlimit-stack=4194304
  CONF

  depends_on = [null_resource.homebridge_maintenance_dir]
}

resource "local_file" "homebridge_androidtv_healer_script" {
  count           = var.homebridge_enabled ? 1 : 0
  filename        = local.homebridge_androidtv_healer_job
  file_permission = "0775"
  content         = <<-SCRIPT
    #!/usr/bin/env bash
    set -euo pipefail

    CONTAINER_NAME="$${CONTAINER_NAME:-${local.homebridge_instance.name}}"
    API_URL="$${API_URL:-http://127.0.0.1:8182/api/devices}"
    HOMEBRIDGE_LOG="$${HOMEBRIDGE_LOG:-${local.homebridge_data_dir}/homebridge.log}"
    STATE_DIR="$${STATE_DIR:-${local.homebridge_maintenance_dir}/androidtv-healer-state}"
    COOLDOWN_SECONDS="$${COOLDOWN_SECONDS:-1800}"
    REQUIRED_CONSECUTIVE_FAILURES="$${REQUIRED_CONSECUTIVE_FAILURES:-2}"
    LOG_TAIL_LINES="$${LOG_TAIL_LINES:-240}"
    LOG_PREFIX="[homebridge-androidtv-healer]"

    mkdir -p "$${STATE_DIR}"
    exec 9>"$${STATE_DIR}/lock"
    flock -n 9 || exit 0

    log() {
      printf '%s %s %s\n' "$${LOG_PREFIX}" "$(date -Is)" "$*"
    }

    require_cmd() {
      command -v "$1" >/dev/null 2>&1 || {
        log "missing required command: $1"
        exit 1
      }
    }

    sanitize() {
      printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_'
    }

    require_cmd curl
    require_cmd docker
    require_cmd flock
    require_cmd jq
    require_cmd nc

    if [ "$(docker inspect -f '{{.State.Running}}' "$${CONTAINER_NAME}" 2>/dev/null || true)" != "true" ]; then
      log "container $${CONTAINER_NAME} is not running; skipping"
      exit 0
    fi

    devices_json="$(curl -fsS --max-time 5 "$${API_URL}" 2>/dev/null || true)"
    if [ -z "$${devices_json}" ]; then
      log "androidtv plugin API unavailable at $${API_URL}; skipping"
      exit 0
    fi

    now="$(date +%s)"
    stuck_devices="$(printf '%s' "$${devices_json}" | jq -r '
      to_entries[]
      | select(.value.paired == true)
      | select(.value.online == true)
      | select(.value.started == true)
      | select(.value.powered == false)
      | [.value.host, (.value.port // 6466), (.value.name // .key)]
      | @tsv
    ')"

    if [ -z "$${stuck_devices}" ]; then
      find "$${STATE_DIR}" -type f -name '*.state' -delete 2>/dev/null || true
      log "no stuck Android TV remote accessories"
      exit 0
    fi

    printf '%s\n' "$${stuck_devices}" | while IFS="$(printf '\t')" read -r host port name; do
      [ -n "$${host}" ] || continue

      state_file="$${STATE_DIR}/$(sanitize "$${host}").state"
      count=0
      last_restart=0
      if [ -f "$${state_file}" ]; then
        # shellcheck disable=SC1090
        . "$${state_file}" 2>/dev/null || true
      fi

      if [ "$((now - last_restart))" -lt "$${COOLDOWN_SECONDS}" ]; then
        log "$${name} ($${host}) still in cooldown after last restart; skipping"
        continue
      fi

      if ! nc -z -w 3 "$${host}" "$${port}" >/dev/null 2>&1; then
        log "$${name} ($${host}:$${port}) is not reachable; treating as device offline"
        rm -f "$${state_file}"
        continue
      fi

      if ! tail -n "$${LOG_TAIL_LINES}" "$${HOMEBRIDGE_LOG}" 2>/dev/null | grep -F "$${host} Remote secureConnect" >/dev/null; then
        log "$${name} ($${host}) powered=false but no recent secureConnect timeout marker; waiting"
        continue
      fi

      count="$((count + 1))"
      if [ "$${count}" -lt "$${REQUIRED_CONSECUTIVE_FAILURES}" ]; then
        {
          printf 'count=%s\n' "$${count}"
          printf 'last_restart=%s\n' "$${last_restart}"
        } > "$${state_file}"
        log "$${name} ($${host}) suspected stuck remote; confirmation $${count}/$${REQUIRED_CONSECUTIVE_FAILURES}"
        continue
      fi

      log "$${name} ($${host}) stuck remote confirmed; restarting $${CONTAINER_NAME}"
      docker restart "$${CONTAINER_NAME}" >/dev/null
      {
        printf 'count=0\n'
        printf 'last_restart=%s\n' "$${now}"
      } > "$${state_file}"
      log "$${CONTAINER_NAME} restarted for $${name} ($${host}); cooldown=$${COOLDOWN_SECONDS}s"
      exit 0
    done
  SCRIPT

  depends_on = [null_resource.homebridge_maintenance_dir]
}

resource "null_resource" "homebridge_androidtv_healer_cron" {
  count = var.homebridge_enabled ? 1 : 0

  triggers = {
    cron_line = "*/2 * * * * ${local.homebridge_androidtv_healer_job} >> ${local.homebridge_androidtv_healer_log} 2>&1 # homebridge_androidtv_healer_job"
  }

  provisioner "local-exec" {
    command = <<-EOT
      bash -lc 'set -eu
      (crontab -l 2>/dev/null | grep -v "homebridge_androidtv_healer_job" || true; echo "${self.triggers.cron_line}") | crontab -'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      bash -lc 'set -eu
      (crontab -l 2>/dev/null | grep -v "homebridge_androidtv_healer_job" || true) | crontab -'
    EOT
  }

  depends_on = [local_file.homebridge_androidtv_healer_script]
}

resource "null_resource" "home_assistant_generated_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.home_assistant_generated_dir}"
  }
}

resource "null_resource" "home_assistant_data_files" {
  provisioner "local-exec" {
    command = <<-EOT
      bash -lc 'set -eu
      mkdir -p "${local.home_assistant_data_dir}/themes"
      mkdir -p "${local.home_assistant_data_dir}/dashboards"
      [ -f "${local.home_assistant_data_dir}/automations.yaml" ] || : > "${local.home_assistant_data_dir}/automations.yaml"
      [ -f "${local.home_assistant_data_dir}/scripts.yaml" ] || : > "${local.home_assistant_data_dir}/scripts.yaml"
      [ -f "${local.home_assistant_data_dir}/scenes.yaml" ] || : > "${local.home_assistant_data_dir}/scenes.yaml"'
    EOT
  }

  depends_on = [null_resource.home_assistant_data_dir]
}

resource "null_resource" "home_assistant_maintenance_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.home_assistant_maintenance_dir}"
  }

  depends_on = [null_resource.home_assistant_data_dir]
}

resource "local_file" "home_assistant_configuration" {
  filename        = local.home_assistant_config_path
  file_permission = "0640"
  content = templatefile(
    "${path.module}/templates/home-assistant-configuration.yaml.tmpl",
    {
      trusted_proxies = var.home_assistant_trusted_proxies
    }
  )

  depends_on = [null_resource.home_assistant_generated_dir]
}

resource "local_file" "home_assistant_recorder_limit_script" {
  filename        = local.home_assistant_recorder_limit_job
  file_permission = "0775"
  content         = <<-SCRIPT
    #!/usr/bin/env bash
    set -euo pipefail

    DB_PATH="$${DB_PATH:-${local.home_assistant_data_dir}/home-assistant_v2.db}"
    WAL_PATH="$${DB_PATH}-wal"
    TOKEN_FILE="$${TOKEN_FILE:-${local.homebridge_data_dir}/config.json}"
    HA_URL="$${HA_URL:-http://127.0.0.1:8123}"
    LIMIT_BYTES="$${LIMIT_BYTES:-104857600}"
    KEEP_DAYS="$${KEEP_DAYS:-1}"
    LOG_PREFIX="[homeassistant-recorder-limit]"

    size_of() {
      [ -e "$1" ] && stat -c '%s' "$1" || printf '0'
    }

    db_size="$(size_of "$${DB_PATH}")"
    wal_size="$(size_of "$${WAL_PATH}")"
    total_size="$((db_size + wal_size))"

    echo "$${LOG_PREFIX} db=$${db_size} wal=$${wal_size} total=$${total_size} limit=$${LIMIT_BYTES}"

    if [ "$${total_size}" -le "$${LIMIT_BYTES}" ]; then
      echo "$${LOG_PREFIX} below limit; nothing to do"
      exit 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
      echo "$${LOG_PREFIX} jq is required to read Home Assistant token" >&2
      exit 1
    fi

    token="$(jq -r '.platforms[]? | select(.platform == "HomeAssistant") | .token // empty' "$${TOKEN_FILE}" | head -n 1)"
    if [ -z "$${token}" ]; then
      echo "$${LOG_PREFIX} could not read Home Assistant token from $${TOKEN_FILE}" >&2
      exit 1
    fi

    payload="$(jq -nc --argjson keep_days "$${KEEP_DAYS}" \
      '{keep_days: $keep_days, repack: true, apply_filter: true}')"

    echo "$${LOG_PREFIX} over limit; requesting recorder.purge keep_days=$${KEEP_DAYS} repack=true"
    curl -fsS \
      -X POST \
      -H "Authorization: Bearer $${token}" \
      -H "Content-Type: application/json" \
      --data "$${payload}" \
      "$${HA_URL}/api/services/recorder/purge" >/dev/null

    echo "$${LOG_PREFIX} purge requested successfully"
  SCRIPT

  depends_on = [null_resource.home_assistant_maintenance_dir]
}

resource "null_resource" "home_assistant_recorder_limit_cron" {
  triggers = {
    cron_line = "20 3 * * * ${local.home_assistant_recorder_limit_job} >> ${local.home_assistant_recorder_limit_log} 2>&1 # homeassistant_recorder_limit_job"
  }

  provisioner "local-exec" {
    command = <<-EOT
      bash -lc 'set -eu
      (crontab -l 2>/dev/null | grep -v "homeassistant_recorder_limit_job" || true; echo "${self.triggers.cron_line}") | crontab -'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      bash -lc 'set -eu
      (crontab -l 2>/dev/null | grep -v "homeassistant_recorder_limit_job" || true) | crontab -'
    EOT
  }

  depends_on = [local_file.home_assistant_recorder_limit_script]
}

resource "local_file" "home_assistant_vacuum_simple_dashboard" {
  filename        = "${local.home_assistant_data_dir}/dashboards/aspirador-simples.yaml"
  file_permission = "0644"
  content         = file("${path.module}/templates/aspirador-simples.yaml")

  depends_on = [null_resource.home_assistant_data_files]
}

resource "local_file" "home_assistant_vacuum_hacs_dashboard" {
  filename        = "${local.home_assistant_data_dir}/dashboards/aspirador-hacs.yaml"
  file_permission = "0644"
  content         = file("${path.module}/templates/aspirador-hacs.yaml")

  depends_on = [null_resource.home_assistant_data_files]
}

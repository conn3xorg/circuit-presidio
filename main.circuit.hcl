locals {
  etc         = "/etc/presidio"
  config_file = "${local.etc}/analyzer.yaml"
  analyzer    = contains(var.services, "analyzer")
  configured  = local.analyzer && var.analyzer_config != null

  # gunicorn takes an IPv6 address in brackets. A wildcard address is
  # probed on loopback.
  bind_host  = strcontains(var.listen_address, ":") ? "[${var.listen_address}]" : var.listen_address
  probe_host = var.listen_address == "0.0.0.0" ? "127.0.0.1" : var.listen_address == "::" ? "[::1]" : local.bind_host
  loopback   = can(regex("^(127\\.|::1$)", var.listen_address))

  images = {
    analyzer   = "ghcr.io/data-privacy-stack/presidio-analyzer:${var.presidio_version}@${var.analyzer_digest}"
    anonymizer = "ghcr.io/data-privacy-stack/presidio-anonymizer:${var.presidio_version}@${var.anonymizer_digest}"
  }
  ports = {
    analyzer   = var.analyzer_port
    anonymizer = var.anonymizer_port
  }

  containers = {
    for s in var.services : "presidio-${s}" => {
      image = local.images[s]
      # PORT is what the image's own HEALTHCHECK probes.
      environment = merge(
        { PORT = tostring(local.ports[s]) },
        s == "analyzer" && local.configured ? { ANALYZER_CONF_FILE = local.config_file } : {},
      )
      volumes = s == "analyzer" ? ["${local.etc}:${local.etc}:ro,Z"] : []
      extra = concat(
        [
          "Network=host",
          # The image's start script binds 0.0.0.0, which on the host's
          # network would be every address. This is the same gunicorn
          # command with listen_address instead.
          "Exec=gunicorn -w 1 -b ${local.bind_host}:${local.ports[s]} app:create_app()",
        ],
        # circuit-podman restarts the container when its unit changes, so
        # the config's hash here makes a new config take effect.
        s == "analyzer" && local.configured ? ["# analyzer.yaml sha256 ${sha256(var.analyzer_config)}"] : [],
      )
    }
  }

  # Each image has python but not curl, and some hosts have neither.
  probe = {
    for s in var.services : s => "podman exec presidio-${s} python -c \"import urllib.request as u; u.build_opener(u.ProxyHandler({})).open('http://${local.probe_host}:${local.ports[s]}/health', timeout=5)\" >/dev/null 2>&1"
  }
}

# Presidio has no authentication of its own. Anyone who can reach a port can
# send it text, and with the anonymizer, get it back rewritten.
check "loopback" {
  assert {
    condition     = local.loopback
    error_message = "Presidio has no authentication, and listen_address ${var.listen_address} isn't a loopback address. Anyone who can reach ports ${join(" and ", [for s in sort(tolist(var.services)) : tostring(local.ports[s])])} can use it. Put a reverse proxy with authentication in front, such as circuit-caddy with basic_auth, and keep the ports closed in the firewall."
  }
}

circuit "config" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # Mounted into the analyzer read-only. The container runs as UID 1001,
  # so the file is world-readable; it holds configuration, not secrets.
  step "dir" {
    for_each = toset(local.analyzer ? ["etc"] : [])
    directory {
      path  = local.etc
      owner = "root"
      group = "root"
      mode  = "0755"
    }
  }

  step "analyzer" {
    for_each = toset(local.configured ? ["config"] : [])
    file {
      path      = local.config_file
      content   = var.analyzer_config
      owner     = "root"
      group     = "root"
      mode      = "0644"
      on_remove = "delete"
    }
  }
}

module "podman" {
  source = "github.com/conn3xorg/circuit-podman?ref=v0.1.0"

  depends_on = [conn3x_directory.config__dir, conn3x_file.config__analyzer]

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  containers = local.containers
}

circuit "ready" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # gunicorn opens the port before the analyzer has loaded its spaCy model,
  # so this waits for /health, which also proves the config loaded. unless
  # is checked at plan time, before the restart, so anything that restarts
  # the container makes the apply check again.
  step "health" {
    for_each   = var.services
    depends_on = [module.podman]
    command {
      command  = "for _ in $(seq 300); do ${local.probe[item.value]} && exit 0; sleep 1; done; echo 'Presidio ${item.value} did not answer /health in 5 minutes. See journalctl -u presidio-${item.value}.' >&2; exit 1"
      unless   = local.probe[item.value]
      triggers = sha256(jsonencode(local.containers["presidio-${item.value}"]))
    }
  }
}

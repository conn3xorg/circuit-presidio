output "services" {
  description = "The systemd services that run Presidio on each host, by service."
  value       = { for s in var.services : s => "presidio-${s}.service" }
}

output "analyzer_url" {
  description = "Base URL of the analyzer on each host, as seen from the host itself. Null when the analyzer isn't in services."
  value       = local.analyzer ? "http://${local.probe_host}:${var.analyzer_port}" : null
}

output "anonymizer_url" {
  description = "Base URL of the anonymizer on each host, as seen from the host itself. Null when the anonymizer isn't in services."
  value       = contains(var.services, "anonymizer") ? "http://${local.probe_host}:${var.anonymizer_port}" : null
}

output "images" {
  description = "The images the hosts run, by service, with tag and digest."
  value       = { for s in var.services : s => local.images[s] }
}

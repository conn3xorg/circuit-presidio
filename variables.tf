variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}


variable "services" {
  type        = set(string)
  default     = ["analyzer", "anonymizer"]
  nullable    = false
  description = "Which of Presidio's services to run: \"analyzer\", which finds PII in text, and \"anonymizer\", which replaces what the analyzer found."

  validation {
    condition     = length(var.services) > 0 && length(setsubtract(var.services, ["analyzer", "anonymizer"])) == 0
    error_message = "services must hold \"analyzer\", \"anonymizer\" or both."
  }
}

variable "presidio_version" {
  type        = string
  default     = "2.2.366"
  description = "Tag of the ghcr.io/data-privacy-stack/presidio-analyzer and presidio-anonymizer images, such as \"2.2.366\". Change analyzer_digest and anonymizer_digest with it."

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.presidio_version))
    error_message = "presidio_version must be an image tag, such as \"2.2.366\"."
  }
}

variable "analyzer_digest" {
  type        = string
  default     = "sha256:036d2f9b3c274fb36497383acef8f2d5aea528a014801c2c3040fb067990c79c"
  description = "Digest of presidio-analyzer for presidio_version. Podman pulls by the digest, so a tag that moves upstream can't change what runs."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.analyzer_digest))
    error_message = "analyzer_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "anonymizer_digest" {
  type        = string
  default     = "sha256:b4d9ec900135c694b84353e03e1abd5127ccdfcd916d32db73002c28f0eaddc7"
  description = "Digest of presidio-anonymizer for presidio_version. Podman pulls by the digest, so a tag that moves upstream can't change what runs."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.anonymizer_digest))
    error_message = "anonymizer_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "listen_address" {
  type        = string
  default     = "127.0.0.1"
  description = "Address both services listen on. Presidio has no authentication, so the default keeps it on the host. Anything else gets a warning on every plan."

  validation {
    condition     = can(cidrhost("${var.listen_address}/${strcontains(var.listen_address, ":") ? 128 : 32}", 0))
    error_message = "listen_address must be an IPv4 or IPv6 address, such as \"127.0.0.1\"."
  }
}

variable "analyzer_port" {
  type        = number
  default     = 5002
  description = "Port the analyzer listens on."

  validation {
    condition     = var.analyzer_port >= 1 && var.analyzer_port <= 65535 && floor(var.analyzer_port) == var.analyzer_port
    error_message = "analyzer_port must be a whole number from 1 to 65535."
  }
}

variable "anonymizer_port" {
  type        = number
  default     = 5001
  description = "Port the anonymizer listens on."

  validation {
    condition     = var.anonymizer_port >= 1 && var.anonymizer_port <= 65535 && floor(var.anonymizer_port) == var.anonymizer_port
    error_message = "anonymizer_port must be a whole number from 1 to 65535."
  }

  validation {
    condition     = var.anonymizer_port != var.analyzer_port
    error_message = "anonymizer_port and analyzer_port must differ."
  }
}

variable "analyzer_config" {
  type        = string
  default     = null
  description = "The analyzer's configuration as YAML, in Presidio's single-file format: supported_languages, default_score_threshold, and optional nlp_configuration and recognizer_registry sections. A recognizer_registry section replaces the built-in list of recognizers. When null, the image's defaults: English, with every built-in recognizer."

  validation {
    condition     = var.analyzer_config == null || can(keys(yamldecode(var.analyzer_config)))
    error_message = "analyzer_config must be a YAML mapping, such as \"supported_languages: [en]\"."
  }
}

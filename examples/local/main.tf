variable "port" {
  type    = number
  default = 2306
}

module "presidio" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  # A short list of the built-in recognizers, plus two of your own: a
  # deny-list of made-up project code names, and a pattern for employee
  # IDs. The spaCy recognizer, which finds names and places, is added for
  # you.
  analyzer_config = <<-YAML
    supported_languages: [en]
    default_score_threshold: 0.4
    recognizer_registry:
      global_regex_flags: 26
      recognizers:
        - name: EmailRecognizer
          type: predefined
        - name: PhoneRecognizer
          type: predefined
        - name: CreditCardRecognizer
          type: predefined
        - name: IpRecognizer
          type: predefined
        - name: UrlRecognizer
          type: predefined
        - name: CodenameRecognizer
          supported_language: en
          supported_entity: PROJECT_CODENAME
          deny_list: [Bluebird, Quillfeather]
        - name: EmployeeIdRecognizer
          supported_language: en
          supported_entity: EMPLOYEE_ID
          patterns:
            - name: employee id
              regex: "\\bEMP-\\d{6}\\b"
              score: 0.9
  YAML
}

output "analyzer_url" {
  value = module.presidio.analyzer_url
}

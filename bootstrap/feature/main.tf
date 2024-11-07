variable "namespace" {
  type = string
}

variable "operator_image_tag" {
  type = string
}

variable "api_key_salt" {
  type = string
}

variable "extension_subdomain" {
  type    = string
  default = "utxorpc-m0"
}

variable "certs_secret" {
  type    = string
  default = "proxy-certs"
}

variable "dns_zone" {
  default = "demeter.run"
}

variable "include_certs" {
  type    = bool
  default = true
}

variable "metrics_delay" {
  description = "the inverval for polling metrics data (in seconds)"
  default     = "60"
}

variable "metrics_step" {
  description = "the metrics prometheus step"
  default     = "10s"
}

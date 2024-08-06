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

variable "dns_zone" {
  default = "demeter.run"
}

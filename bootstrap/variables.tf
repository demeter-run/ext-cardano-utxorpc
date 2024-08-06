variable "namespace" {
  type = string
}

variable "networks" {
  type    = list(string)
  default = ["mainnet", "preprod", "preview", "vector-testnet"]
}

variable "network_addresses" {
  type    = map(string, string)
  default = {}
}

// Feature
variable "operator_image_tag" {
  type = string
}

variable "api_key_salt" {
  type = string
}

variable "extension_subdomain" {
  type = string
}

variable "dns_zone" {
  default = "demeter.run"
}

// Instances
variable "instances" {
  type = map(object({
    network       = string
    replicas      = optional(number)
    dolos_version = optional(string)
    resources = optional(object({
      limits = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
      storage = object({
        size  = string
        class = string
      })
    }))
  }))
}

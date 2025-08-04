variable "namespace" {
  type = string
}

variable "networks" {
  type    = list(string)
  default = ["cardano-mainnet", "cardano-preprod", "cardano-preview"]
}

variable "network_addresses" {
  type    = map(string)
  default = {}
}

// Feature
variable "operator_image_tag" {
  type = string
}

variable "api_key_salt" {
  type = string
}

variable "extension_urls_per_network" {
  type = map(list(string))
}

variable "prometheus_url" {
  type    = string
  default = "http://prometheus-operated.demeter-system.svc.cluster.local:9090/api/v1"
}

// Proxies
variable "proxies_image_tag" {
  type = string
}

variable "cells" {
  type = map(object({
    tolerations = optional(list(object({
      effect   = string
      key      = string
      operator = string
      value    = optional(string)
    })))
    pvc = object({
      storage_class = string
      storage_size  = string
      volume_name   = optional(string)
    })
    instances = map(object({
      dolos_image     = string
      replicas        = optional(number)
      proxy_image_tag = string
      resources = optional(object({
        limits = object({
          cpu    = string
          memory = string
        })
        requests = object({
          cpu    = string
          memory = string
        })
      }))
      proxy_resources = optional(object({
        limits = object({
          cpu    = string
          memory = string
        })
        requests = object({
          cpu    = string
          memory = string
        })
      }))
    }))
  }))
}

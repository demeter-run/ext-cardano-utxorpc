variable "namespace" {
  type = string
}

variable "networks" {
  type    = list(string)
  default = ["mainnet", "preprod", "preview", "vector-testnet"]
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

variable "extension_subdomain" {
  type = string
}

variable "dns_zone" {
  default = "demeter.run"
}

// Cloudflared
variable "cloudflared_tunnel_id" {
  type = string
}

variable "cloudflared_tunnel_secret" {
  type        = string
  description = "TunnelSecret, written on credentials file."
}

variable "cloudflared_account_tag" {
  type        = string
  description = "AccountTag, written on credentials file."
}

variable "cells" {
  type = map(object({
    tolerations = optional(list(object({
      effect   = string
      key      = string
      operator = string
      value    = string
    })))
    pvc = object({
      storage_class = string
      storage_size  = string
      volume_name   = string
    })
    proxy = object({
      image_tag = string
      replicas  = optional(number)
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
    })
    cloudflared = optional(object({
      image_tag = optional(string)
      replicas  = optional(number)
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
    }))
    instances = map(object({
      dolos_version = string
      replicas      = optional(number)
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
    }))
  }))
}

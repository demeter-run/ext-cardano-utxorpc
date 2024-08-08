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

// Proxy
variable "proxy_image_tag" {
  type = string
}

variable "proxy_replicas" {
  type    = number
  default = 1
}

variable "proxy_resources" {
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits : {
      cpu : "50m",
      memory : "250Mi"
    }
    requests : {
      cpu : "50m",
      memory : "250Mi"
    }
  }
}

// Cloudflared
variable "cloudflared_tunnel_id" {
  type = string
}

variable "cloudflared_hostname" {
  type = string
}

variable "cloudflared_credentials_secret_name" {
  type        = string
  description = "Name of the secret where credentials.json is saved."
}

variable "cloudflared_metrics_port" {
  type    = number
  default = 2000
}

variable "cloudflared_image_tag" {
  type    = string
  default = "latest"
}

variable "cloudflared_replicas" {
  type    = number
  default = 2
}

variable "cloudflared_resources" {
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits : {
      cpu : "1",
      memory : "500Mi"
    }
    requests : {
      cpu : "50m",
      memory : "500Mi"
    }
  }
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

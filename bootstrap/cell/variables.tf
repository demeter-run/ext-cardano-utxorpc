variable "namespace" {
  type = string
}

variable "salt" {
  type = string
}

variable "extension_subdomain" {
  type = string
}

variable "dns_zone" {
  default = "demeter.run"
}

variable "storage_size" {
  type = string
}

variable "storage_class" {
  type = string
}

variable "volume_name" {
  type = string
}

variable "certs_configmap" {
  type    = string
  default = "proxy-certs"
}

variable "tolerations" {
  type = list(object({
    effect   = string
    key      = string
    operator = string
    value    = string
  }))
  default = [
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-profile"
      operator = "Equal"
      value    = "general-purpose"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-arch"
      operator = "Equal"
      value    = "x86"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/availability-sla"
      operator = "Equal"
      value    = "best-effort"
    }
  ]
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

variable "cloudflared_tunnel_secret" {
  type        = string
  description = "TunnelSecret, written on credentials file."
}

variable "cloudflared_account_tag" {
  type        = string
  description = "AccountTag, written on credentials file."
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
}

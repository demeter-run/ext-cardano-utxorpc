locals {
  name = "proxy-${var.network}"
  role = "proxy-${var.network}"

  prometheus_port = 9187
  prometheus_addr = "0.0.0.0:${local.prometheus_port}"
  proxy_port      = 8080
  proxy_addr      = "[::1]:${local.proxy_port}"
}

variable "namespace" {
  type = string
}

variable "network" {
  type = string
}

variable "replicas" {
  type    = number
  default = 1
}

variable "image_tag" {
  type = string
}

variable "extension_url" {
  type = string
}

variable "extra_extension_urls" {
  type    = list(string)
  default = []
}

variable "certs_secret_name" {
  type    = string
  default = null
}

variable "tolerations" {
  type = list(object({
    effect   = string
    key      = string
    operator = string
    value    = optional(string)
  }))
  default = [
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-profile"
      operator = "Exists"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-arch"
      operator = "Equal"
      value    = "arm64"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/availability-sla"
      operator = "Exists"
    }
  ]
}

variable "resources" {
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

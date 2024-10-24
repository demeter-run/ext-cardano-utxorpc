locals {
  name = "proxy-${var.network}"
  role = "proxy-${var.network}"

  prometheus_port = 9187
  prometheus_addr = "0.0.0.0:${local.prometheus_port}"
  proxy_port      = 8080
  proxy_addr      = "0.0.0.0:${local.proxy_port}"
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

variable "certs_secret" {
  type    = string
  default = "proxy-certs"
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
      value    = "x86"
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

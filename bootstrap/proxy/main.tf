locals {
  name = var.name
  role = var.environment != null ? "proxy-${var.environment}" : "proxy"

  prometheus_port = 9187
  prometheus_addr = "0.0.0.0:${local.prometheus_port}"
  proxy_port      = 8080
  proxy_addr      = "0.0.0.0:${local.proxy_port}"
}

variable "name" {
  type    = string
  default = "proxy"
}

variable "namespace" {
  type = string
}

variable "environment" {
  default = null
}

variable "utxorpc_instances" {
  type = map(string)
}

variable "replicas" {
  type    = number
  default = 1
}

variable "image_tag" {
  type = string
}

variable "certs_secret_name" {
  type = string
}

variable "dns_names" {
  type = list(string)
}

variable "cluster_issuer" {
  type    = string
  default = "letsencrypt-dns01"
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
      operator = "Equal"
      value    = "best-effort"
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
      cpu : "2000m",
      memory : "250Mi"
    }
    requests : {
      cpu : "50m",
      memory : "250Mi"
    }
  }
}

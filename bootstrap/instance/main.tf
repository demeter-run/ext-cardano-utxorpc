locals {
  instance = "${var.instance_name}-${var.salt}"
}

variable "namespace" {}

variable "network" {
  type = string
}

variable "salt" {
  type = string
}

variable "pvc_name" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "replicas" {
  default = 1
}

variable "dolos_version" {
  type = string
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

variable "resources" {
  type = object({
    limits = object({
      cpu    = optional(string)
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "50m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "512Mi"
    }
  }
}


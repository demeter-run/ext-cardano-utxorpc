locals {
  configmap_name = "snapshot-updater-config-${var.network}-${var.prefix}"
}

variable "namespace" {
  type = string
}

variable "network" {
  type = string
}

variable "pvc_name" {
  type = string
}

variable "pvc_size" {
  type = string
}

variable "cron" {
  type    = string
  default = "15 0 * * *"
}

variable "suspend" {
  type    = bool
  default = false
}

variable "dolos_version" {
  type = string
}

variable "bucket" {
  type    = string
  default = "dolos-snapshots"
}

variable "prefix" {
  type    = string
  default = "v2"
}

variable "bootstrap" {
  type    = string
  default = "snapshot --variant full"
}

variable "aws_access_key_id" {
  type = string
}

variable "aws_secret_access_key" {
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
      operator = "Exists"
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


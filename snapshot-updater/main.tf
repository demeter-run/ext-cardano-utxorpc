locals {
  magic_by_network = {
    "mainnet" : 764824073,
    "preprod" : 1,
    "preview" : 2
  }
  address_by_network = {
    "mainnet" : "node-mainnet-stable.ext-nodes-m1.svc.cluster.local:3000"
    "preprod" : "node-preprod-stable.ext-nodes-m1.svc.cluster.local:3000"
    "preview" : "node-preview-stable.ext-nodes-m1.svc.cluster.local:3000"
  }
  magic          = local.magic_by_network[var.network]
  address        = local.address_by_network[var.network]
  configmap_name = "snapshot-updater-config-${var.network}"
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

variable "dolos_version" {
  type = string
}

variable "bucket" {
  type    = string
  default = "dolos-snapshots"
}

variable "prefix" {
  type    = string
  default = "v0"
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


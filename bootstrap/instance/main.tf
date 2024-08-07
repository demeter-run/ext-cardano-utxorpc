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

variable "instance_name" {
  type = string
}

variable "replicas" {
  default = 1
}

variable "dolos_version" {
  type = string
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
    storage = object({
      size  = string
      class = string
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
    storage = {
      size  = "30Gi"
      class = "fast"
    }

  }
}


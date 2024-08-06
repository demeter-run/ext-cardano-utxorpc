locals {
  default_address_by_network = {
    "mainnet" : "node-mainnet-stable.ext-nodes-m1.svc.cluster.local:3000"
    "preprod" : "node-preprod-stable.ext-nodes-m1.svc.cluster.local:3000"
    "preview" : "node-preview-stable.ext-nodes-m1.svc.cluster.local:3000"
    "vector-testnet" : "85.90.225.26:7532"
  }
}

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "network" {
  description = "cardano node network"
}

variable "namespace" {
  description = "the namespace where the resources will be created"
}

variable "address" {
  type    = string
  default = null
}

resource "kubernetes_config_map" "node-config" {
  metadata {
    namespace = var.namespace
    name      = "configs-${var.network}"
  }

  data = {
    "dolos.toml" = "${templatefile("${path.module}/${var.network}.toml", {
      address = coalesce(var.address, local.default_address_by_network[var.network])
    })}"
  }
}

output "cm_name" {
  value = "configs-${var.network}"
}

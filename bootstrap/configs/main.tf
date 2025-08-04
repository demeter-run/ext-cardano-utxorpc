locals {
  default_address_by_network = {
    "cardano-mainnet" : "node-mainnet-stable.ext-nodes-m1.svc.cluster.local:3000"
    "cardano-preprod" : "node-preprod-stable.ext-nodes-m1.svc.cluster.local:3000"
    "cardano-preview" : "node-preview-stable.ext-nodes-m1.svc.cluster.local:3000"
    "vector-testnet" : "node-vector-testnet-stable.ext-nodes-m1.svc.cluster.local:3000"
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

resource "kubernetes_config_map" "genesis" {
  for_each = var.network == "vector-testnet" ? toset(["vector-testnet"]) : toset([])

  metadata {
    namespace = var.namespace
    name      = "genesis-${var.network}"
  }

  data = {
    "alonzo.json"  = "${file("${path.module}/${var.network}/alonzo.json")}"
    "byron.json"   = "${file("${path.module}/${var.network}/byron.json")}"
    "conway.json"  = "${file("${path.module}/${var.network}/conway.json")}"
    "shelley.json" = "${file("${path.module}/${var.network}/shelley.json")}"
  }
}

output "cm_name" {
  value = "configs-${var.network}"
}

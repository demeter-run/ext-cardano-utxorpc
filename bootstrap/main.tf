resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = var.namespace
  }
}

module "feature" {
  depends_on = [kubernetes_namespace_v1.namespace]
  source     = "./feature"

  namespace                  = var.namespace
  operator_image_tag         = var.operator_image_tag
  extension_urls_per_network = var.extension_urls_per_network
  api_key_salt               = var.api_key_salt
}

module "configs" {
  depends_on = [kubernetes_namespace_v1.namespace]
  source     = "./configs"
  for_each   = { for network in var.networks : "${network}" => network }

  namespace = var.namespace
  network   = each.value
  address   = lookup(var.network_addresses, each.value, null)
}

module "services" {
  depends_on = [kubernetes_namespace_v1.namespace]
  source     = "./services"

  namespace = var.namespace
  networks  = var.networks
}

module "cells" {
  depends_on = [module.configs, module.feature]
  for_each   = var.cells
  source     = "./cell"

  namespace = var.namespace
  salt      = each.key
  tolerations = coalesce(each.value.tolerations, [
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-profile"
      operator = "Equal"
      value    = "disk-intensive"
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
      value    = "consistent"
    }
  ])

  // PVC
  storage_size  = each.value.pvc.storage_size
  storage_class = each.value.pvc.storage_class
  volume_name   = each.value.pvc.volume_name

  // Instances
  instances = each.value.instances
}

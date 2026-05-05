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

module "proxies_blue" {
  depends_on = [kubernetes_namespace_v1.namespace]
  source     = "./proxy"

  namespace         = var.namespace
  name              = "proxy-blue"
  environment       = "blue"
  utxorpc_instances = var.proxy_blue_instance_per_network
  image_tag         = var.proxy_blue_image_tag
  replicas          = var.proxy_blue_replicas
  resources         = var.proxy_blue_resources
  tolerations       = var.proxy_blue_tolerations
  certs_secret_name = "utxorpc-proxy-blue-wildcard-tls"
  cluster_issuer    = var.cluster_issuer
  dns_names         = distinct(flatten(values(var.extension_urls_per_network)))
}

module "proxies_green" {
  depends_on = [kubernetes_namespace_v1.namespace]
  source     = "./proxy"

  namespace         = var.namespace
  name              = "proxy-green"
  environment       = "green"
  utxorpc_instances = var.proxy_green_instance_per_network
  image_tag         = var.proxy_green_image_tag
  replicas          = var.proxy_green_replicas
  resources         = var.proxy_green_resources
  tolerations       = var.proxy_green_tolerations
  certs_secret_name = "utxorpc-proxy-green-wildcard-tls"
  cluster_issuer    = var.cluster_issuer
  dns_names         = distinct(flatten(values(var.extension_urls_per_network)))
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

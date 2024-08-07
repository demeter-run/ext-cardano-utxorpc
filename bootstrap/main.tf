resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

module "feature" {
  depends_on = [kubernetes_namespace.namespace]
  source     = "./feature"

  namespace           = var.namespace
  operator_image_tag  = var.operator_image_tag
  extension_subdomain = var.extension_subdomain
  dns_zone            = var.dns_zone
  api_key_salt        = var.api_key_salt
}

module "configs" {
  source   = "./configs"
  for_each = { for network in var.networks : "${network}" => network }

  namespace = var.namespace
  network   = each.value
  address   = lookup(var.network_addresses, each.value, null)
}

module "services" {
  depends_on = [kubernetes_namespace.namespace]
  for_each   = { for network in var.networks : "${network}" => network }
  source     = "./service"

  namespace = var.namespace
  network   = each.value
}

module "proxy" {
  depends_on = [kubernetes_namespace.namespace]
  source     = "./proxy"

  namespace = var.namespace
  image_tag = var.proxy_image_tag
  replicas  = var.proxy_replicas
  resources = var.proxy_resources
}

module "instances" {
  depends_on = [module.utxorpc_feature, module.utxorpc_configs]
  for_each   = var.instances
  source     = "./instance"

  namespace     = var.namespace
  network       = each.network
  salt          = each.key
  instance_name = "${each.value.network}-${each.value.salt}"
  dolos_version = each.value.dolos_version
  replicas      = each.value.replicas
  resources     = each.value.resources
}

resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = var.namespace
  }
}

module "feature" {
  depends_on = [kubernetes_namespace_v1.namespace]
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
  depends_on = [kubernetes_namespace_v1.namespace]
  for_each   = { for network in var.networks : "${network}" => network }
  source     = "./service"

  namespace = var.namespace
  network   = each.value
}

module "proxy" {
  depends_on = [kubernetes_namespace_v1.namespace]
  source     = "./proxy"

  namespace = var.namespace
  image_tag = var.proxy_image_tag
  replicas  = var.proxy_replicas
  resources = var.proxy_resources
}

module "cloudflared" {
  depends_on = [module.proxy]
  source     = "./cloudflared"

  namespace     = var.namespace
  tunnel_id     = var.cloudflared_tunnel_id
  hostname      = "${var.extension_subdomain}.${var.dns_zone}"
  tunnel_secret = var.cloudflared_tunnel_secret
  account_tag   = var.cloudflared_account_tag
  metrics_port  = var.cloudflared_metrics_port
  image_tag     = var.cloudflared_image_tag
  replicas      = var.cloudflared_replicas
  resources     = var.cloudflared_resources
}

module "instances" {
  depends_on = [module.feature, module.configs]
  for_each   = var.instances
  source     = "./instance"

  namespace     = var.namespace
  network       = each.value.network
  salt          = each.key
  instance_name = "${each.value.network}-${each.key}"
  dolos_version = coalesce(each.value.dolos_version, "v0.13.1")
  replicas      = coalesce(each.value.replicas, 1)
  resources = coalesce(each.value.resources, {
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
  })
}

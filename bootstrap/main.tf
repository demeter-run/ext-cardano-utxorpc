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

  namespace           = var.namespace
  salt                = each.key
  extension_subdomain = var.extension_subdomain
  dns_zone            = var.dns_zone
  tolerations = coalesce(each.value.tolerations, [
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
  ])

  // PVC
  storage_size  = each.value.pvc.storage_size
  storage_class = each.value.pvc.storage_class
  volume_name   = each.value.pvc.volume_name

  // Proxy
  proxy_image_tag = each.value.proxy.image_tag
  proxy_replicas  = try(each.value.proxy.replicas, 1)
  proxy_resources = try(each.value.proxy.resoures, {
    limits : {
      cpu : "50m",
      memory : "250Mi"
    }
    requests : {
      cpu : "50m",
      memory : "250Mi"
    }
  })

  // CLoudflared
  cloudflared_tunnel_id     = var.cloudflared_tunnel_id
  cloudflared_tunnel_secret = var.cloudflared_tunnel_secret
  cloudflared_account_tag   = var.cloudflared_account_tag
  cloudflared_image_tag     = try(each.value.cloudflared.image_tag, "latest")
  cloudflared_replicas      = try(each.value.cloudflared.replicas, 1)
  cloudflared_resources = try(each.value.cloudflared.resources, {
    limits : {
      cpu : "1",
      memory : "500Mi"
    }
    requests : {
      cpu : "50m",
      memory : "500Mi"
    }
  })

  // Instances
  instances = each.value.instances
}

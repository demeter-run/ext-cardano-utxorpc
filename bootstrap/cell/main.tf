module "pvc" {
  source = "../pvc"

  namespace     = var.namespace
  name          = "pvc-${var.salt}"
  storage_size  = var.storage_size
  storage_class = var.storage_class
  volume_name   = var.volume_name
}

module "proxy" {
  source = "../proxy"

  namespace       = var.namespace
  image_tag       = var.proxy_image_tag
  replicas        = var.proxy_replicas
  resources       = var.proxy_resources
  salt            = var.salt
  certs_configmap = var.certs_configmap
}

module "cloudflared" {
  source = "../cloudflared"

  namespace     = var.namespace
  tunnel_id     = var.cloudflared_tunnel_id
  hostname      = "${var.extension_subdomain}.${var.dns_zone}"
  tunnel_secret = var.cloudflared_tunnel_secret
  account_tag   = var.cloudflared_account_tag
  metrics_port  = var.cloudflared_metrics_port
  image_tag     = var.cloudflared_image_tag
  replicas      = var.cloudflared_replicas
  resources     = var.cloudflared_resources
  tolerations   = var.tolerations
  salt          = var.salt
}

module "instances" {
  for_each = var.instances
  source   = "../instance"

  namespace     = var.namespace
  tolerations   = var.tolerations
  salt          = var.salt
  instance_name = each.key
  network       = each.key
  pvc_name      = "pvc-${var.salt}"
  dolos_version = each.value.dolos_version
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
  })
}

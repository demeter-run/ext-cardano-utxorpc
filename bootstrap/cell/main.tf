module "pvc" {
  source = "../pvc"

  namespace     = var.namespace
  name          = "pvc-${var.salt}"
  storage_size  = var.storage_size
  storage_class = var.storage_class
  volume_name   = var.volume_name
}

module "instances" {
  for_each = var.instances
  source   = "../instance"

  namespace       = var.namespace
  tolerations     = var.tolerations
  salt            = var.salt
  instance_name   = each.key
  network         = each.key
  pvc_name        = "pvc-${var.salt}"
  dolos_image     = each.value.dolos_image
  proxy_image_tag = each.value.proxy_image_tag
  replicas        = coalesce(each.value.replicas, 1)
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
  proxy_resources = coalesce(each.value.proxy_resources, {
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

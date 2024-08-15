locals {
  configmap_name = "tunnel-config"
}


resource "kubernetes_config_map" "tunnel-config" {
  metadata {
    namespace = var.namespace
    name      = local.configmap_name
  }

  data = {
    "config.yml" = "${templatefile("${path.module}/config.yml.tfpl", {
      tunnel_id    = var.tunnel_id
      metrics_port = var.metrics_port
      hostname     = var.hostname
      namespace    = var.namespace
      port         = 8080
      networks     = var.networks
    })}"
  }
}

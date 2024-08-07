resource "kubernetes_config_map" "proxy-certs" {
  metadata {
    namespace = var.namespace
    name      = local.certs_configmap
  }

  data = {
    localhost.crt = file("${path.module}/tls.crt")
    localhost.key = file("${path.module}/tls.key")
  }
}

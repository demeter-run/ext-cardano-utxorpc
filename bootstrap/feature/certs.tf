resource "kubernetes_config_map" "proxy-certs" {
  metadata {
    namespace = var.namespace
    name      = var.certs_configmap
  }

  data = {
    "tls.crt" = file("${path.module}/tls.crt")
    "tls.key" = file("${path.module}/tls.key")
  }
}

resource "kubernetes_secret" "proxy-certs" {
  metadata {
    namespace = var.namespace
    name      = var.certs_secret
  }

  data = {
    "tls.crt" = file("${path.module}/tls.crt")
    "tls.key" = file("${path.module}/tls.key")
  }
}

resource "kubernetes_config_map" "config" {
  metadata {
    namespace = var.namespace
    name      = local.configmap_name
  }

  data = {
    "dolos.toml" = "${templatefile(
      "${path.module}/dolos.toml.tftpl",
      {
        address = local.address
        network = var.network
        magic   = local.magic
      }
    )}",
    "script.sh" = "${templatefile(
      "${path.module}/script.sh.tftpl",
      {
        network = var.network
        magic   = local.magic
        bucket  = var.bucket
        prefix  = var.prefix
      }
    )}",
  }
}

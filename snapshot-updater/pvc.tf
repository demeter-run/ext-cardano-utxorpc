resource "kubernetes_persistent_volume_claim" "scratch" {
  wait_until_bound = false

  metadata {
    name      = var.pvc_name
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "450Gi"
      }
    }
    storage_class_name = "fast"
  }
}

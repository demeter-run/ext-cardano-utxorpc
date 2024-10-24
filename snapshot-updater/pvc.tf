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
        storage = var.pvc_size
      }
    }
    storage_class_name = "gp3"
  }
}

variable "namespace" {
  description = "The namespace where the resources will be created"
}

variable "network" {
  description = "Cardano node network"
}

resource "kubernetes_service_v1" "well_known_service_grpc" {
  metadata {
    name      = "utxorpc-${var.network}-grpc"
    namespace = var.namespace
  }

  spec {
    port {
      name     = "grpc"
      protocol = "TCP"
      port     = 50051
    }

    selector = {
      "cardano.demeter.run/network" = var.network
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "well_known_service_grpc_web" {
  metadata {
    name      = "utxorpc-${var.network}-grpc-web"
    namespace = var.namespace
  }

  spec {
    port {
      name     = "grpc-web"
      protocol = "TCP"
      port     = 50051
    }

    selector = {
      "cardano.demeter.run/network" = var.network
    }

    type = "ClusterIP"
  }
}

variable "namespace" {
  description = "The namespace where the resources will be created"
}

variable "networks" {
  type    = list(string)
  default = ["cardano-mainnet", "cardano-preprod", "cardano-preview", "cardano-vector-testnet"]
}

resource "kubernetes_service_v1" "proxy_service" {
  for_each = { for network in var.networks : "${network}" => network }

  metadata {
    name      = "utxorpc-${each.value}-grpc"
    namespace = var.namespace

    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" : "instance"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" : "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-type" : "external"
    }
  }

  spec {
    load_balancer_class = "service.k8s.aws/nlb"
    selector = {
      "cardano.demeter.run/network" = each.value
    }

    port {
      name        = "proxy"
      port        = 443
      target_port = 8080
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_service_v1" "internal" {
  for_each = { for network in var.networks : "${network}" => network }

  metadata {
    name      = "internal-${each.value}-grpc"
    namespace = var.namespace
  }

  spec {
    selector = {
      "cardano.demeter.run/network" = each.value
    }

    port {
      name        = "grpc"
      port        = 50051
      target_port = 50051
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "internal_minibf" {
  for_each = { for network in var.networks : "${network}" => network }

  metadata {
    name      = "internal-${each.value}-minibf"
    namespace = var.namespace
  }

  spec {
    selector = {
      "cardano.demeter.run/network" = each.value
    }

    port {
      name        = "minibf"
      port        = 3001
      target_port = 3001
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

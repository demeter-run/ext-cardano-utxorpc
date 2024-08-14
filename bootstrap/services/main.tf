variable "namespace" {
  description = "The namespace where the resources will be created"
}

variable "networks" {
  type    = list(string)
  default = ["mainnet", "preprod", "preview", "vector-testnet"]
}

resource "kubernetes_service_v1" "well_known_service_grpc" {
  for_each = { for network in var.networks : "${network}" => network }

  metadata {
    name      = "utxorpc-${each.value}-grpc"
    namespace = var.namespace
  }

  spec {
    port {
      name     = "grpc"
      protocol = "TCP"
      port     = 50051
    }

    selector = {
      "cardano.demeter.run/network" = each.value
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "well_known_service_grpc_web" {
  for_each = { for network in var.networks : "${network}" => network }
  metadata {
    name      = "utxorpc-${each.value}-grpc-web"
    namespace = var.namespace
  }

  spec {
    port {
      name     = "grpc-web"
      protocol = "TCP"
      port     = 50051
    }

    selector = {
      "cardano.demeter.run/network" = each.value
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "proxies" {
  metadata {
    name      = "proxy"
    namespace = var.namespace
    # annotations = {
    #   "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" : "instance"
    #   "service.beta.kubernetes.io/aws-load-balancer-scheme" : "internet-facing"
    #   "service.beta.kubernetes.io/aws-load-balancer-type" : "external"
    #   "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol" : "HTTPS"
    #   "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path" : "/dmtr_health"
    # }
  }

  spec {
    # load_balancer_class = "service.k8s.aws/nlb"
    selector = {
      role = "proxy"
    }

    port {
      name        = "proxy"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    # type = "LoadBalancer"
    type = "ClusterIP"
  }
}

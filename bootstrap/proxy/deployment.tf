resource "kubernetes_deployment_v1" "utxorpc_proxy" {
  wait_for_rollout = false

  metadata {
    name      = local.name
    namespace = var.namespace
    labels = {
      role               = local.role
      "demeter-run/cell" = var.salt
    }
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        role               = local.role
        "demeter-run/cell" = var.salt
      }
    }
    template {
      metadata {
        name = local.name
        labels = {
          role               = local.role
          "demeter-run/cell" = var.salt
        }
      }
      spec {
        container {
          name              = "main"
          image             = "ghcr.io/demeter-run/ext-cardano-utxorpc-proxy:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          resources {
            limits = {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
          }

          port {
            name           = "metrics"
            container_port = local.prometheus_port
            protocol       = "TCP"
          }

          port {
            name           = "proxy"
            container_port = local.proxy_port
            protocol       = "TCP"
          }

          env {
            name  = "PROXY_NAMESPACE"
            value = var.namespace
          }

          env {
            name  = "PROXY_ADDR"
            value = local.proxy_addr
          }

          env {
            name  = "PROMETHEUS_ADDR"
            value = local.prometheus_addr
          }

          env {
            name  = "UTXORPC_DNS"
            value = "${var.namespace}.svc.cluster.local"
          }

          env {
            name  = "SSL_CRT_PATH"
            value = "/certs/tls.crt"
          }

          env {
            name  = "SSL_KEY_PATH"
            value = "/certs/tls.key"
          }

          volume_mount {
            mount_path = "/certs"
            name       = "certs"
          }
        }

        volume {
          name = "certs"
          config_map {
            name = var.certs_configmap
          }
        }

        dynamic "toleration" {
          for_each = var.tolerations

          content {
            effect   = toleration.value.effect
            key      = toleration.value.key
            operator = toleration.value.operator
            value    = toleration.value.value
          }
        }
      }
    }
  }
}

locals {
  prometheus_port  = 9187
  prometheus_addr  = "0.0.0.0:${local.prometheus_port}"
  proxy_port       = 8080
  proxy_addr       = "[::]:${local.proxy_port}"
  cert_secret_name = "utxorpc-${var.network}-proxy-wildcard-tls"
}

resource "kubernetes_stateful_set_v1" "utxorpc" {
  wait_for_rollout = false

  metadata {
    name      = local.instance
    namespace = var.namespace
    labels = {
      "demeter.run/kind"            = "UtxoRpcInstance"
      "cardano.demeter.run/network" = var.network
      "demeter.run/instance"        = local.instance
    }
  }
  spec {
    replicas     = var.replicas
    service_name = "utxorpc"

    selector {
      match_labels = {
        "demeter.run/instance"        = local.instance
        "cardano.demeter.run/network" = var.network
      }
    }
    template {
      metadata {
        labels = {
          "demeter.run/instance"        = local.instance
          "cardano.demeter.run/network" = var.network
        }
      }
      spec {
        init_container {
          name  = "init"
          image = "ghcr.io/txpipe/dolos:${var.dolos_version}"
          args = [
            "-c",
            "/etc/config/dolos.toml",
            "bootstrap",
            "snapshot",
            "--variant",
            "full"
          ]
          resources {
            limits   = var.resources.limits
            requests = var.resources.requests
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/config"
          }
          volume_mount {
            name       = "data"
            mount_path = "/var/data"
          }
        }

        container {
          name  = local.instance
          image = "ghcr.io/txpipe/dolos:${var.dolos_version}"
          args = [
            "-c",
            "/etc/config/dolos.toml",
            "daemon"
          ]
          resources {
            limits   = var.resources.limits
            requests = var.resources.requests
          }

          port {
            name           = "grpc"
            container_port = 50051
            protocol       = "TCP"
          }

          port {
            name           = "ouroboros"
            container_port = 30013
            protocol       = "TCP"
          }

          port {
            name           = "minibf"
            container_port = 3001
            protocol       = "TCP"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/data"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/config"
          }

          readiness_probe {
            tcp_socket {
              port = 50051
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }
        }

        container {
          name  = "proxy"
          image = "ghcr.io/demeter-run/ext-cardano-utxorpc-proxy:${var.proxy_image_tag}"

          resources {
            limits   = var.proxy_resources.limits
            requests = var.proxy_resources.requests
          }

          env {
            name  = "NETWORK"
            value = var.network
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
            name  = "UPSTREAM"
            value = "http://localhost:50051"
          }

          env {
            name  = "SSL_CRT_PATH"
            value = "/certs/tls.crt"
          }

          env {
            name  = "SSL_KEY_PATH"
            value = "/certs/tls.key"
          }

          port {
            name           = "proxy"
            container_port = local.proxy_port
            protocol       = "TCP"
          }

          port {
            name           = "metrics"
            container_port = local.prometheus_port
            protocol       = "TCP"
          }

          liveness_probe {
            tcp_socket {
              port = local.proxy_port
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          volume_mount {
            mount_path = "/certs"
            name       = "certs"
          }
        }

        volume {
          name = "certs"
          secret {
            secret_name = var.certs_secret_name == null ? local.cert_secret_name : var.certs_secret_name
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = var.pvc_name
          }
        }

        volume {
          name = "config"
          config_map {
            name = "configs-${var.network}"
          }
        }

        termination_grace_period_seconds = 180
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


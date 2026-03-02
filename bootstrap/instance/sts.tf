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
          image = var.dolos_image
          args = var.network == "vector-testnet" ? [
            "-c",
            "/etc/config/dolos.toml",
            "bootstrap",
            "relay",
            ] : [
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
          image = var.dolos_image
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

          dynamic "volume_mount" {
            for_each = var.network == "vector-testnet" ? toset([1]) : toset([])

            content {
              name       = "genesis"
              mount_path = "/genesis"
            }

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

        dynamic "volume" {
          for_each = var.network == "vector-testnet" ? toset([1]) : toset([])

          content {
            name = "genesis"

            config_map {
              name = "genesis-${var.network}"
            }
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

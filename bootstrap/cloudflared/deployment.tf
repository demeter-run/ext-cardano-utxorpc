resource "kubernetes_deployment" "cloudflared" {
  wait_for_rollout = false
  depends_on       = [kubernetes_secret.tunnel_credentials]

  metadata {
    name      = "cloudflared"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name" = "cloudflared"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "cloudflared"
        }

        annotations = {
          "kubectl.kubernetes.io/default-container" = "main"
        }
      }

      spec {
        container {
          name  = "main"
          image = "cloudflare/cloudflared:${var.image_tag}"
          args = [
            "tunnel",
            "--config",
            "/etc/cloudflared/config/config.yml",
            "run",
            "--protocol",
            "http2"
          ]

          liveness_probe {
            http_get {
              path = "/ready"
              port = var.metrics_port
            }
            failure_threshold     = 1
            period_seconds        = 10
            initial_delay_seconds = 10
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/cloudflared/config"
            read_only  = true
          }

          volume_mount {
            name       = "creds"
            mount_path = "/etc/cloudflared/creds"
            read_only  = true
          }

          port {
            name           = "metrics"
            container_port = var.metrics_port
            protocol       = "TCP"
          }

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
        }

        volume {
          name = "creds"
          secret {
            secret_name = local.credentials_secret_name
          }
        }

        volume {
          name = "config"
          config_map {
            name = local.configmap_name
            items {
              key  = "config.yml"
              path = "config.yml"
            }
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Exists"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-arch"
          operator = "Exists"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/availability-sla"
          operator = "Equal"
          value    = "consistent"
        }
      }
    }
  }
}

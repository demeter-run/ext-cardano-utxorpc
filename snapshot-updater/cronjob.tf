resource "kubernetes_cron_job_v1" "cronjob" {
  metadata {
    name      = "snapshot-updater-${var.network}-cronjob"
    namespace = var.namespace
  }

  spec {
    schedule = var.cron

    job_template {
      metadata {
        labels = {
          "cardano.demeter.run/network" = var.network
        }
      }

      spec {
        template {
          metadata {
            labels = {
              "cardano.demeter.run/network" = var.network
            }
          }

          spec {
            container {
              name    = "main"
              image   = "ghcr.io/txpipe/dolos:${var.dolos_version}"
              command = ["sh", "/etc/config/script.sh"]

              env {
                name  = "AWS_ACCESS_KEY_ID"
                value = var.aws_access_key_id
              }

              env {
                name  = "AWS_SECRET_ACCESS_KEY"
                value = var.aws_secret_access_key
              }

              resources {
                limits   = var.resources.limits
                requests = var.resources.requests
              }

              volume_mount {
                name       = "data"
                mount_path = "/var/data"
              }

              volume_mount {
                name       = "config"
                mount_path = "/etc/config"
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
                name = local.configmap_name
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
  }
}


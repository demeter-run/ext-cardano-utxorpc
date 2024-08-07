locals {
  port = 9946
}

resource "kubernetes_deployment_v1" "operator" {
  wait_for_rollout = false

  metadata {
    namespace = var.namespace
    name      = "operator"
    labels = {
      role = "operator"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        role = "operator"
      }
    }

    template {
      metadata {
        labels = {
          role = "operator"
        }
      }

      spec {
        container {
          image = "ghcr.io/demeter-run/ext-cardano-utxorpc-operator:${var.operator_image_tag}"
          name  = "main"

          env {
            name  = "ADDR"
            value = "0.0.0.0:${local.port}"
          }

          env {
            name  = "API_KEY_SALT"
            value = var.api_key_salt
          }

          env {
            name  = "NAMESPACE"
            value = var.namespace
          }

          env {
            name  = "EXTENSION_SUBDOMAIN"
            value = var.extension_subdomain
          }

          env {
            name  = "DNS_ZONE"
            value = var.dns_zone
          }

          resources {
            limits = {
              cpu    = "4"
              memory = "256Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "256Mi"
            }
          }

          port {
            name           = "metrics"
            container_port = local.port
            protocol       = "TCP"
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Equal"
          value    = "general-purpose"
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


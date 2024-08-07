resource "kubernetes_deployment_v1" "utxorpc_proxy" {
  wait_for_rollout = false
  depends_on       = [kubernetes_manifest.certificate_cluster_wildcard_tls]

  metadata {
    name      = local.name
    namespace = var.namespace
    labels = {
      role = local.role
    }
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        role = local.role
      }
    }
    template {
      metadata {
        name = local.name
        labels = {
          role = local.role
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
          secret {
            secret_name = local.certs_configmap
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
          operator = "Equal"
          value    = "x86"
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

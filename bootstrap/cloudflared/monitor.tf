resource "kubernetes_manifest" "monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      labels = {
        "app.kubernetes.io/component" = "o11y"
        "app.kubernetes.io/part-of"   = "demeter"
      }
      name      = "cloudflared"
      namespace = var.namespace
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "cloudflared"
        }
      }
      podMetricsEndpoints = [
        {
          port = "metrics",
          path = "/metrics"
        }
      ]
    }
  }
}

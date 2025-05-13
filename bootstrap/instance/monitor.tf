resource "kubernetes_manifest" "proxy_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      labels = {
        "app.kubernetes.io/component" = "o11y"
        "app.kubernetes.io/part-of"   = "demeter"
      }
      name      = "proxy-${local.instance}"
      namespace = var.namespace
    }
    spec = {
      selector = {
        matchLabels = {
          "demeter.run/instance"        = local.instance
          "cardano.demeter.run/network" = var.network
        }
      }
      podMetricsEndpoints = [
        {
          port = "proxy",
          path = "/metrics"
        }
      ]
    }
  }
}

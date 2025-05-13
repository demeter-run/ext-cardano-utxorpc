resource "kubernetes_manifest" "certificate_cluster_wildcard_tls" {
  for_each = var.extension_urls_per_network

  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Certificate"
    "metadata" = {
      "name"      = "utxorpc-${each.key}-proxy-wildcard-tls"
      "namespace" = var.namespace
    }
    "spec" = {
      "dnsNames" = each.value

      "issuerRef" = {
        "kind" = "ClusterIssuer"
        "name" = "letsencrypt-dns01"
      }
      "secretName" = "utxorpc-${each.key}-proxy-wildcard-tls"
    }
  }
}

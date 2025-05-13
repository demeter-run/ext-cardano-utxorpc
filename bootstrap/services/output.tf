output "load_balancer_urls" {
  value = {
    "cardano-mainnet" : try(
      kubernetes_service_v1.proxy_service["cardano-mainnet"].status.0.load_balancer.0.ingress.0.hostname,
      null
    )
    "cardano-preprod" : try(
      kubernetes_service_v1.proxy_service["cardano-preprod"].status.0.load_balancer.0.ingress.0.hostname,
      null
    )
    "cardano-preview" : try(
      kubernetes_service_v1.proxy_service["cardano-preview"].status.0.load_balancer.0.ingress.0.hostname,
      null
    )
  }
}




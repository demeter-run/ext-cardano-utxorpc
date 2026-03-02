output "load_balancer_urls" {
  value = {
    "cardano-mainnet" : try(module.proxies["cardano-mainnet"].load_balancer_url, null)
    "cardano-preprod" : try(module.proxies["cardano-preprod"].load_balancer_url, null)
    "cardano-preview" : try(module.proxies["cardano-preview"].load_balancer_url, null)
  }
}

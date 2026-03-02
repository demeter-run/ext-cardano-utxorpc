output "load_balancer_url" {
  value = kubernetes_service_v1.proxy_service.status.0.load_balancer.0.ingress.0.hostname
}

variable "namespace" {
  type = string
}

variable "operator_image_tag" {
  type = string
}

variable "api_key_salt" {
  type = string
}

variable "extension_urls_per_network" {
  type = map(list(string))
}

variable "metrics_delay" {
  description = "the inverval for polling metrics data (in seconds)"
  default     = "60"
}

variable "metrics_step" {
  description = "the metrics prometheus step"
  default     = "10s"
}

variable "prometheus_url" {
  type    = string
  default = "http://prometheus-operated.demeter-system.svc.cluster.local:9090/api/v1"
}

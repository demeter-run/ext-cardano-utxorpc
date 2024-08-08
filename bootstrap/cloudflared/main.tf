variable "namespace" {
  type = string
}

variable "tunnel_id" {
  type = string
}

variable "metrics_port" {
  type    = number
  default = 2000
}

variable "hostname" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "resources" {
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits : {
      cpu : "1",
      memory : "500Mi"
    }
    requests : {
      cpu : "50m",
      memory : "500Mi"
    }
  }
}

variable "account_tag" {
  type    = string
  default = "AccountTag, written on credentials json."
}

variable "tunnel_secret" {
  type    = string
  default = "TunnelSecret, written on credentials json."
}

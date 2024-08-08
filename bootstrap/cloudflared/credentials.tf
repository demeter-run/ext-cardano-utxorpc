locals {
  credentials_secret_name = "tunnel-credentials"
}

resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    namespace = var.namespace
    name      = local.credentials_secret_name
  }

  data = {
    "credentials.json" = jsonencode({
      "AccountTag" : var.account_tag,
      "TunnelSecret" : var.tunnel_secret,
      "TunnelID" : var.tunnel_id
    })
  }

  type = "Opaque"
}



locals {
  config = {
    "mainnet" : {
      "magic" : 764824073,
      "address" : "node-mainnet-stable.ext-nodes-m1.svc.cluster.local:3000",
      "is_testnet" : "false",
      "aggregator" : "https://aggregator.release-mainnet.api.mithril.network/aggregator",
      "genesis_key" : "5b3139312c36362c3134302c3138352c3133382c31312c3233372c3230372c3235302c3134342c32372c322c3138382c33302c31322c38312c3135352c3230342c31302c3137392c37352c32332c3133382c3139362c3231372c352c31342c32302c35372c37392c33392c3137365d",
    },
    "preprod" : {
      "magic" : 1,
      "address" : "node-preprod-stable.ext-nodes-m1.svc.cluster.local:3000",
      "is_testnet" : "true",
      "aggregator" : "https://aggregator.release-preprod.api.mithril.network/aggregator",
      "genesis_key" : "5b3132372c37332c3132342c3136312c362c3133372c3133312c3231332c3230372c3131372c3139382c38352c3137362c3139392c3136322c3234312c36382c3132332c3131392c3134352c31332c3233322c3234332c34392c3232392c322c3234392c3230352c3230352c33392c3233352c34345d"
    },
    "preview" : {
      "magic" : 2,
      "address" : "node-preview-stable.ext-nodes-m1.svc.cluster.local:3000",
      "is_testnet" : "true",
      "aggregator" : "https://aggregator.pre-release-preview.api.mithril.network/aggregator",
      "genesis_key" : "5b3132372c37332c3132342c3136312c362c3133372c3133312c3231332c3230372c3131372c3139382c38352c3137362c3139392c3136322c3234312c36382c3132332c3131392c3134352c31332c3233322c3234332c34392c3232392c322c3234392c3230352c3230352c33392c3233352c34345d",
  } }
}

resource "kubernetes_config_map" "config" {
  metadata {
    namespace = var.namespace
    name      = local.configmap_name
  }

  data = {
    "dolos.toml" = "${templatefile(
      "${path.module}/dolos.toml.tftpl",
      {
        network             = var.network
        address             = local.config[var.network]["address"]
        magic               = local.config[var.network]["magic"]
        is_testnet          = local.config[var.network]["is_testnet"]
        mithril_aggregator  = local.config[var.network]["aggregator"]
        mithril_genesis_key = local.config[var.network]["genesis_key"]
      }
    )}",
    "script.sh" = "${templatefile(
      "${path.module}/script.sh.tftpl",
      {
        network   = var.network
        bucket    = var.bucket
        prefix    = var.prefix
        magic     = local.config[var.network]["magic"]
        bootstrap = var.bootstrap
      }
    )}",
  }
}

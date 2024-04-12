# UtxoRpc Proxy

This proxy will allow UtxoRpc to be accessed externally.

## Environment

| Key          | Value            |
| ------------ | ---------------- |
| PROXY_ADDR   | 0.0.0.0:5000     |
| SSL_CRT_PATH | /localhost.crt   |
| SSL_KEY_PATH | /localhost.key   |
| UTXORPC_PORT |                  |
| UTXORPC_DNS  | internal k8s dns |

## Commands

To generate the CRD will need to execute `crdgen`

```bash
cargo run --bin=crdgen
```

and execute the operator

```bash
cargo run
```

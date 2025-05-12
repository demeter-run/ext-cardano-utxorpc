# UTxORPC Proxy

This proxy will allow UTxORPC to be accessed externally.

## Environment

| Key               | Value                                            |
| ----------------- | ------------------------------------------------ |
| PROXY_ADDR        | 0.0.0.0:5000                                     |
| PROXY_NAMESPACE   |                                                  |
| PROMETHEUS_ADDR   | 0.0.0.0:9090                                     |
| SSL_CRT_PATH      | /localhost.crt                                   |
| SSL_KEY_PATH      | /localhost.key                                   |
| UPSTREAM          | URI where to proxy to eg(http://localhost:50051) |

## Commands

To generate the CRD will need to execute `crdgen`

```bash
cargo run --bin=crdgen
```

and execute the operator

```bash
cargo run
```

## Metrics

To collect metrics for Prometheus, an HTTP API will enable the route /metrics
on the address defined by the PROMETHEUS_ADDR config.

```
/metrics
```

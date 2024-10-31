use chrono::Utc;
use http_body_util::{combinators::BoxBody, BodyExt, Full};
use hyper::{body::Bytes, server::conn::http1, service::service_fn, Response};
use hyper_util::rt::TokioIo;
use kube::{Resource, ResourceExt};
use prometheus::{opts, Encoder, IntCounterVec, Registry, TextEncoder};
use regex::Regex;
use serde::{Deserialize, Deserializer};
use std::{net::SocketAddr, str::FromStr, sync::Arc};
use tokio::net::TcpListener;
use tracing::{error, info, instrument, warn};

use crate::{get_config, Error, State, UtxoRpcPort};

#[derive(Clone)]
pub struct Metrics {
    pub usage: IntCounterVec,
    pub reconcile_failures: IntCounterVec,
    pub metrics_failures: IntCounterVec,
}

impl Default for Metrics {
    fn default() -> Self {
        let usage = IntCounterVec::new(
            opts!("usage", "Feature usage",),
            &["feature", "project", "resource_name", "tier"],
        )
        .unwrap();

        let reconcile_failures = IntCounterVec::new(
            opts!(
                "utxorpc_operator_crd_reconciliation_errors_total",
                "reconciliation errors",
            ),
            &["instance", "error"],
        )
        .unwrap();

        let metrics_failures = IntCounterVec::new(
            opts!(
                "utxorpc_operator_metrics_errors_total",
                "errors to calculation metrics",
            ),
            &["error"],
        )
        .unwrap();

        Metrics {
            usage,
            reconcile_failures,
            metrics_failures,
        }
    }
}

impl Metrics {
    pub fn register(self, registry: &Registry) -> Result<Self, prometheus::Error> {
        registry.register(Box::new(self.usage.clone()))?;
        registry.register(Box::new(self.reconcile_failures.clone()))?;
        registry.register(Box::new(self.metrics_failures.clone()))?;

        Ok(self)
    }

    pub fn reconcile_failure(&self, crd: &UtxoRpcPort, e: &Error) {
        self.reconcile_failures
            .with_label_values(&[crd.name_any().as_ref(), e.metric_label().as_ref()])
            .inc()
    }

    pub fn metrics_failure(&self, e: &Error) {
        self.metrics_failures
            .with_label_values(&[e.metric_label().as_ref()])
            .inc()
    }

    pub fn count_usage(&self, project: &str, resource_name: &str, tier: &str, value: u64) {
        let feature = &UtxoRpcPort::kind(&());

        self.usage
            .with_label_values(&[feature, project, resource_name, tier])
            .inc_by(value);
    }
}

pub fn run_metrics_server(state: Arc<State>) {
    tokio::spawn(async move {
        let addr = std::env::var("ADDR").unwrap_or("0.0.0.0:8080".into());
        let addr_result = SocketAddr::from_str(&addr);
        if let Err(err) = addr_result {
            error!(error = err.to_string(), "invalid prometheus addr");
            std::process::exit(1);
        }
        let addr = addr_result.unwrap();

        let listener_result = TcpListener::bind(addr).await;
        if let Err(err) = listener_result {
            error!(
                error = err.to_string(),
                "fail to bind tcp prometheus server listener"
            );
            std::process::exit(1);
        }
        let listener = listener_result.unwrap();

        info!(addr = addr.to_string(), "metrics listening");

        loop {
            let state = state.clone();

            let accept_result = listener.accept().await;
            if let Err(err) = accept_result {
                error!(error = err.to_string(), "accept client prometheus server");
                continue;
            }
            let (stream, _) = accept_result.unwrap();

            let io = TokioIo::new(stream);

            tokio::task::spawn(async move {
                let service = service_fn(move |_| api_get_metrics(state.clone()));

                if let Err(err) = http1::Builder::new().serve_connection(io, service).await {
                    error!(error = err.to_string(), "failed metrics server connection");
                }
            });
        }
    });
}

async fn api_get_metrics(
    state: Arc<State>,
) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    let metrics = state.metrics_collected();

    let encoder = TextEncoder::new();
    let mut buffer = vec![];
    encoder.encode(&metrics, &mut buffer).unwrap();

    let res = Response::builder()
        .body(
            Full::new(buffer.into())
                .map_err(|never| match never {})
                .boxed(),
        )
        .unwrap();
    Ok(res)
}

#[instrument("metrics collector run", skip_all)]
pub fn run_metrics_collector(state: Arc<State>) {
    tokio::spawn(async move {
        info!("collecting metrics running");

        let client = reqwest::Client::builder().build().unwrap();
        let config = get_config();
        let project_regex = Regex::new(r"prj-(.+)\.(.+)$").unwrap();
        let network_regex = Regex::new(r"cardano-?([\w-]+)").unwrap();
        let mut start = Utc::now();

        loop {
            tokio::time::sleep(config.metrics_delay).await;

            let end = Utc::now();

            let response =  client
            .get(format!(
                "{}/query_range?query=sum by (consumer, network, tier) (utxorpc_proxy_total_requests{{status_code!~\"401|429|503\"}})",
                &config.prometheus_url
            ))
            .query(&[
                ("start", start.timestamp().to_string()),
                ("end", end.timestamp().to_string()),
                ("step", config.metrics_step.clone()),
            ])
            .send()
            .await;
            if let Err(err) = response {
                error!(error = err.to_string(), "error to make prometheus request");
                state.metrics.metrics_failure(&err.into());
                continue;
            }
            let response = response.unwrap();
            let status = response.status();
            if status.is_client_error() || status.is_server_error() {
                error!(status = status.to_string(), "Prometheus request error");
                state.metrics.metrics_failure(&Error::HttpError(format!(
                    "Prometheus request error. Status: {}",
                    status
                )));
                continue;
            }

            start = end;

            let response: PrometheusResponse = response.json().await.unwrap();

            for result in response.data.result {
                let min = result.values.iter().min_by_key(|v| v.timestamp);
                let max = result.values.iter().max_by_key(|v| v.timestamp);

                let first_value = match min {
                    Some(v) => v.value,
                    None => 0,
                };
                let last_value = match max {
                    Some(v) => v.value,
                    None => 0,
                };

                let value = (last_value - first_value) as u64;

                let consumer = result.metric.consumer;
                let project_captures = project_regex.captures(&consumer);
                if project_captures.is_none() {
                    warn!(consumer, "invalid project to the regex");
                    continue;
                }
                let project_captures = project_captures.unwrap();
                let project = project_captures.get(1).unwrap().as_str();
                let resource_name = project_captures.get(2).unwrap().as_str();

                let network = result.metric.network;
                let network_captures = network_regex.captures(&network);
                if network_captures.is_none() {
                    warn!(network, "invalid network to the regex");
                    continue;
                }
                let tier = result.metric.tier;

                state
                    .metrics
                    .count_usage(project, resource_name, &tier, value);
            }
        }
    });
}

#[derive(Debug, Deserialize)]
struct PrometheusResponse {
    data: PrometheusData,
}
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PrometheusData {
    result: Vec<PrometheusDataResult>,
}
#[derive(Debug, Deserialize)]
struct PrometheusDataResult {
    metric: PrometheusDataResultMetric,
    values: Vec<PrometheusValue>,
}
#[derive(Debug, Deserialize)]
struct PrometheusDataResultMetric {
    consumer: String,
    network: String,
    tier: String,
}
#[derive(Debug, Deserialize)]
struct PrometheusValue {
    #[serde(rename = "0")]
    timestamp: u64,

    #[serde(rename = "1")]
    #[serde(deserialize_with = "deserialize_value")]
    value: i64,
}

fn deserialize_value<'de, D>(deserializer: D) -> Result<i64, D::Error>
where
    D: Deserializer<'de>,
{
    let value = String::deserialize(deserializer)?;
    Ok(value.parse().unwrap())
}

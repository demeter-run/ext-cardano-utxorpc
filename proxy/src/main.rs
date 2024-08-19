use auth::AuthBackgroundService;
use config::Config;
use dotenv::dotenv;
use health::HealthBackgroundService;
use operator::{kube::ResourceExt, UtxoRpcPort};
use pingora::{
    server::{configuration::Opt, Server},
    services::background::background_service,
};
use prometheus::{opts, register_int_counter_vec};
use proxy::UtxoRpcProxy;
use std::{collections::HashMap, fmt::Display, sync::Arc};
use tokio::sync::RwLock;
use tracing::Level;

mod auth;
mod config;
mod health;
mod proxy;

fn main() {
    dotenv().ok();

    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let config: Arc<Config> = Arc::default();
    let state: Arc<State> = Arc::default();

    let opt = Opt::default();
    let mut server = Server::new(Some(opt)).unwrap();
    server.bootstrap();

    let auth_background_service = background_service(
        "K8S Auth Service",
        AuthBackgroundService::new(state.clone()),
    );
    server.add_service(auth_background_service);

    let mut utxorpc_http_proxy = pingora::proxy::http_proxy_service(
        &server.configuration,
        UtxoRpcProxy::new(state.clone(), config.clone()),
    );
    let mut tls_settings =
        pingora::listeners::TlsSettings::intermediate(&config.ssl_crt_path, &config.ssl_key_path)
            .unwrap();

    tls_settings.enable_h2();
    utxorpc_http_proxy.add_tls_with_settings(&config.proxy_addr, None, tls_settings);
    server.add_service(utxorpc_http_proxy);

    let mut prometheus_service = pingora::services::listening::Service::prometheus_http_service();
    prometheus_service.add_tcp(&config.prometheus_addr);
    server.add_service(prometheus_service);

    let health_background_service = background_service(
        "K8S Auth Service",
        HealthBackgroundService::new(state.clone(), config.clone()),
    );
    server.add_service(health_background_service);

    server.run_forever();
}

#[derive(Default)]
pub struct State {
    consumers: RwLock<HashMap<String, Consumer>>,
    metrics: Metrics,
    upstream_health: RwLock<bool>,
}
impl State {
    pub async fn get_consumer(&self, key: &str) -> Option<Consumer> {
        let consumers = self.consumers.read().await.clone();
        consumers.get(key).cloned()
    }
}

#[derive(Debug, Clone, Default)]
pub struct Consumer {
    namespace: String,
    port_name: String,
    tier: String,
    key: String,
    network: String,
}
impl Display for Consumer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}.{}", self.namespace, self.port_name)
    }
}
impl From<&UtxoRpcPort> for Consumer {
    fn from(value: &UtxoRpcPort) -> Self {
        let network = value.spec.network.to_string();
        let tier = value
            .spec
            .throughput_tier
            .clone()
            .unwrap_or("0".to_string());
        let key = value.status.as_ref().unwrap().auth_token.clone();
        let namespace = value.metadata.namespace.as_ref().unwrap().clone();
        let port_name = value.name_any();

        Self {
            namespace,
            port_name,
            tier,
            key,
            network,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Metrics {
    http_total_request: prometheus::IntCounterVec,
}
impl Metrics {
    pub fn new() -> Self {
        let http_total_request = register_int_counter_vec!(
            opts!("utxorpc_proxy_total_requests", "Total requests",),
            &[
                "consumer",
                "namespace",
                "instance",
                "status_code",
                "network",
                "tier"
            ]
        )
        .unwrap();

        Self { http_total_request }
    }

    pub fn inc_http_total_request(
        &self,
        consumer: &Consumer,
        namespace: &str,
        instance: &str,
        status: &u16,
    ) {
        self.http_total_request
            .with_label_values(&[
                &consumer.to_string(),
                namespace,
                instance,
                &status.to_string(),
                &consumer.network,
                &consumer.tier,
            ])
            .inc()
    }
}
impl Default for Metrics {
    fn default() -> Self {
        Self::new()
    }
}

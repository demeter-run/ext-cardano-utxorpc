use config::Config;
use dotenv::dotenv;
use metrics::Metrics;
use operator::{handle_legacy_networks, kube::ResourceExt, UtxoRpcPort};
use prometheus::Registry;
use std::{collections::HashMap, fmt::Display, sync::Arc};
use tokio::sync::RwLock;
use tokio_util::sync::CancellationToken;
use tracing::{info, Level};

mod auth;
mod config;
mod metrics;
mod proxy;
mod services;

#[tokio::main]
async fn main() {
    dotenv().ok();

    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let registry = Registry::default();
    tonic_prometheus_layer::metrics::try_init_settings(
        tonic_prometheus_layer::metrics::GlobalSettings {
            histogram_buckets: vec![0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0],
            registry: registry.clone(),
        },
    )
    .expect("failed to init prometheus layer.");

    let exit = hook_exit_token();

    let config = Config::new();
    let state: Arc<State> = Arc::new(State::new(registry).await);

    info!("Serving on {}", config.proxy_addr);
    let proxy = async {
        tokio::select! {
            _  =  proxy::serve(state.clone(), &config)  => {

            }
            _ = exit.cancelled() => {

            }
        }
    };

    let auth = async {
        tokio::select! {
            _  =  auth::run(state.clone())  => {

            }
            _ = exit.cancelled() => {

            }
        }
    };

    let metrics = async {
        tokio::select! {
            _  =  metrics::run(&config)  => {

            }
            _ = exit.cancelled() => {

            }
        }
    };

    tokio::join!(proxy, auth, metrics);
}

pub struct State {
    consumers: RwLock<HashMap<String, Consumer>>,
    metrics: Metrics,
}
impl State {
    pub async fn new(registry: Registry) -> Self {
        Self {
            metrics: Metrics::new(registry),
            consumers: Default::default(),
        }
    }
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
        let network = handle_legacy_networks(&value.spec.network);
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

async fn wait_for_exit_signal() {
    let mut sigterm =
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()).unwrap();

    tokio::select! {
        _ = tokio::signal::ctrl_c() => {
            tracing::warn!("SIGINT detected");
        }
        _ = sigterm.recv() => {
            tracing::warn!("SIGTERM detected");
        }
    };
}

pub fn hook_exit_token() -> CancellationToken {
    let cancel = CancellationToken::new();

    let cancel2 = cancel.clone();
    tokio::spawn(async move {
        wait_for_exit_signal().await;
        tracing::debug!("notifying exit");
        cancel2.cancel();
    });

    cancel
}

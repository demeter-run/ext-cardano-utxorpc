use config::Config;
use dotenv::dotenv;
use metrics::Metrics;
use operator::{handle_legacy_networks, kube::ResourceExt, UtxoRpcPort};
use std::{collections::HashMap, fmt::Display, sync::Arc};
use tokio::sync::RwLock;
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

    tonic_prometheus_layer::metrics::try_init_settings(
        tonic_prometheus_layer::metrics::GlobalSettings {
            histogram_buckets: vec![0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0],
            ..Default::default()
        },
    )
    .expect("failed to init prometheus layer.");

    let config = Config::new();
    let state: Arc<State> = Arc::default();

    info!("Serving on {}", config.proxy_addr);
    let proxy = async {
        proxy::serve(state.clone(), &config)
            .await
            .expect("Failed to run server")
    };

    let auth = async {
        auth::run(state.clone()).await;
    };

    let metrics = async {
        metrics::run(&config).await;
    };

    tokio::join!(proxy, auth, metrics);
}

#[derive(Default)]
pub struct State {
    consumers: RwLock<HashMap<String, Consumer>>,
    metrics: Metrics,
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

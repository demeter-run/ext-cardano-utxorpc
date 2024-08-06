use auth::AuthBackgroundService;
use config::Config;
use dotenv::dotenv;
use operator::{kube::ResourceExt, UtxoRpcPort};
use pingora::{
    listeners::Listeners,
    server::{configuration::Opt, Server},
    services::{background::background_service, listening::Service},
};
use proxy::UtxoRpcProxy;
use std::{collections::HashMap, fmt::Display, sync::Arc};
use tokio::sync::RwLock;
use tracing::Level;

mod auth;
mod config;
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

    let tls_proxy_service = Service::with_listeners(
        "TLS Proxy Service".to_string(),
        Listeners::tls(
            &config.proxy_addr,
            &config.ssl_crt_path,
            &config.ssl_key_path,
        )
        .unwrap(),
        Arc::new(UtxoRpcProxy::new(state.clone(), config.clone())),
    );
    server.add_service(tls_proxy_service);

    server.run_forever();
}

#[derive(Default)]
pub struct State {
    consumers: RwLock<HashMap<String, Consumer>>,
}
impl State {
    pub async fn get_consumer(&self, key: &str) -> Option<Consumer> {
        let consumers = self.consumers.read().await.clone();
        consumers.get(key).cloned()
    }
}

#[derive(Debug, Clone, Default)]
pub struct Consumer {
    key: String,
    namespace: String,
    port_name: String,
    network: String,
    version: String,
}
impl Consumer {
    pub fn new(
        key: String,
        namespace: String,
        port_name: String,
        network: String,
        version: String,
    ) -> Self {
        Self {
            key,
            namespace,
            port_name,
            network,
            version,
        }
    }
}
impl Display for Consumer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}.{}", self.namespace, self.port_name)
    }
}

impl From<&UtxoRpcPort> for Consumer {
    fn from(value: &UtxoRpcPort) -> Self {
        let network = value.spec.network.to_string();
        let key = value.status.as_ref().unwrap().auth_token.clone();
        let version = value.spec.utxorpc_version.clone().unwrap_or("v1".into());
        let namespace = value.metadata.namespace.as_ref().unwrap().clone();
        let port_name = value.name_any();

        Self {
            key,
            namespace,
            port_name,
            network,
            version,
        }
    }
}

use async_trait::async_trait;
use pingora::{server::ShutdownWatch, services::background::BackgroundService};
use std::sync::Arc;
use tracing::{info, warn};

use crate::{Config, State};

pub struct HealthBackgroundService {
    state: Arc<State>,
    config: Arc<Config>,
}
impl HealthBackgroundService {
    pub fn new(state: Arc<State>, config: Arc<Config>) -> Self {
        Self { state, config }
    }

    async fn get_health(&self) -> bool {
        let Some(instance) = self
            .config
            .utxorpc_instances
            .get(&self.config.health_network)
            .cloned()
        else {
            warn!(
                network = self.config.health_network,
                "Health network is missing from UTXORPC_INSTANCES"
            );
            return false;
        };

        match tokio::net::TcpStream::connect(&instance).await {
            Ok(_) => true,
            Err(err) => {
                warn!(
                    error = %err,
                    instance = %instance,
                    "Error pinging instance for health."
                );
                false
            }
        }
    }

    async fn update_health(&self) {
        let current_health = *self.state.upstream_health.read().await;

        let new_health = self.get_health().await;

        match (current_health, new_health) {
            (false, true) => info!("Upstream is now healthy, ready to proxy requests."),
            (true, false) => warn!("Upstream is now deamed unhealthy, no pods in running state"),
            _ => {}
        }

        *self.state.upstream_health.write().await = new_health;
    }
}

#[async_trait]
impl BackgroundService for HealthBackgroundService {
    async fn start(&self, mut _shutdown: ShutdownWatch) {
        loop {
            self.update_health().await;
            tokio::time::sleep(self.config.health_pool_interval).await;
        }
    }
}

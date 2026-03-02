use async_trait::async_trait;
use operator::{
    k8s_openapi::api::core::v1::{Endpoints, Pod},
    kube::{api::ListParams, Api, Client},
};
use pingora::{server::ShutdownWatch, services::background::BackgroundService};
use std::{collections::HashSet, sync::Arc};
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
        // Create a Kubernetes client
        let client = Client::try_default()
            .await
            .expect("Unable to instance k8s client.");

        // Get the Endpoints associated with the service
        let endpoints_api: Api<Endpoints> = Api::default_namespaced(client.clone());
        let endpoints = match endpoints_api.get(&self.config.service()).await {
            Ok(endpoints) => endpoints,
            Err(err) => {
                warn!(
                    error = err.to_string(),
                    "Error getting endpoints for health."
                );
                return false;
            }
        };

        // Extract the IPs of the pods from the Endpoints
        let mut pod_ips = HashSet::new();
        if let Some(subsets) = endpoints.subsets {
            for subset in subsets {
                if let Some(addresses) = subset.addresses {
                    for address in addresses {
                        pod_ips.insert(address.ip);
                    }
                }
            }
        }

        // Get the Pods in the namespace
        let pods_api: Api<Pod> = Api::default_namespaced(client);
        let pods = match pods_api.list(&ListParams::default()).await {
            Ok(pods) => pods,
            Err(err) => {
                warn!(error = err.to_string(), "Error getting pods for health.");
                return false;
            }
        };

        // Filter the pods to match the IPs found in the Endpoints
        let running_pods: Vec<_> = pods
            .items
            .into_iter()
            .filter(|pod| {
                if let Some(status) = &pod.status {
                    if let Some(pod_ip) = &status.pod_ip {
                        return pod_ips.contains(pod_ip);
                    }
                }
                false
            })
            .collect();

        !running_pods.is_empty()
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

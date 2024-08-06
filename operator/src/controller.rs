use futures::StreamExt;
use kube::{
    runtime::{controller::Action, watcher::Config as WatcherConfig, Controller},
    Api, Client, CustomResource, CustomResourceExt, ResourceExt,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::{sync::Arc, time::Duration};
use tracing::{error, info, instrument};

use crate::{build_api_key, build_hostname, patch_resource_status, Error, Metrics, Result, State};

pub static UTXORPX_PORT_FINALIZER: &str = "utxorpcports.demeter.run";

struct Context {
    pub client: Client,
    pub metrics: Metrics,
}
impl Context {
    pub fn new(client: Client, metrics: Metrics) -> Self {
        Self { client, metrics }
    }
}

#[derive(CustomResource, Deserialize, Serialize, Clone, Debug, JsonSchema)]
#[kube(
    kind = "UtxoRpcPort",
    group = "demeter.run",
    version = "v1alpha1",
    shortname = "utxoport",
    category = "demeter-port",
    plural = "utxorpcports",
    namespaced
)]
#[kube(status = "UtxoRpcPortStatus")]
#[kube(printcolumn = r#"
        {"name": "Network", "jsonPath": ".spec.network", "type": "string"},
        {"name": "Throughput Tier", "jsonPath":".spec.throughputTier", "type": "string"}, 
        {"name": "UtxoRPC Version", "jsonPath": ".spec.utxorpcVersion", "type": "string"},
        {"name": "Endpoint", "jsonPath": ".status.grpcEndpointUrl", "type": "string"},
        {"name": "Auth Token", "jsonPath": ".status.authToken", "type": "string"}
    "#)]
#[serde(rename_all = "camelCase")]
pub struct UtxoRpcPortSpec {
    pub operator_version: String,
    pub network: String,
    pub throughput_tier: Option<String>,
    pub utxorpc_version: Option<String>,
    pub auth_token: Option<String>,
}

#[derive(Deserialize, Serialize, Clone, Default, Debug, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct UtxoRpcPortStatus {
    pub grpc_endpoint_url: String,
    pub auth_token: String,
}

async fn reconcile(crd: Arc<UtxoRpcPort>, ctx: Arc<Context>) -> Result<Action> {
    let key = match &crd.spec.auth_token {
        Some(key) => key.clone(),
        None => build_api_key(&crd).await?,
    };
    let (hostname, _) = build_hostname(&key);

    let status = UtxoRpcPortStatus {
        grpc_endpoint_url: hostname,
        auth_token: key,
    };

    let namespace = crd.namespace().unwrap();
    let utxorpc_port = UtxoRpcPort::api_resource();

    patch_resource_status(
        ctx.client.clone(),
        &namespace,
        utxorpc_port,
        &crd.name_any(),
        serde_json::to_value(status)?,
    )
    .await?;

    info!(resource = crd.name_any(), "Reconcile completed");

    Ok(Action::await_change())
}

fn error_policy(crd: Arc<UtxoRpcPort>, err: &Error, ctx: Arc<Context>) -> Action {
    error!(error = err.to_string(), "reconcile failed");
    ctx.metrics.reconcile_failure(&crd, err);
    Action::requeue(Duration::from_secs(5))
}

#[instrument("controller run", skip_all)]
pub async fn run(state: Arc<State>) {
    info!("listening crds running");

    let client = Client::try_default()
        .await
        .expect("failed to create kube client");

    let crds = Api::<UtxoRpcPort>::all(client.clone());

    let ctx = Context::new(client, state.metrics.clone());

    Controller::new(crds, WatcherConfig::default().any_semantic())
        .shutdown_on_signal()
        .run(reconcile, error_policy, Arc::new(ctx))
        .filter_map(|x| async move { std::result::Result::ok(x) })
        .for_each(|_| futures::future::ready(()))
        .await;
}

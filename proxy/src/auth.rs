use std::sync::Arc;

use futures_util::TryStreamExt;

use operator::{
    kube::{
        runtime::watcher::{self, Config as ConfigWatcher, Event},
        Api, Client, ResourceExt,
    },
    UtxoRpcPort,
};
use tokio::pin;
use tracing::{error, info};

use crate::{Consumer, State};

pub async fn run(state: Arc<State>) {
    let client = Client::try_default()
        .await
        .expect("failed to create kube client");

    let api = Api::<UtxoRpcPort>::all(client.clone());
    let stream = watcher::watcher(api.clone(), ConfigWatcher::default());
    pin!(stream);

    loop {
        let result = stream.try_next().await;
        match result {
            Ok(Some(Event::Init)) => {
                info!("auth: Watcher restarted, reseting consumers");
                state.consumers.write().await.clear();
            }

            Ok(Some(Event::InitApply(crd))) => {
                info!("auth: Adding consumer: {}", crd.name_any());
                let consumer = Consumer::from(&crd);
                state
                    .consumers
                    .write()
                    .await
                    .insert(consumer.key.clone(), consumer);
            }

            Ok(Some(Event::InitDone)) => {
                info!("auth: Watcher completed restart.");
            }

            Ok(Some(Event::Apply(crd))) => match crd.status {
                Some(_) => {
                    info!("auth: Updating consumer: {}", crd.name_any());
                    let consumer = Consumer::from(&crd);
                    state
                        .consumers
                        .write()
                        .await
                        .insert(consumer.key.clone(), consumer);
                }
                None => {
                    // New ports are created without status. When the status is added, a new
                    // Applied event is triggered.
                    info!("auth: New port created: {}", crd.name_any());
                }
            },

            Ok(Some(Event::Delete(crd))) => {
                info!(
                    "auth: Port deleted, removing from state: {}",
                    crd.name_any()
                );
                let consumer = Consumer::from(&crd);
                state.consumers.write().await.remove(&consumer.key);
            }

            Ok(None) => {
                error!("auth: Empty response from watcher.");
                continue;
            }
            // Unexpected error when streaming CRDs.
            Err(err) => {
                error!(error = err.to_string(), "auth: Failed to update crds.");
                std::process::exit(1);
            }
        }
    }
}

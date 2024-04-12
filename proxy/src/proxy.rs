use std::{net::SocketAddr, sync::Arc};

use async_trait::async_trait;
use pingora::{
    apps::ServerApp, connectors::TransportConnector, protocols::Stream, server::ShutdownWatch,
    tls::ssl::NameType, upstreams::peer::BasicPeer,
};
use regex::Regex;
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::lookup_host,
    select,
};
use tracing::error;

use crate::{config::Config, State};

enum DuplexEvent {
    ClientRead(usize),
    InstanceRead(usize),
}

pub struct UtxoRpcProxy {
    client_connector: TransportConnector,
    state: Arc<State>,
    config: Arc<Config>,
    host_regex: Regex,
}
impl UtxoRpcProxy {
    pub fn new(state: Arc<State>, config: Arc<Config>) -> Self {
        let client_connector = TransportConnector::new(None);
        let host_regex = Regex::new(r"(dmtr_[\w\d-]+)\..+").unwrap();

        Self {
            client_connector,
            state,
            config,
            host_regex,
        }
    }
}

#[async_trait]
impl ServerApp for UtxoRpcProxy {
    async fn process_new(
        self: &Arc<Self>,
        mut io_client: Stream,
        _shutdown: &ShutdownWatch,
    ) -> Option<Stream> {
        let hostname = io_client.get_ssl()?.servername(NameType::HOST_NAME);
        if hostname.is_none() {
            error!("hostname is not present in the certificate");
            return None;
        }

        let captures_result = self.host_regex.captures(hostname?);
        if captures_result.is_none() {
            error!("invalid hostname pattern");
            return None;
        }
        let captures = captures_result?;
        let key = captures.get(1)?.as_str().to_string();
        let consumer = self.state.get_consumer(&key).await?;

        let instance = format!(
            "utxorpc-{}-{}.{}:{}",
            consumer.network, consumer.version, self.config.utxorpc_dns, self.config.utxorpc_port
        );

        let lookup_result = lookup_host(&instance).await;
        if let Err(err) = lookup_result {
            error!(error = err.to_string(), "fail to lookup ip");
            return None;
        }
        let lookup: Vec<SocketAddr> = lookup_result.unwrap().collect();
        let node_addr = lookup.first()?;

        let proxy_to = BasicPeer::new(&node_addr.to_string());

        let io_instance = self.client_connector.new_stream(&proxy_to).await;

        let mut io_client_buf = [0; 1024];
        let mut io_instance_buf = [0; 1024];

        match io_instance {
            Ok(mut io_instance) => loop {
                let event: DuplexEvent;

                select! {
                    n = io_client.read(&mut io_client_buf) => {
                        match n {
                            Ok(b) => event = DuplexEvent::ClientRead(b),
                            Err(_) => {
                                event = DuplexEvent::ClientRead(0);
                            },
                        }
                    },
                    n = io_instance.read(&mut io_instance_buf) => {
                        match n {
                            Ok(b) => event = DuplexEvent::InstanceRead(b),
                            Err(_) => {
                                event = DuplexEvent::InstanceRead(0);
                            },
                        }
                    },
                }

                match event {
                    DuplexEvent::ClientRead(0) | DuplexEvent::InstanceRead(0) => {
                        return None;
                    }
                    DuplexEvent::ClientRead(bytes) => {
                        let _ = io_instance.write_all(&io_client_buf[0..bytes]).await;
                        let _ = io_instance.flush().await;
                    }
                    DuplexEvent::InstanceRead(bytes) => {
                        let _ = io_client.write_all(&io_instance_buf[0..bytes]).await;
                        let _ = io_client.flush().await;
                    }
                }
            },
            Err(err) => {
                error!(error = err.to_string(), "instance error");
                None
            }
        }
    }
}

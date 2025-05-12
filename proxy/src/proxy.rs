use miette::{bail, IntoDiagnostic};
use std::sync::Arc;
use tonic::transport::{Certificate, Identity, Server, ServerTlsConfig};
use tonic_prometheus_layer::MetricsLayer;
use tower_http::cors::CorsLayer;
use tower_http::trace::{DefaultOnEos, TraceLayer};
use tracing::{info, Level};
use utxorpc as u5c;

use crate::config::Config;
use crate::services::{QueryServiceImpl, SubmitServiceImpl, SyncServiceImpl, WatchServiceImpl};
use crate::State;

pub async fn serve(state: Arc<State>, config: &Config) -> miette::Result<()> {
    let addr = config.proxy_addr.parse().unwrap();

    let inner = SyncServiceImpl::try_new(state.clone(), config.clone())?;
    let sync_service = u5c::spec::sync::sync_service_server::SyncServiceServer::new(inner);

    let inner = QueryServiceImpl::try_new(state.clone(), config.clone())?;
    let query_service = u5c::spec::query::query_service_server::QueryServiceServer::new(inner);

    let inner = WatchServiceImpl::try_new(state.clone(), config.clone())?;
    let watch_service = u5c::spec::watch::watch_service_server::WatchServiceServer::new(inner);

    let inner = SubmitServiceImpl::try_new(state.clone(), config.clone())?;
    let submit_service = u5c::spec::submit::submit_service_server::SubmitServiceServer::new(inner);

    let reflection = tonic_reflection::server::Builder::configure()
        .register_encoded_file_descriptor_set(u5c::spec::cardano::FILE_DESCRIPTOR_SET)
        .register_encoded_file_descriptor_set(u5c::spec::sync::FILE_DESCRIPTOR_SET)
        .register_encoded_file_descriptor_set(u5c::spec::query::FILE_DESCRIPTOR_SET)
        .register_encoded_file_descriptor_set(u5c::spec::submit::FILE_DESCRIPTOR_SET)
        .register_encoded_file_descriptor_set(u5c::spec::watch::FILE_DESCRIPTOR_SET)
        .register_encoded_file_descriptor_set(protoc_wkt::google::protobuf::FILE_DESCRIPTOR_SET)
        .build_v1()
        .unwrap();

    let server = Server::builder()
        .accept_http1(true)
        .layer(TraceLayer::new_for_grpc().on_eos(DefaultOnEos::new().level(Level::INFO)))
        .layer(MetricsLayer::new())
        .layer(CorsLayer::permissive());

    let key = std::fs::read_to_string(&config.ssl_key_path).expect("Failed to read SSL key");
    let crt = std::fs::read_to_string(&config.ssl_crt_path).expect("Failed to read SSL crt");
    let pem = Certificate::from_pem(crt);
    let identity = Identity::from_pem(pem, key);
    let tls = ServerTlsConfig::new().identity(identity);

    let Ok(mut server) = server.tls_config(tls) else {
        bail!("Failed set up HTTPS on proxy.")
    };

    info!("Serving proxy on {}", config.proxy_addr);
    server
        .add_service(tonic_web::enable(sync_service))
        .add_service(tonic_web::enable(query_service))
        .add_service(tonic_web::enable(submit_service))
        .add_service(tonic_web::enable(watch_service))
        .add_service(reflection)
        .serve(addr)
        .await
        .into_diagnostic()
}

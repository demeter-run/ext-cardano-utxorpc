use std::time::Duration;

use async_trait::async_trait;
use bytes::Bytes;
use dotenv::dotenv;
use pingora::protocols::ALPN;
use pingora::server::{configuration::Opt, Server};
use pingora::{http, Result};
use pingora::{
    proxy::{ProxyHttp, Session},
    upstreams::peer::HttpPeer,
};
use tracing::Level;

pub struct GrpcProxy;

fn main() {
    dotenv().ok();

    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let opt = Opt::default();
    let mut server = Server::new(Some(opt)).unwrap();
    server.bootstrap();

    let mut grpc_proxy = pingora::proxy::http_proxy_service(&server.configuration, GrpcProxy);

    let mut tls_settings =
        pingora::listeners::TlsSettings::intermediate("cert/localhost.crt", "cert/localhost.key")
            .unwrap();

    tls_settings.enable_h2();

    grpc_proxy.add_tls_with_settings("0.0.0.0:8000", None, tls_settings);
    // grpc_proxy.add_tcp("0.0.0.0:8000");
    server.add_service(grpc_proxy);

    server.run_forever();
}

#[async_trait]
impl ProxyHttp for GrpcProxy {
    type CTX = ();
    fn new_ctx(&self) -> Self::CTX {}

    async fn upstream_peer(
        &self,
        _session: &mut Session,
        _ctx: &mut Self::CTX,
    ) -> Result<Box<HttpPeer>> {
        let mut peer = Box::new(HttpPeer::new("0.0.0.0:50051", false, String::default()));
        peer.options.alpn = ALPN::H2;

        peer.options.h2_ping_interval = Some(Duration::from_secs(1));

        Ok(peer)
    }
    
    
    async fn response_trailer_filter(
        &self,
        _session: &mut Session,
        upstream_trailers: &mut http::HMap,
        _ctx: &mut Self::CTX,
    ) -> Result<Option<Bytes>>
    where
        Self::CTX: Send + Sync,
    {
        dbg!("--->");
        dbg!(upstream_trailers);
        dbg!(_session.is_http2());

        Ok(Some(Bytes::default()))
    }
}

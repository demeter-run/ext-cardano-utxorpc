use async_trait::async_trait;
use bytes::Bytes;
use pingora::proxy::{ProxyHttp, Session};
use pingora::Result;
use pingora::{http::ResponseHeader, upstreams::peer::HttpPeer};
use std::sync::Arc;
use tokio::net::lookup_host;
use tracing::info;

use crate::config::Config;
use crate::{Consumer, State};

static DMTR_API_KEY: &str = "dmtr-api-key";

pub struct UtxoRpcProxy {
    state: Arc<State>,
    config: Arc<Config>,
}
impl UtxoRpcProxy {
    pub fn new(state: Arc<State>, config: Arc<Config>) -> Self {
        Self { state, config }
    }

    fn extract_key(&self, session: &Session) -> String {
        session
            .get_header(DMTR_API_KEY)
            .map(|v| v.to_str().unwrap())
            .unwrap_or_default()
            .to_string()
    }

    async fn respond_health(&self, session: &mut Session, ctx: &mut Context) {
        ctx.is_health_request = true;
        session.set_keepalive(None);

        let is_healthy = match lookup_host(&self.config.instance()).await {
            Ok(mut addresses) => addresses.next().is_some(),
            Err(_) => false,
        };
        let (code, message) = if is_healthy {
            (200, "OK")
        } else {
            (500, "UNHEALTHY")
        };

        let header = Box::new(ResponseHeader::build(code, None).unwrap());
        session.write_response_header(header, true).await.unwrap();
        session
            .write_response_body(Some(Bytes::from(message)), true)
            .await
            .unwrap();
    }
}

#[derive(Debug, Default)]
pub struct Context {
    instance: String,
    consumer: Consumer,
    is_health_request: bool,
}

#[async_trait]
impl ProxyHttp for UtxoRpcProxy {
    type CTX = Context;
    fn new_ctx(&self) -> Self::CTX {
        Context::default()
    }

    async fn request_filter(&self, session: &mut Session, ctx: &mut Self::CTX) -> Result<bool>
    where
        Self::CTX: Send + Sync,
    {
        let path = session.req_header().uri.path();
        if path == self.config.health_endpoint {
            self.respond_health(session, ctx).await;
            return Ok(true);
        }

        let key = self.extract_key(session);

        ctx.consumer = match self.state.get_consumer(&key).await {
            Some(consumer) => consumer,
            None => {
                return session.respond_error(401).await.map(|_| true);
            }
        };

        if ctx.consumer.network != self.config.network {
            return session.respond_error(404).await.map(|_| true);
        }

        ctx.instance = self.config.instance();

        Ok(false)
    }

    async fn upstream_peer(
        &self,
        _session: &mut Session,
        ctx: &mut Self::CTX,
    ) -> Result<Box<HttpPeer>> {
        let mut peer = Box::new(HttpPeer::new(&ctx.instance, false, String::default()));
        peer.options.alpn = pingora::upstreams::peer::ALPN::H2;
        Ok(peer)
    }

    async fn logging(
        &self,
        session: &mut Session,
        _e: Option<&pingora::Error>,
        ctx: &mut Self::CTX,
    ) {
        if !ctx.is_health_request {
            let response_code = session
                .response_written()
                .map_or(0, |resp| resp.status.as_u16());

            info!(
                "{} response code: {response_code}",
                self.request_summary(session, ctx)
            );

            self.state.metrics.inc_http_total_request(
                &ctx.consumer,
                &self.config.proxy_namespace,
                &ctx.instance,
                &response_code,
            );
        }
    }
}

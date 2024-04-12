use async_trait::async_trait;
use pingora::Result;
use pingora::{
    proxy::{ProxyHttp, Session},
    upstreams::peer::HttpPeer,
};
pub struct GrpcProxy;

#[async_trait]
impl ProxyHttp for GrpcProxy {
    type CTX = ();
    fn new_ctx(&self) -> Self::CTX {}

    async fn upstream_peer(
        &self,
        _session: &mut Session,
        _ctx: &mut Self::CTX,
    ) -> Result<Box<HttpPeer>> {
        let http_peer = HttpPeer::new("0.0.0.0:50051", false, String::default());
        Ok(Box::new(http_peer))
    }
}

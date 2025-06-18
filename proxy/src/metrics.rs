use prometheus::{opts, IntCounterVec, Registry};
use rocket::config::Shutdown;
use rocket::http::Status;
use rocket::response::content::RawText;
use rocket::response::status::Custom;
use rocket::{get, routes};
use std::net::SocketAddr;

use crate::config::Config;
use crate::Consumer;

#[derive(Debug, Clone)]
pub struct Metrics {
    http_total_request: IntCounterVec,
}
impl Metrics {
    pub fn new(registry: Registry) -> Self {
        let http_total_request = IntCounterVec::new(
            opts!("utxorpc_proxy_total_requests", "Total requests",),
            &[
                "consumer",
                "namespace",
                "instance",
                "status_code",
                "network",
                "tier",
            ],
        )
        .unwrap();

        registry
            .register(Box::new(http_total_request.clone()))
            .unwrap();

        Self { http_total_request }
    }

    pub fn inc_http_total_request(
        &self,
        consumer: &Consumer,
        namespace: &str,
        instance: &str,
        status: &u16,
    ) {
        self.http_total_request
            .with_label_values(&[
                &consumer.to_string(),
                namespace,
                instance,
                &status.to_string(),
                &consumer.network,
                &consumer.tier,
            ])
            .inc()
    }
}

#[get("/metrics")]
async fn metrics() -> Custom<RawText<String>> {
    let body = tonic_prometheus_layer::metrics::encode_to_string().unwrap();

    Custom(Status::Ok, RawText(body))
}

pub async fn run(config: &Config) {
    let addr: SocketAddr = config
        .prometheus_addr
        .parse()
        .expect("Failed to parse prometheus address");

    let config = rocket::config::Config {
        address: addr.ip(),
        port: addr.port(),
        shutdown: Shutdown {
            ctrlc: false,
            ..Default::default()
        },
        ..rocket::config::Config::release_default()
    };

    rocket::custom(config)
        .mount("/", routes![metrics])
        .launch()
        .await
        .unwrap();
}

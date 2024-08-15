use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub network: String,
    pub proxy_addr: String,
    pub proxy_namespace: String,
    pub prometheus_addr: String,
    pub ssl_crt_path: String,
    pub ssl_key_path: String,
    pub utxorpc_dns: String,
    pub utxorpc_port: u16,
    pub health_endpoint: String,
}
impl Config {
    pub fn new() -> Self {
        Self {
            network: env::var("NETWORK").expect("NETWORK must be set"),
            proxy_addr: env::var("PROXY_ADDR").expect("PROXY_ADDR must be set"),
            proxy_namespace: env::var("PROXY_NAMESPACE").expect("PROXY_NAMESPACE must be set"),
            prometheus_addr: env::var("PROMETHEUS_ADDR").expect("PROMETHEUS_ADDR must be set"),
            ssl_crt_path: env::var("SSL_CRT_PATH").expect("SSL_CRT_PATH must be set"),
            ssl_key_path: env::var("SSL_KEY_PATH").expect("SSL_KEY_PATH must be set"),
            utxorpc_dns: env::var("UTXORPC_DNS").expect("UTXORPC_DNS must be set"),
            utxorpc_port: env::var("UTXORPC_PORT")
                .unwrap_or("50051".to_string())
                .parse()
                .expect("Unable to parse port."),
            health_endpoint: "/dmtr_health".to_string(),
        }
    }

    pub fn instance(&self) -> String {
        format!(
            "utxorpc-{}-grpc.{}:{}",
            self.network, self.utxorpc_dns, self.utxorpc_port
        )
    }
}
impl Default for Config {
    fn default() -> Self {
        Self::new()
    }
}

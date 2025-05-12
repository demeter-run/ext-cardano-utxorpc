use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub network: String,
    pub proxy_addr: String,
    pub proxy_namespace: String,
    pub prometheus_addr: String,
    pub ssl_crt_path: String,
    pub ssl_key_path: String,
    pub upstream: String,
}
impl Config {
    pub fn new() -> Self {
        let network = env::var("NETWORK").expect("NETWORK must be set");
        let upstream = env::var("UPSTREAM").expect("UPSTREAM must be set");
        Self {
            upstream,
            network,
            proxy_addr: env::var("PROXY_ADDR").expect("PROXY_ADDR must be set"),
            proxy_namespace: env::var("PROXY_NAMESPACE").expect("PROXY_NAMESPACE must be set"),
            prometheus_addr: env::var("PROMETHEUS_ADDR").expect("PROMETHEUS_ADDR must be set"),
            ssl_crt_path: env::var("SSL_CRT_PATH").expect("SSL_CRT_PATH must be set"),
            ssl_key_path: env::var("SSL_KEY_PATH").expect("SSL_KEY_PATH must be set"),
        }
    }
}
impl Default for Config {
    fn default() -> Self {
        Self::new()
    }
}

use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub proxy_addr: String,
    pub ssl_crt_path: String,
    pub ssl_key_path: String,
    pub utxorpc_port: u16,
    pub utxorpc_dns: String,
}
impl Config {
    pub fn new() -> Self {
        Self {
            proxy_addr: env::var("PROXY_ADDR").expect("PROXY_ADDR must be set"),
            ssl_crt_path: env::var("SSL_CRT_PATH").expect("SSL_CRT_PATH must be set"),
            ssl_key_path: env::var("SSL_KEY_PATH").expect("SSL_KEY_PATH must be set"),
            utxorpc_port: env::var("UTXORPC_PORT")
                .expect("UTXORPC_PORT must be set")
                .parse()
                .expect("UTXORPC_PORT must a number"),
            utxorpc_dns: env::var("UTXORPC_DNS").expect("UTXORPC_DNS must be set"),
        }
    }
}
impl Default for Config {
    fn default() -> Self {
        Self::new()
    }
}

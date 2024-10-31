use lazy_static::lazy_static;
use std::{env, time::Duration};

lazy_static! {
    static ref CONTROLLER_CONFIG: Config = Config::from_env();
}

pub fn get_config() -> &'static Config {
    &CONTROLLER_CONFIG
}

#[derive(Debug, Clone)]
pub struct Config {
    pub dns_zone: String,
    pub extension_subdomain: String,
    pub api_key_salt: String,
    pub default_utxorpc_version: String,
    pub metrics_delay: Duration,
    pub metrics_step: String,
    pub prometheus_url: String,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            dns_zone: env::var("DNS_ZONE").unwrap_or("demeter.run".into()),
            extension_subdomain: env::var("EXTENSION_SUBDOMAIN").unwrap_or("utxorpc-m1".into()),
            api_key_salt: env::var("API_KEY_SALT").unwrap_or("utxorpc-salt".into()),
            default_utxorpc_version: env::var("DEFAULT_UTXORPC_VERSION").unwrap_or("v1".into()),
            metrics_delay: Duration::from_secs(
                env::var("METRICS_DELAY")
                    .expect("METRICS_DELAY must be set")
                    .parse::<u64>()
                    .expect("METRICS_DELAY must be a number"),
            ),
            metrics_step: env::var("METRICS_STEP").unwrap_or("30s".into()),
            prometheus_url: env::var("PROMETHEUS_URL").expect("PROMETHEUS_URL must be set"),
        }
    }
}

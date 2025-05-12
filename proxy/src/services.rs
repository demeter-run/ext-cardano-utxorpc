/// Shallow reimplementations of all U5C services.
use futures_util::Stream;
use miette::IntoDiagnostic;
use std::pin::Pin;
use std::str::FromStr;
use std::sync::Arc;
use tonic::transport::{Channel, ClientTlsConfig, Endpoint};
use tonic::{Request, Response, Status};
use tracing::info;
use utxorpc as u5c;

use crate::config::Config;
use crate::{Consumer, State};

static DMTR_API_KEY: &str = "dmtr-api-key";

pub async fn get_consumer<T>(
    request: &Request<T>,
    state: Arc<State>,
    config: &Config,
) -> Result<Consumer, Status> {
    let key = match request
        .metadata()
        .clone()
        .into_headers()
        .get(DMTR_API_KEY)
        .map(|v| v.to_str().unwrap())
    {
        Some(header) => header.to_string(),
        None => return Err(Status::unauthenticated("API key not found.")),
    };

    let consumer = match state.get_consumer(&key).await {
        Some(consumer) => consumer,
        None => return Err(Status::unauthenticated("Unauthorized.")),
    };

    if consumer.network != config.network {
        return Err(Status::unauthenticated(
            "This key corresponds to a different network",
        ));
    }
    Ok(consumer)
}

pub struct SyncServiceImpl {
    pub state: Arc<State>,
    pub config: Config,
    pub channel: Channel,
}
impl SyncServiceImpl {
    pub fn try_new(state: Arc<State>, config: Config) -> miette::Result<Self> {
        let endpoint = Endpoint::from_str(&config.upstream).into_diagnostic()?;
        let channel = endpoint
            .tls_config(ClientTlsConfig::new().with_enabled_roots())
            .unwrap()
            .connect_lazy();

        Ok(Self {
            state,
            channel,
            config,
        })
    }

    pub fn client(&self) -> u5c::spec::sync::sync_service_client::SyncServiceClient<Channel> {
        u5c::spec::sync::sync_service_client::SyncServiceClient::new(self.channel.clone())
    }
}

#[async_trait::async_trait]
impl u5c::spec::sync::sync_service_server::SyncService for SyncServiceImpl {
    type FollowTipStream = Pin<
        Box<dyn Stream<Item = Result<u5c::spec::sync::FollowTipResponse, Status>> + Send + 'static>,
    >;

    async fn fetch_block(
        &self,
        request: Request<u5c::spec::sync::FetchBlockRequest>,
    ) -> Result<Response<u5c::spec::sync::FetchBlockResponse>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SyncService/FetchBlock request");

        self.state.metrics.inc_http_total_request(
            &consumer,
            &self.config.proxy_namespace,
            &self.config.upstream,
            &200,
        );
        self.client().fetch_block(request).await
    }

    async fn dump_history(
        &self,
        request: Request<u5c::spec::sync::DumpHistoryRequest>,
    ) -> Result<Response<u5c::spec::sync::DumpHistoryResponse>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SyncService/DumpHistory request");
        self.client().dump_history(request).await
    }

    async fn follow_tip(
        &self,
        request: Request<u5c::spec::sync::FollowTipRequest>,
    ) -> Result<Response<Self::FollowTipStream>, tonic::Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SyncService/FollowTip request");
        let stream = self.client().follow_tip(request).await?;
        Ok(Response::new(Box::pin(stream.into_inner())))
    }

    async fn read_tip(
        &self,
        request: tonic::Request<u5c::spec::sync::ReadTipRequest>,
    ) -> std::result::Result<tonic::Response<u5c::spec::sync::ReadTipResponse>, tonic::Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SyncService/ReadTip request");
        self.client().read_tip(request).await
    }
}

pub struct QueryServiceImpl {
    pub state: Arc<State>,
    pub config: Config,
    pub channel: Channel,
}
impl QueryServiceImpl {
    pub fn try_new(state: Arc<State>, config: Config) -> miette::Result<Self> {
        let endpoint = Endpoint::from_str(&config.upstream).into_diagnostic()?;
        let channel = endpoint
            .tls_config(ClientTlsConfig::new().with_enabled_roots())
            .unwrap()
            .connect_lazy();

        Ok(Self {
            state,
            channel,
            config,
        })
    }

    pub fn client(&self) -> u5c::spec::query::query_service_client::QueryServiceClient<Channel> {
        u5c::spec::query::query_service_client::QueryServiceClient::new(self.channel.clone())
    }
}

#[async_trait::async_trait]
impl u5c::spec::query::query_service_server::QueryService for QueryServiceImpl {
    async fn read_params(
        &self,
        request: Request<u5c::spec::query::ReadParamsRequest>,
    ) -> Result<Response<u5c::spec::query::ReadParamsResponse>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving QueryService/ReadParams request");
        self.client().read_params(request).await
    }

    async fn read_data(
        &self,
        request: Request<u5c::spec::query::ReadDataRequest>,
    ) -> Result<Response<u5c::spec::query::ReadDataResponse>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving QueryService/ReadData request");
        self.client().read_data(request).await
    }

    async fn read_utxos(
        &self,
        request: Request<u5c::spec::query::ReadUtxosRequest>,
    ) -> Result<Response<u5c::spec::query::ReadUtxosResponse>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving QueryService/ReadUtxos request");
        self.client().read_utxos(request).await
    }

    async fn search_utxos(
        &self,
        request: Request<u5c::spec::query::SearchUtxosRequest>,
    ) -> Result<Response<u5c::spec::query::SearchUtxosResponse>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving QueryService/SearchUtxos request");
        self.client().search_utxos(request).await
    }
}

pub struct SubmitServiceImpl {
    pub state: Arc<State>,
    pub config: Config,
    pub channel: Channel,
}
impl SubmitServiceImpl {
    pub fn try_new(state: Arc<State>, config: Config) -> miette::Result<Self> {
        let endpoint = Endpoint::from_str(&config.upstream).into_diagnostic()?;
        let channel = endpoint
            .tls_config(ClientTlsConfig::new().with_enabled_roots())
            .unwrap()
            .connect_lazy();

        Ok(Self {
            state,
            channel,
            config,
        })
    }

    pub fn client(&self) -> u5c::spec::submit::submit_service_client::SubmitServiceClient<Channel> {
        u5c::spec::submit::submit_service_client::SubmitServiceClient::new(self.channel.clone())
    }
}

#[async_trait::async_trait]
impl u5c::spec::submit::submit_service_server::SubmitService for SubmitServiceImpl {
    type WaitForTxStream = Pin<
        Box<
            dyn Stream<Item = Result<u5c::spec::submit::WaitForTxResponse, tonic::Status>>
                + Send
                + 'static,
        >,
    >;

    type WatchMempoolStream = Pin<
        Box<
            dyn Stream<Item = Result<u5c::spec::submit::WatchMempoolResponse, tonic::Status>>
                + Send
                + 'static,
        >,
    >;

    async fn submit_tx(
        &self,
        request: Request<u5c::spec::submit::SubmitTxRequest>,
    ) -> Result<Response<u5c::spec::submit::SubmitTxResponse>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SubmitService/SubmitTx request");
        self.client().submit_tx(request).await
    }

    async fn wait_for_tx(
        &self,
        request: Request<u5c::spec::submit::WaitForTxRequest>,
    ) -> Result<Response<Self::WaitForTxStream>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SubmitService/WaitForTx request");
        let stream = self.client().wait_for_tx(request).await?;
        Ok(Response::new(Box::pin(stream.into_inner())))
    }

    async fn read_mempool(
        &self,
        request: tonic::Request<u5c::spec::submit::ReadMempoolRequest>,
    ) -> Result<tonic::Response<u5c::spec::submit::ReadMempoolResponse>, tonic::Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SubmitService/ReadMempool request");
        self.client().read_mempool(request).await
    }

    async fn watch_mempool(
        &self,
        request: tonic::Request<u5c::spec::submit::WatchMempoolRequest>,
    ) -> Result<tonic::Response<Self::WatchMempoolStream>, tonic::Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SubmitService/WatchMempool request");
        let stream = self.client().watch_mempool(request).await?;
        Ok(Response::new(Box::pin(stream.into_inner())))
    }

    async fn eval_tx(
        &self,
        request: tonic::Request<u5c::spec::submit::EvalTxRequest>,
    ) -> Result<tonic::Response<u5c::spec::submit::EvalTxResponse>, tonic::Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving SubmitService/EvalTx request");
        self.client().eval_tx(request).await
    }
}

pub struct WatchServiceImpl {
    pub state: Arc<State>,
    pub config: Config,
    pub channel: Channel,
}
impl WatchServiceImpl {
    pub fn try_new(state: Arc<State>, config: Config) -> miette::Result<Self> {
        let endpoint = Endpoint::from_str(&config.upstream).into_diagnostic()?;
        let channel = endpoint
            .tls_config(ClientTlsConfig::new().with_enabled_roots())
            .unwrap()
            .connect_lazy();

        Ok(Self {
            state,
            channel,
            config,
        })
    }

    pub fn client(&self) -> u5c::spec::watch::watch_service_client::WatchServiceClient<Channel> {
        u5c::spec::watch::watch_service_client::WatchServiceClient::new(self.channel.clone())
    }
}

#[async_trait::async_trait]
impl u5c::spec::watch::watch_service_server::WatchService for WatchServiceImpl {
    type WatchTxStream = Pin<
        Box<
            dyn Stream<Item = Result<u5c::spec::watch::WatchTxResponse, tonic::Status>>
                + Send
                + 'static,
        >,
    >;

    async fn watch_tx(
        &self,
        request: Request<u5c::spec::watch::WatchTxRequest>,
    ) -> Result<Response<Self::WatchTxStream>, Status> {
        let consumer = get_consumer(&request, self.state.clone(), &self.config).await?;
        info!(consumer =? consumer, "serving WatchService/WatchTx request");
        let stream = self.client().watch_tx(request).await?;
        Ok(Response::new(Box::pin(stream.into_inner())))
    }
}

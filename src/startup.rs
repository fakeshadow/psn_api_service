use std::future::Future;
use std::pin::Pin;
use std::time::Duration;

use ntex::http::header;
use ntex::server::openssl::SslAcceptorBuilder;
use ntex::web::dev::WebRequest;
use ntex_cors::CorsFactory;
use ntex_ratelimiter::{Filter, FilterResult, RateLimiter};
use openssl::ssl::{SslAcceptor, SslFiletype, SslMethod};
use psn_api_rs::{psn::PSN, traits::PSNRequest};

use crate::model::{SharedGlobalState, SharedMap};

pub fn global_builder(admin_token: String, api_key: String) -> (SharedGlobalState, SharedMap) {
    let state = SharedGlobalState::new(admin_token, api_key);
    let map = SharedMap::new();

    (state, map)
}

pub fn ssl_builder(key_path: String, cert_path: String) -> SslAcceptorBuilder {
    let mut builder = SslAcceptor::mozilla_intermediate(SslMethod::tls()).unwrap();

    builder
        .set_private_key_file(key_path, SslFiletype::PEM)
        .unwrap();
    builder.set_certificate_chain_file(cert_path).unwrap();

    builder
}

pub async fn psn_builder() -> PSN {
    let psn = PSN::new(vec![]).await;

    // we pause the pool when start up.
    psn.pause_inner();

    psn
}

pub fn cors_builder(cors_origin: &str) -> CorsFactory {
    let mut cors = ntex_cors::Cors::new();

    if cors_origin != "All" {
        cors = cors.allowed_origin(cors_origin);
    }

    cors.allowed_methods(vec!["GET", "POST"])
        .allowed_headers(vec![
            header::AUTHORIZATION,
            header::ACCEPT,
            header::CONTENT_TYPE,
        ])
        .max_age(3600)
        .finish()
}

pub fn rate_limiter_builder<E>(auth_token: &str) -> RateLimiter<E> {
    struct MyFilter(String);

    impl<E> Filter<E> for MyFilter {
        fn filter(&self, req: &WebRequest<E>) -> Pin<Box<dyn Future<Output = FilterResult>>> {
            let token = req
                .headers()
                .get("Authorization")
                .map(|value| value.to_str().unwrap_or("").to_owned());

            let res = match token {
                Some(token) => {
                    if token.contains(self.0.as_str()) {
                        FilterResult::Skip
                    } else {
                        FilterResult::Continue
                    }
                }
                None => FilterResult::Continue,
            };

            Box::pin(async move { res })
        }
    }

    RateLimiter::new()
        .max_requests(60)
        .interval(Duration::from_secs(3600))
        .recycle_interval(Duration::from_secs(60))
        .filter(MyFilter(auth_token.to_owned()))
}

pub fn schedule_refresher(psn: PSN) {
    ntex_rt::spawn(async move {
        // lifecycle: This loop will go on until the server is exit.
        loop {
            ntex_rt::time::delay_for(Duration::from_secs(900)).await;
            let pool = psn.get_inner();
            let inner = pool.get().await;

            if let Ok(mut inner) = inner {
                if let Ok(client) = PSN::new_client() {
                    let _ = inner.gen_access_from_refresh(&client).await;
                }
            }
        }
    });
}

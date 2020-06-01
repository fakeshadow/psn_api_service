#[macro_use]
extern crate serde_derive;

use std::env;

use ntex::web::{self, App, HttpServer, ServiceConfig};

use routes::*;
use startup::*;

mod captcha_solver;
mod error;
mod extractor;
mod handler;
mod model;
mod routes;
mod startup;

#[ntex::main]
async fn main() -> std::io::Result<()> {
    dotenv::dotenv().ok();

    let address = env::var("ADDRESS").expect("ADDRESS must be provided in .env");
    let port = env::var("PORT").expect("PORT must be provided in .env");
    let admin_token = env::var("BEARER_TOKEN").expect("BEARER_TOKEN must be provided in .env");
    let api_key = env::var("CAPTCHA_API_KEY").unwrap_or_else(|_| String::from(""));

    // if CORS_ORIGIN is not provided than no CORS behavior is allowed.
    let cors_origin = env::var("CORS_ORIGIN").ok();

    /*
        You would want to enable ssl if you expose the server to internet.
        As some of the APIs would send your authentication info for PSN.
        So be sure to provide KEY_PATH and CERT_PATH in your .env file if you want to enable it.
    */
    let key_path = env::var("KEY_PATH").ok();
    let cert_path = env::var("CERT_PATH").ok();

    let (state, map) = global_builder(admin_token.clone(), api_key);
    let psn = psn_builder().await;

    schedule_refresher(psn.clone());

    let simple = match cors_origin {
        Some(cors_origin) => SimpleEither::L(HttpServer::new(move || {
            let cors = cors_builder(&cors_origin);

            // Remove comment if you want to enable build in rate limiter.
            // let rate_limiter = rate_limiter_builder(&admin_token);

            App::new()
                .wrap(cors)
                // Remove comment if you want to enable build in rate limiter.
                // .wrap(rate_limiter)
                .app_data(state.clone())
                .app_data(map.clone())
                .app_data(psn.clone())
                .configure(conf_admin)
                .service(psn_request)
                .service(web::resource("/message").route(web::post().to(psn_message_request)))
        })),
        None => SimpleEither::R(HttpServer::new(move || {
            // Remove comment if you want to enable build in rate limiter.
            // let rate_limiter = rate_limiter_builder(&admin_token);

            App::new()
                // Remove comment if you want to enable build in rate limiter.
                // .wrap(rate_limiter)
                .app_data(state.clone())
                .app_data(map.clone())
                .app_data(psn.clone())
                .configure(conf_admin)
                .service(psn_request)
                .service(web::resource("/message").route(web::post().to(psn_message_request)))
        })),
    };

    match simple {
        SimpleEither::L(server) => match key_path {
            Some(key_path) => {
                let cert_path = cert_path.expect("Cert path is needed to enable ssl");
                let openssl = ssl_builder(key_path, cert_path);

                server
                    .bind_openssl(format!("{}:{}", address, port), openssl)?
                    .run()
                    .await
            }
            None => server.bind(format!("{}:{}", address, port))?.run().await,
        },
        SimpleEither::R(server) => match key_path {
            Some(key_path) => {
                let cert_path = cert_path.expect("Cert path is needed to enable ssl");
                let openssl = ssl_builder(key_path, cert_path);

                server
                    .bind_openssl(format!("{}:{}", address, port), openssl)?
                    .run()
                    .await
            }
            None => server.bind(format!("{}:{}", address, port))?.run().await,
        },
    }
}

enum SimpleEither<L, R> {
    L(L),
    R(R),
}

fn conf_admin(cfg: &mut ServiceConfig) {
    cfg.service(
        web::scope("/admin")
            .service(get_admin)
            .service(post_admin)
            .service(set_npsso),
    );
}

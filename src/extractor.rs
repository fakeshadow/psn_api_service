use std::future::Future;
use std::pin::Pin;

use ntex::http::{Payload, PayloadStream};
use ntex::web::{FromRequest, HttpRequest};

use crate::error::PSNServerError;
use crate::model::{AdminAuth, SharedGlobalState};

impl<F> FromRequest<F> for AdminAuth {
    type Error = PSNServerError;
    type Future = Pin<Box<dyn Future<Output=Result<Self, Self::Error>>>>;

    fn from_request(req: &HttpRequest, _payload: &mut Payload<PayloadStream>) -> Self::Future {
        let admin_token = req
            .app_data::<SharedGlobalState>()
            .expect("Global State must be initialized")
            .admin_token();

        let token = req
            .headers()
            .get("Authorization")
            .map(|v| v.to_str().map(|token| token == admin_token));

        Box::pin(async move {
            let is_authenticated = token
                .ok_or(PSNServerError::Authorization)?
                .map_err(|_| PSNServerError::Authorization)?;

            if is_authenticated {
                Ok(AdminAuth)
            } else {
                Err(PSNServerError::Authorization)
            }
        })
    }
}

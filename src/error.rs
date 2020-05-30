use derive_more::Display;
use failure::Error as FailureError;
use ntex::http::client::error::{JsonPayloadError, SendRequestError};
use ntex::web::{HttpRequest, HttpResponse, WebResponseError};
use psn_api_rs::psn::PSNError;
use reqwest::Error as ReqwestError;

#[derive(Debug, Display)]
pub enum PSNServerError {
    #[display(fmt = "Authentication Failed")]
    Authorization,
    #[display(fmt = "Internal Server Error: {}", _0)]
    General500(String),
    #[display(fmt = "PSN Error: {}", _0)]
    PSN(String),
    #[display(fmt = "Solver Error: {}", _0)]
    Solver(String),
    #[display(fmt = "Request Timeout")]
    TimeOut,
}

impl WebResponseError for PSNServerError {
    fn error_response(&self, _: &HttpRequest) -> HttpResponse {
        match self {
            PSNServerError::Authorization => {
                HttpResponse::Ok().json(&ErrorMessage::new(203, &format!("{}", self)))
            }

            PSNServerError::PSN(e) => HttpResponse::Ok().json(&ErrorMessage::new(500, e)),

            PSNServerError::General500(e) => HttpResponse::Ok().json(&ErrorMessage::new(500, e)),
            PSNServerError::TimeOut => {
                HttpResponse::Ok().json(&ErrorMessage::new(500, &format!("{}", self)))
            }

            PSNServerError::Solver(e) => HttpResponse::Ok().json(&ErrorMessage::new(500, e)),
        }
    }
}

#[derive(Serialize)]
struct ErrorMessage<'a> {
    status: u16,
    error: &'a str,
}

impl<'a> ErrorMessage<'a> {
    fn new(status: u16, error: &'a str) -> Self {
        ErrorMessage { status, error }
    }
}

impl From<SendRequestError> for PSNServerError {
    fn from(e: SendRequestError) -> Self {
        PSNServerError::General500(format!("{}", e))
    }
}

impl From<JsonPayloadError> for PSNServerError {
    fn from(e: JsonPayloadError) -> Self {
        PSNServerError::General500(format!("{}", e))
    }
}

impl From<PSNError> for PSNServerError {
    fn from(e: PSNError) -> Self {
        PSNServerError::PSN(format!("{}", e))
    }
}

impl From<FailureError> for PSNServerError {
    fn from(e: FailureError) -> Self {
        PSNServerError::Solver(format!("{}", e))
    }
}

impl From<ReqwestError> for PSNServerError {
    fn from(e: ReqwestError) -> Self {
        PSNServerError::Solver(format!("{}", e))
    }
}

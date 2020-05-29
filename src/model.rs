use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[derive(Clone, Debug)]
pub struct SharedGlobalState(Arc<GlobalState>);

impl SharedGlobalState {
    pub fn new(admin_token: String, api_key: String) -> Self {
        SharedGlobalState(Arc::new(GlobalState {
            admin_token: Mutex::new(format!("Bearer {}", admin_token)),
            api_key,
        }))
    }

    pub fn admin_token(&self) -> String {
        self.0.admin_token.lock().unwrap().clone()
    }

    pub fn api_key(&self) -> &str {
        &self.0.api_key
    }
}

#[derive(Debug)]
pub struct GlobalState {
    pub admin_token: Mutex<String>,
    pub api_key: String,
}

#[derive(Clone)]
pub struct SharedMap(Arc<Mutex<HashMap<String, Vec<Npsso>>>>);

impl SharedMap {
    pub fn new() -> Self {
        Self(Arc::new(Mutex::new(HashMap::new())))
    }

    pub fn add(&self, key: String, value: Vec<Npsso>) {
        self.0.lock().unwrap().insert(key, value);
    }

    pub fn contains(&self, key: &str) -> bool {
        self.0.lock().unwrap().contains_key(key)
    }

    // safe because we always check contains beforehand.
    pub fn is_ready(&self, key: &str) -> bool {
        self.0
            .lock()
            .unwrap()
            .get(key)
            .map(|v| !v.is_empty())
            .unwrap()
    }

    pub fn get(&self, key: &str) -> Option<Vec<Npsso>> {
        self.0.lock().unwrap().remove(key)
    }
}

pub(crate) struct AdminAuth;

#[derive(Deserialize)]
pub struct PSNInnerRequest {
    pub psn_inners: Vec<PSNInnerInfo>,
}

#[derive(Deserialize)]
pub struct PSNInnerInfo {
    pub email: String,
    pub online_id: Option<String>,
    pub npsso: String,
    // pub expires_at: String,
    pub region: Option<String>,
    pub language: Option<String>,
}

#[derive(Serialize)]
pub struct PSNInnerResponse {
    pub status: u16,
    pub psn_running: bool,
    pub failures: Option<Vec<PSNInnerFailure>>,
}

#[derive(Serialize)]
pub struct PSNInnerFailure {
    pub email: String,
    pub npsso: String,
    pub error: String,
}

#[derive(Deserialize, Serialize)]
pub(crate) struct SolverRequest {
    pub(crate) accounts: Vec<PSNAccount>,
}

#[derive(Deserialize, Serialize)]
pub(crate) struct PSNAccount {
    pub(crate) email: String,
    pub(crate) password: String,
}

#[derive(Serialize)]
pub struct SolverResponse<'a> {
    pub status: u16,
    pub solver_id: &'a str,
}

#[derive(Deserialize)]
#[serde(tag = "query_type")]
pub enum AdminQuery {
    SolverId { solver_id: String },
    StartService,
    PauseService,
}

#[derive(Deserialize, Serialize)]
pub struct SolverIdResponse {
    pub status: u16,
    pub npsso: Option<Vec<Npsso>>,
    pub error: Option<String>,
}

#[derive(Deserialize, Serialize)]
pub struct Npsso {
    pub email: String,
    pub npsso: Option<String>,
    pub expires_at: Option<String>,
    pub error: Option<String>,
}

#[derive(Deserialize, Debug)]
pub(crate) struct CaptchaResponse {
    pub(crate) status: u16,
    pub(crate) request: String,
}

#[derive(Deserialize)]
#[serde(tag = "query_type")]
pub enum PSNQuery {
    Profile {
        online_id: String,
    },
    Titles {
        online_id: String,
        offset: String,
    },
    TrophySet {
        online_id: String,
        np_communication_id: String,
    },
    Store {
        language: String,
        region: String,
        age: String,
        name: String,
    },
}

#[derive(Deserialize, Debug)]
pub struct PSNNpssoResponse {
    pub npsso: String,
    pub expires_in: i32,
}

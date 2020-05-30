use ntex::web::{
    self,
    HttpRequest,
    HttpResponse, types::{Json, Query},
};
use ntex_multipart::Multipart;
use psn_api_rs::{
    models::{PSNUser, StoreSearchResult, TrophySet, TrophyTitles},
    psn::PSN,
};

use crate::error::PSNServerError;
use crate::handler::*;
use crate::model::{
    AdminAuth, AdminQuery, PSNInnerRequest, PSNQuery, SharedGlobalState, SharedMap, SolverRequest,
};

#[web::get("")]
pub(crate) async fn get_admin(
    req: HttpRequest,
    _auth: AdminAuth,
    query: Query<AdminQuery>,
) -> Result<HttpResponse, PSNServerError> {
    match query.into_inner() {
        AdminQuery::SolverId { solver_id } => {
            let map = req.map();
            handle_solver_id(map, &solver_id)
        }
        AdminQuery::StartService => {
            req.psn().resume_inner();
            default_200_response()
        }
        AdminQuery::PauseService => {
            req.psn().pause_inner();
            default_200_response()
        }
    }
}

#[web::post("")]
pub(crate) async fn post_admin(
    _auth: AdminAuth,
    req: HttpRequest,
    solver_req: Json<SolverRequest>,
) -> Result<HttpResponse, PSNServerError> {
    let api_key = req.api_key();
    let map = req.map().clone();
    let solver_req = solver_req.into_inner();
    let users = solver_req.accounts;

    handle_post_admin(api_key, map, users).await
}

#[web::post("/npsso")]
pub(crate) async fn set_npsso(
    _auth: AdminAuth,
    req: HttpRequest,
    npsso: Json<PSNInnerRequest>,
) -> Result<HttpResponse, PSNServerError> {
    let npsso = npsso.into_inner().psn_inners;
    let psn = req.psn();

    handle_set_npsso(npsso, psn).await
}

#[web::get("/")]
pub(crate) async fn psn_request(
    req: HttpRequest,
    query: Query<PSNQuery>,
) -> Result<HttpResponse, PSNServerError> {
    let psn = req.psn();

    match query.into_inner() {
        PSNQuery::Profile { online_id } => {
            let res = psn.get_profile::<PSNUser>(&online_id).await?;
            psn_request_response(res)
        }
        PSNQuery::Titles { online_id, offset } => {
            let offset = offset.parse::<u32>().unwrap_or(0);
            let res = psn.get_titles::<TrophyTitles>(&online_id, offset).await?;
            psn_request_response(res)
        }
        PSNQuery::TrophySet {
            online_id,
            np_communication_id,
        } => {
            let res = psn
                .get_trophy_set::<TrophySet>(&online_id, &np_communication_id)
                .await?;
            psn_request_response(res)
        }
        PSNQuery::Store {
            language,
            region,
            name,
            age,
        } => {
            let res = psn
                .search_store_items::<StoreSearchResult>(&language, &region, &age, &name)
                .await?;

            psn_request_response(res)
        }
    }
}

pub(crate) async fn psn_message_request(
    req: HttpRequest,
    payload: Multipart,
) -> Result<HttpResponse, PSNServerError> {
    handle_message(req, payload);
    default_200_response()
}

pub trait FromAppData {
    fn psn(&self) -> &PSN;
    fn api_key(&self) -> &str;
    fn map(&self) -> &SharedMap;
}

impl FromAppData for HttpRequest {
    fn psn(&self) -> &PSN {
        self.app_data::<PSN>().unwrap()
    }

    fn api_key(&self) -> &str {
        self.app_data::<SharedGlobalState>().unwrap().api_key()
    }

    fn map(&self) -> &SharedMap {
        self.app_data::<SharedMap>().unwrap()
    }
}

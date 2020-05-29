use futures_util::StreamExt;
use ntex::web::{HttpRequest, HttpResponse};
use ntex_multipart::{Field, Multipart};
use psn_api_rs::psn::PSN;
use psn_api_rs::traits::PSNRequest;
use psn_api_rs::types::PSNInner;
use serde::Serialize;

use crate::captcha_solver::CaptchaSolver;
use crate::error::PSNServerError;
use crate::model::{
    Npsso, PSNAccount, PSNInnerFailure, PSNInnerInfo, PSNInnerResponse, SharedMap,
    SolverIdResponse, SolverResponse,
};
use crate::routes::FromAppData;

pub(crate) fn handle_solver_id(
    map: &SharedMap,
    solver_id: &str,
) -> Result<HttpResponse, PSNServerError> {
    let res = if map.contains(solver_id) {
        if map.is_ready(solver_id) {
            SolverIdResponse {
                status: 200,
                npsso: map.get(solver_id),
                error: None,
            }
        } else {
            SolverIdResponse {
                status: 201,
                npsso: None,
                error: Some("Not Ready".into()),
            }
        }
    } else {
        SolverIdResponse {
            status: 404,
            npsso: None,
            error: Some("Not Found".into()),
        }
    };

    Ok(HttpResponse::Ok().json(&res))
}

pub(crate) async fn handle_post_admin(
    api_key: &str,
    map: SharedMap,
    users: Vec<PSNAccount>,
) -> Result<HttpResponse, PSNServerError> {
    let solver_id = uuid::Uuid::new_v4().to_string();

    let solver = CaptchaSolver::new(api_key.into());

    let res = HttpResponse::Ok().json(&SolverResponse {
        status: 200,
        solver_id: &solver_id,
    });

    ntex_rt::spawn(async move {
        map.add(solver_id.clone(), Vec::new());

        let mut results = Vec::new();

        for user in users.into_iter() {
            let res = solver.get_npsso(&user).await;

            let result = match res {
                Ok(n) => Npsso {
                    email: user.email,
                    npsso: Some(n.npsso),
                    // ToDo: use datetime here.
                    expires_at: None,
                    error: None,
                },
                Err(e) => Npsso {
                    email: user.email,
                    npsso: None,
                    expires_at: None,
                    error: Some(e.to_string()),
                },
            };
            results.push(result);
        }

        map.add(solver_id, results);
    });

    Ok(res)
}

pub(crate) async fn handle_set_npsso(
    npsso: Vec<PSNInnerInfo>,
    psn: &PSN,
) -> Result<HttpResponse, PSNServerError> {
    let mut failure = Vec::new();
    let mut inner = Vec::new();

    let client = PSN::new_client()?;

    for n in npsso.into_iter() {
        let email = n.email;
        let npsso = n.npsso;
        let online_id = n.online_id.unwrap_or_else(|| String::from(""));
        let region = n.region.unwrap_or_else(|| String::from("hk"));
        let lang = n.language.unwrap_or_else(|| String::from("en"));

        let mut i = PSNInner::new();
        i.set_email(email.clone())
            .set_self_online_id(online_id)
            .set_region(region)
            .set_lang(lang)
            .add_npsso(npsso.clone());

        let res = i.gen_access_and_refresh(&client).await;

        match res {
            Ok(_) => inner.push(i),
            Err(e) => failure.push(PSNInnerFailure {
                email,
                npsso,
                error: format!("{}", e),
            }),
        }
    }

    let failure = if failure.is_empty() {
        Some(failure)
    } else {
        None
    };

    let len = inner.len();
    let psn_running = if len > 0 {
        psn.pause_inner();
        psn.set_psn_inner_max(len);
        psn.add_psn_inner(inner);
        psn.clear_inner();
        psn.resume_inner();
        true
    } else {
        false
    };

    Ok(HttpResponse::Ok().json(&PSNInnerResponse {
        status: 200,
        psn_running,
        failures: failure,
    }))
}

pub(crate) fn handle_message(req: HttpRequest, mut payload: Multipart) {
    ntex_rt::spawn(async move {
        let mut online_id = String::new();
        let mut msg: Option<String> = None;
        let mut buf: Option<Vec<u8>> = None;

        while let Some(res) = payload.next().await {
            match res {
                Ok(mut field) => {
                    let mime = field.content_type();
                    let typ = mime.type_();
                    let sub_typ = mime.subtype();
                    match (typ, sub_typ) {
                        (mime::TEXT, mime::PLAIN) => {
                            while let Some(chunk) = field.next().await {
                                match chunk {
                                    Ok(ref bytes) => {
                                        if let Ok(txt) = std::str::from_utf8(bytes) {
                                            match match_field(&field) {
                                                FieldType::OnlineId => online_id.push_str(txt),
                                                FieldType::Message => msg = Some(txt.into()),
                                                _ => break,
                                            }
                                        }
                                    }
                                    Err(_e) => (),
                                }
                            }
                        }
                        (mime::IMAGE, _) => match sub_typ {
                            mime::PNG => {
                                while let Some(chunk) = field.next().await {
                                    match chunk {
                                        Ok(bytes) => match match_field(&field) {
                                            FieldType::Picture => buf = Some(bytes.to_vec()),
                                            _ => break,
                                        },
                                        Err(_e) => (),
                                    }
                                }
                            }
                            mime::JPEG => (),
                            _ => break,
                        },
                        _ => break,
                    }
                }
                Err(_e) => (),
            }
        }

        if online_id.is_empty() {
            return;
        }

        if msg.is_none() && buf.is_none() {
            return;
        }

        let psn = req.psn();
        let _ = psn
            .send_message_with_buf(&online_id, msg.as_deref(), buf.as_deref())
            .await;
    });
}

enum FieldType {
    None,
    OnlineId,
    Message,
    Picture,
}

fn match_field(field: &Field) -> FieldType {
    let disposition = match field.headers().get("content-disposition") {
        Some(header) => header.to_str().unwrap_or(""),
        None => return FieldType::None,
    };

    if disposition.contains("online_id") {
        return FieldType::OnlineId;
    }

    if disposition.contains("message") {
        return FieldType::Message;
    }

    if disposition.contains("picture") {
        return FieldType::Picture;
    }

    FieldType::None
}

pub(crate) fn psn_request_response<T: Serialize>(
    psn_data: T,
) -> Result<HttpResponse, PSNServerError> {
    #[derive(Serialize)]
    struct PSNQueryResponse<T> {
        status: u16,
        psn_data: T,
    }

    Ok(HttpResponse::Ok().json(&PSNQueryResponse {
        status: 200,
        psn_data,
    }))
}

pub(crate) fn default_200_response() -> Result<HttpResponse, PSNServerError> {
    #[derive(Serialize)]
    struct Default200 {
        status: u16,
    }

    let res = HttpResponse::Ok().json(&Default200 { status: 200 });

    Ok(res)
}

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use headless_chrome::{Browser, LaunchOptions};
use headless_chrome::browser::tab::RequestInterceptionDecision;
use headless_chrome::protocol::network::methods::RequestPattern;
use reqwest::Client;

use crate::error::PSNServerError;
use crate::model::{CaptchaResponse, PSNAccount, PSNNpssoResponse};

const USER_AGENT: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36";
const URL: &str = "https://account.sonyentertainmentnetwork.com";
const AUTH_URL: &str = "https://auth.api.sonyentertainmentnetwork.com";
const SITE_KEY: &str = "6Le-UyUUAAAAAIqgW-LsIp5Rn95m_0V0kt_q0Dl5";
const TWO_CAP_REQ_URL: &str = "https://2captcha.com/in.php";
const TWO_CAP_RES_URL: &str = "https://2captcha.com/res.php";

pub(crate) struct CaptchaSolver {
    browser: Browser,
    api_key: String,
    client: Client,
}

impl CaptchaSolver {
    pub fn new(api_key: String) -> Self {
        Self {
            browser: Browser::new(
                LaunchOptions::default_builder()
                    .headless(false)
                    .window_size(Some((800, 600)))
                    .build()
                    .unwrap(),
            )
                .unwrap(),
            api_key,
            client: Client::new(),
        }
    }

    pub async fn get_npsso(&self, user: &PSNAccount) -> Result<PSNNpssoResponse, PSNServerError> {
        let tab = self.browser.wait_for_initial_tab()?;

        tab.set_user_agent(USER_AGENT, None, None)?;

        tab.navigate_to(URL)?.wait_for_element_with_custom_timeout(
            "#g-recaptcha-response",
            Duration::from_secs(15),
        )?;

        tab.wait_for_element_with_custom_timeout("#ember19", Duration::from_secs(5))?;

        tab.find_element("#ember19")?
            .focus()?
            .type_into(&user.email)?;

        tokio::time::delay_for(Duration::from_secs(1)).await;

        tab.find_element("#ember22")?
            .focus()?
            .type_into(&user.password)?;

        tokio::time::delay_for(Duration::from_secs(1)).await;

        tab.find_element("#ember24")?.click()?;

        let pattern = RequestPattern {
            url_pattern: Some("*"),
            resource_type: Some("XHR"),
            interception_stage: Some("Request"),
        };

        let response_token = Arc::new(Mutex::new(String::from("")));

        let response_token_clone = response_token.clone();
        // listen to request to AUTH_URL and replace the response_token
        let _ = tab.enable_request_interception(
            &[pattern],
            Box::new(move |_, _, mut param| {
                if param.request.url.starts_with(AUTH_URL) {
                    if let Some(post_data) = param.request.post_data.as_ref() {
                        if post_data.starts_with("grant_type=captcha") {
                            let sub = post_data.split("response_token=").collect::<Vec<&str>>();

                            // this unwrap is safe as we would return with error if response_token can't be obtained.
                            param.request.post_data = Some(format!(
                                "{}{}{}",
                                sub[0],
                                "response_token=",
                                response_token_clone.lock().unwrap()
                            ));
                        }
                    }
                }

                RequestInterceptionDecision::Continue
            }),
        );

        let npsso = Arc::new(Mutex::new(None));
        let npsso_clone = npsso.clone();
        // listen to and extract the response from AUTH_URL. It would contain the npsso code we need.
        let _ = tab.enable_response_handling(Box::new(move |params, func| {
            if params.response.url.starts_with(AUTH_URL) {
                if let Ok(res) = func() {
                    let np = serde_json::from_str::<PSNNpssoResponse>(&res.body);
                    if let Ok(npsso) = np {
                        npsso_clone
                            .lock()
                            .map(|mut inner| *inner = Some(npsso))
                            .unwrap()
                    }
                }
            }
        }));

        let url = tab.get_url();

        let request_id = self.send(url).await?;
        let captcha_answer = self.wait_receive(request_id).await?;

        response_token
            .lock()
            .map(|mut inner| {
                *inner = captcha_answer;
            })
            .unwrap();

        tab.evaluate("widgetVerified(this)", false)?;

        let mut retries = 0;
        let mut interval = tokio::time::interval(Duration::from_secs(2));

        loop {
            interval.tick().await;
            if retries == 10 {
                return Err(PSNServerError::TimeOut);
            } else {
                let mut n = npsso.lock().unwrap();
                match n.as_ref() {
                    Some(_) => {
                        return Ok(n.take().unwrap());
                    }
                    None => {
                        retries += 1;
                    }
                }
            }
        }
    }

    async fn send(&self, url: String) -> Result<String, PSNServerError> {
        let mut hashmap = HashMap::new();

        hashmap.insert("key", self.api_key.as_str());
        hashmap.insert("method", "userrecaptcha");
        hashmap.insert("googlekey", SITE_KEY);
        hashmap.insert("invisible", "1");
        hashmap.insert("json", "1");
        hashmap.insert("pageurl", &url);

        let res: CaptchaResponse = self
            .client
            .post(TWO_CAP_REQ_URL)
            .json(&hashmap)
            .send()
            .await?
            .json()
            .await?;

        if res.status == 1 {
            Ok(res.request)
        } else {
            Err(PSNServerError::Solver(
                "Failed to obtain request captchaId".into(),
            ))
        }
    }

    async fn try_receive(&self, request_url: &str) -> Option<String> {
        let res = self
            .client
            .get(request_url)
            .send()
            .await
            .ok()?
            .json::<CaptchaResponse>()
            .await
            .ok()?;

        if res.status == 1 {
            Some(res.request)
        } else {
            None
        }
    }

    async fn wait_receive(&self, request_id: String) -> Result<String, PSNServerError> {
        let url = format!(
            "{}?key={}&action=get&id={}&json=1",
            TWO_CAP_RES_URL, self.api_key, request_id
        );

        tokio::time::delay_for(Duration::from_secs(25)).await;

        let mut retries = 0;
        let mut interval = tokio::time::interval(Duration::from_secs(3));
        loop {
            if retries == 30 {
                return Err(PSNServerError::TimeOut);
            } else {
                match self.try_receive(&url).await {
                    Some(captcha) => return Ok(captcha),
                    None => {
                        retries += 1;
                        interval.tick().await;
                    }
                }
            }
        }
    }
}

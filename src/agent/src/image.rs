// Copyright (c) 2021 Alibaba Cloud
// Copyright (c) 2021, 2023 IBM Corporation
// Copyright (c) 2022 Intel Corporation
//
// SPDX-License-Identifier: Apache-2.0
//

use safe_path::scoped_join;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::sync::Arc;
use std::path::PathBuf;

use anyhow::{anyhow, Context, Result};
use image_rs::image::ImageClient;
use tokio::sync::Mutex;

use crate::rpc::CONTAINER_BASE;
use crate::AGENT_CONFIG;

// A marker to merge container spec for images pulled inside guest.
const ANNO_K8S_IMAGE_NAME: &str = "io.kubernetes.cri.image-name";
const KATA_IMAGE_WORK_DIR: &str = "/run/kata-containers/image/";
const CONFIG_JSON: &str = "config.json";

#[rustfmt::skip]
lazy_static! {
    pub static ref IMAGE_SERVICE: Mutex<Option<ImageService>> = Mutex::new(None);
}

// Convenience function to obtain the scope logger.
fn sl() -> slog::Logger {
    slog_scope::logger().new(o!("subsystem" => "image"))
}

#[derive(Clone)]
pub struct ImageService {
    image_client: Arc<Mutex<ImageClient>>,
    images: Arc<Mutex<HashMap<String, String>>>,
}

impl ImageService {
    pub fn new() -> Self {
        Self {
            image_client: Arc::new(Mutex::new(ImageClient::new(PathBuf::from(
                KATA_IMAGE_WORK_DIR,
            )))),
            images: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Get the singleton instance of image service.
    pub async fn singleton() -> Result<ImageService> {
        IMAGE_SERVICE
            .lock()
            .await
            .clone()
            .ok_or_else(|| anyhow!("image service is uninitialized"))
    }

    async fn add_image(&self, image: String, cid: String) {
        self.images.lock().await.insert(image, cid);
    }

    /// Set proxy environment from AGENT_CONFIG
    fn set_proxy_env_vars() {
        if env::var("HTTPS_PROXY").is_err() {
            let https_proxy = &AGENT_CONFIG.https_proxy;
            if !https_proxy.is_empty() {
                env::set_var("HTTPS_PROXY", https_proxy);
            }
        }
        if env::var("NO_PROXY").is_err() {
            let no_proxy = &AGENT_CONFIG.no_proxy;
            if !no_proxy.is_empty() {
                env::set_var("NO_PROXY", no_proxy);
            }
        }
    }

    /// pull_image is used for call image-rs to pull image in the guest.
    /// # Parameters
    /// - `image`: Image name (exp: quay.io/prometheus/busybox:latest)
    /// - `cid`: Container id
    /// - `image_metadata`: Annotations about the image (exp: "containerd.io/snapshot/cri.layer-digest": "sha256:24fb2886d6f6c5d16481dd7608b47e78a8e92a13d6e64d87d57cb16d5f766d63")
    /// # Returns
    /// - The image rootfs bundle path. (exp. /run/kata-containers/cb0b47276ea66ee9f44cc53afa94d7980b57a52c3f306f68cb034e58d9fbd3c6/images/rootfs)
    pub async fn pull_image(
        &self,
        image: &str,
        cid: &str,
        image_metadata: &HashMap<String, String>,
    ) -> Result<String> {
        info!(sl(), "image metadata: {image_metadata:?}");
        Self::set_proxy_env_vars();

        let bundle_base_dir = scoped_join(CONTAINER_BASE, cid)?;
        fs::create_dir_all(&bundle_base_dir)?;
        let bundle_path = scoped_join(&bundle_base_dir, "images")?;
        fs::create_dir_all(&bundle_path)?;
        info!(sl(), "pull image {image:?}, bundle path {bundle_path:?}");

        let res = self
            .image_client
            .lock()
            .await
            .pull_image(image, &bundle_path, &None, &None)
            .await;
        match res {
            Ok(image) => {
                info!(
                    sl(),
                    "pull and unpack image {image:?}, cid: {cid:?} succeeded."
                );
            }
            Err(e) => {
                error!(
                    sl(),
                    "pull and unpack image {image:?}, cid: {cid:?} failed with {:?}.",
                    e.to_string()
                );
                return Err(e);
            }
        };
        self.add_image(String::from(image), String::from(cid)).await;
        let image_bundle_path = scoped_join(&bundle_path, "rootfs")?;
        Ok(image_bundle_path.as_path().display().to_string())
    }

    /// When being passed an image name through a container annotation, merge its
    /// corresponding bundle OCI specification into the passed container creation one.
    pub async fn merge_bundle_oci(&self, container_oci: &mut oci::Spec) -> Result<()> {
        if let Some(image_name) = container_oci.annotations.get(ANNO_K8S_IMAGE_NAME) {
            let images = self.images.lock().await;
            if let Some(container_id) = images.get(image_name) {
                let image_oci_config_path = Path::new(CONTAINER_BASE)
                    .join(container_id)
                    .join(CONFIG_JSON);
                debug!(
                    sl(),
                    "Image bundle config path: {:?}", image_oci_config_path
                );

                let image_oci =
                    oci::Spec::load(image_oci_config_path.to_str().ok_or_else(|| {
                        anyhow!(
                            "Invalid container image OCI config path {:?}",
                            image_oci_config_path
                        )
                    })?)
                    .context("load image bundle")?;

                if let (Some(container_root), Some(image_root)) =
                    (container_oci.root.as_mut(), image_oci.root.as_ref())
                {
                    let root_path = Path::new(CONTAINER_BASE)
                        .join(container_id)
                        .join(image_root.path.clone());
                    container_root.path = String::from(root_path.to_str().ok_or_else(|| {
                        anyhow!("Invalid container image root path {:?}", root_path)
                    })?);
                }

                if let (Some(container_process), Some(image_process)) =
                    (container_oci.process.as_mut(), image_oci.process.as_ref())
                {
                    self.merge_oci_process(container_process, image_process);
                }
            }
        }

        Ok(())
    }

    /// Partially merge an OCI process specification into another one.
    fn merge_oci_process(&self, target: &mut oci::Process, source: &oci::Process) {
        // Override the target args only when the target args is empty and source.args is not empty
        if target.args.is_empty() && !source.args.is_empty() {
            target.args.append(&mut source.args.clone());
        }

        // Override the target cwd only when the target cwd is blank and source.cwd is not blank
        if target.cwd == "/" && source.cwd != "/" {
            target.cwd = String::from(&source.cwd);
        }

        for source_env in &source.env {
            if let Some((variable_name, variable_value)) = source_env.split_once('=') {
                debug!(
                    sl(),
                    "source spec environment variable: {variable_name:?} : {variable_value:?}"
                );
                if !target.env.iter().any(|i| i.contains(variable_name)) {
                    target.env.push(source_env.to_string());
                }
            }
        }
    }
}
#[cfg(test)]
mod tests {
    use super::ImageService;
    use rstest::rstest;

    #[rstest]
    // TODO - how can we tell the user didn't specifically set it to `/` vs not setting at all? Is that scenario valid?
    #[case::image_cwd_should_override_blank_container_cwd("/", "/imageDir", "/imageDir")]
    #[case::container_cwd_should_override_image_cwd("/containerDir", "/imageDir", "/containerDir")]
    #[case::container_cwd_should_override_blank_image_cwd("/containerDir", "/", "/containerDir")]
    async fn test_merge_cwd(
        #[case] container_process_cwd: &str,
        #[case] image_process_cwd: &str,
        #[case] expected: &str,
    ) {
        let image_service = ImageService::new();
        let mut container_process = oci::Process {
            cwd: container_process_cwd.to_string(),
            ..Default::default()
        };
        let image_process = oci::Process {
            cwd: image_process_cwd.to_string(),
            ..Default::default()
        };
        image_service.merge_oci_process(&mut container_process, &image_process);
        assert_eq!(expected, container_process.cwd);
    }

    #[rstest]
    #[case::pods_environment_overrides_images(
        vec!["ISPRODUCTION=true".to_string()],
        vec!["ISPRODUCTION=false".to_string()],
        vec!["ISPRODUCTION=true".to_string()]
    )]
    #[case::multiple_environment_variables_can_be_overrided(
        vec!["ISPRODUCTION=true".to_string(), "ISDEVELOPMENT=false".to_string()],
        vec!["ISPRODUCTION=false".to_string(), "ISDEVELOPMENT=true".to_string()],
        vec!["ISPRODUCTION=true".to_string(), "ISDEVELOPMENT=false".to_string()]
    )]
    #[case::not_override_them_when_none_of_variables_match(
        vec!["ANOTHERENV=TEST".to_string()],
        vec!["ISPRODUCTION=false".to_string(), "ISDEVELOPMENT=true".to_string()],
        vec!["ANOTHERENV=TEST".to_string(), "ISPRODUCTION=false".to_string(), "ISDEVELOPMENT=true".to_string()]
    )]
    #[case::a_mix_of_both_overriding_and_not(
        vec!["ANOTHERENV=TEST".to_string(), "ISPRODUCTION=true".to_string()],
        vec!["ISPRODUCTION=false".to_string(), "ISDEVELOPMENT=true".to_string()],
        vec!["ANOTHERENV=TEST".to_string(), "ISPRODUCTION=true".to_string(), "ISDEVELOPMENT=true".to_string()]
    )]
    async fn test_merge_env(
        #[case] container_process_env: Vec<String>,
        #[case] image_process_env: Vec<String>,
        #[case] expected: Vec<String>,
    ) {
        let image_service = ImageService::new();
        let mut container_process = oci::Process {
            env: container_process_env,
            ..Default::default()
        };
        let image_process = oci::Process {
            env: image_process_env,
            ..Default::default()
        };
        image_service.merge_oci_process(&mut container_process, &image_process);
        assert_eq!(expected, container_process.env);
    }
}

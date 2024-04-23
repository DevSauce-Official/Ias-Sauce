// Copyright (c) 2022 Alibaba Cloud
//
// SPDX-License-Identifier: Apache-2.0
//

//! shim-interface is a common library for different components of Kata Containers
//! to make function call through services inside the runtime(runtime-rs runtime).
//!
//! Shim management:
//! Currently, inside the shim, there is a shim management server running as the shim
//! starts, working as a RESTful server. To make function call in runtime from another
//! binary, using the utilities provided in this library is one of the methods.
//!
//! You may construct clients by construct a MgmtClient and let is make specific
//! HTTP request to the server. The server inside shim will multiplex the request
//! to its corresponding handler and run certain methods.

use std::path::Path;

use anyhow::{anyhow, Result};

pub mod shim_mgmt;

use kata_types::config::{KATA_PATH, KATA_PATH_RUNTIME_GO};

pub const SHIM_MGMT_SOCK_NAME: &str = "shim-monitor.sock";

// return sandbox's storage path
pub fn sb_storage_path() -> String {
    String::from(KATA_PATH)
}

pub fn sb_storage_path_runtime_go() -> String {
    String::from(KATA_PATH_RUNTIME_GO)
}

// returns the address of the unix domain socket(UDS) for communication with shim
// management service using http
// normally returns "unix:///run/kata/{sid}/shim_monitor.sock"
pub fn mgmt_socket_addr(sid: &str) -> Result<String> {
    if sid.is_empty() {
        return Err(anyhow!(
            "Empty sandbox id for acquiring socket address for shim_mgmt"
        ));
    }

    let p = Path::new(&sb_storage_path())
        .join(sid)
        .join(SHIM_MGMT_SOCK_NAME);

    // Check if file exists
    if !p.metadata().is_err() {
        if let Some(p) = p.to_str() {
            return Ok(format!("unix://{}", p));
        }
    }

    // When running runtime-go, the sandboxes info is stored under a different path.
    // Fallback, if the default path check fails.
    let p_go = Path::new(&sb_storage_path_runtime_go())
        .join(sid)
        .join(SHIM_MGMT_SOCK_NAME);

    // Check if file exists on disk
    if !p_go.metadata().is_err() {
        if let Some(p_go) = p_go.to_str() {
            return Ok(format!("unix://{}", p_go));
        }
    }

    Err(anyhow!("Bad socket path"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mgmt_socket_addr() {
        let sid = "414123";
        let addr = mgmt_socket_addr(sid).unwrap();
        assert_eq!(addr, "unix:///run/kata/414123/shim-monitor.sock");

        let sid = "";
        assert!(mgmt_socket_addr(sid).is_err());
    }
}

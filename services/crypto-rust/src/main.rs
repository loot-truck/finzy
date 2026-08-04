//! Crypto service: CPU-bound hashing and (later) encryption.
//!
//! `POST /digest` returns the SHA-256 of the request body. SHA-256 is
//! implemented here so the scaffold has no dependencies; for encryption use a
//! reviewed crate (`ring`, `aes-gcm`, `chacha20poly1305`) rather than
//! hand-written primitives.

mod sha256;

use httpmini::{port_from_env, serve, Response, Router};

fn main() -> std::io::Result<()> {
    let port = port_from_env("PORT", 9093);

    let router = Router::new()
        .health("crypto")
        .route("POST", "/digest", |req| {
            if req.body.is_empty() {
                return Response::error(400, "empty body");
            }
            let digest = sha256::hex(&req.body);
            Response::json(
                200,
                format!(
                    r#"{{"algorithm":"sha-256","bytes":{},"digest":"{digest}"}}"#,
                    req.body.len()
                ),
            )
        });

    serve(&format!("0.0.0.0:{port}"), router)
}

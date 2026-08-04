//! A dependency-free HTTP/1.1 server just large enough for the Rust compute
//! services: a thread-per-connection loop, exact-match routing, and helpers for
//! JSON and binary responses.
//!
//! It exists so the scaffold builds with no crates.io access. Swap it for
//! `axum` + `tokio` once you add real dependencies — the handler signature is
//! deliberately close to what those expect.

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;
use std::thread;

/// Largest request body accepted, to bound memory per connection.
const MAX_BODY: usize = 32 * 1024 * 1024;

pub struct Request {
    pub method: String,
    pub path: String,
    pub headers: HashMap<String, String>,
    pub body: Vec<u8>,
}

pub struct Response {
    pub status: u16,
    pub content_type: String,
    pub body: Vec<u8>,
}

impl Response {
    pub fn json(status: u16, body: impl Into<String>) -> Self {
        Response {
            status,
            content_type: "application/json".into(),
            body: body.into().into_bytes(),
        }
    }

    pub fn bytes(status: u16, content_type: &str, body: Vec<u8>) -> Self {
        Response {
            status,
            content_type: content_type.into(),
            body,
        }
    }

    pub fn error(status: u16, message: &str) -> Self {
        Response::json(status, format!(r#"{{"error":"{}"}}"#, escape(message)))
    }
}

type Handler = Box<dyn Fn(&Request) -> Response + Send + Sync>;

#[derive(Default)]
pub struct Router {
    routes: HashMap<(String, String), Handler>,
}

impl Router {
    pub fn new() -> Self {
        Router::default()
    }

    /// Registers `handler` for an exact method + path pair.
    pub fn route<F>(mut self, method: &str, path: &str, handler: F) -> Self
    where
        F: Fn(&Request) -> Response + Send + Sync + 'static,
    {
        self.routes
            .insert((method.to_uppercase(), path.to_string()), Box::new(handler));
        self
    }

    /// Adds the `/healthz` probe used by Docker, Nginx and Prometheus.
    pub fn health(self, service: &'static str) -> Self {
        self.route("GET", "/healthz", move |_| {
            Response::json(200, format!(r#"{{"status":"ok","service":"{service}"}}"#))
        })
    }

    fn handle(&self, req: &Request) -> Response {
        match self.routes.get(&(req.method.clone(), req.path.clone())) {
            Some(h) => h(req),
            None => Response::error(404, "not found"),
        }
    }
}

/// Serves `router` on `addr` until the process is stopped.
pub fn serve(addr: &str, router: Router) -> std::io::Result<()> {
    let listener = TcpListener::bind(addr)?;
    let router = Arc::new(router);
    eprintln!("listening on {addr}");

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let router = Arc::clone(&router);
                thread::spawn(move || {
                    if let Err(e) = handle_conn(stream, &router) {
                        eprintln!("connection error: {e}");
                    }
                });
            }
            Err(e) => eprintln!("accept: {e}"),
        }
    }

    Ok(())
}

fn handle_conn(stream: TcpStream, router: &Router) -> std::io::Result<()> {
    let mut reader = BufReader::new(stream.try_clone()?);
    let mut writer = stream;

    let req = match read_request(&mut reader) {
        Ok(Some(req)) => req,
        Ok(None) => return Ok(()), // client closed before sending anything
        Err(resp) => return write_response(&mut writer, &resp),
    };

    let resp = router.handle(&req);
    write_response(&mut writer, &resp)
}

fn read_request(reader: &mut BufReader<TcpStream>) -> Result<Option<Request>, Response> {
    let mut line = String::new();
    match reader.read_line(&mut line) {
        Ok(0) => return Ok(None),
        Ok(_) => {}
        Err(_) => return Err(Response::error(400, "could not read request")),
    }

    let mut parts = line.split_whitespace();
    let method = parts.next().unwrap_or_default().to_uppercase();
    let target = parts.next().unwrap_or_default();
    // Query strings are not part of routing; keep only the path.
    let path = target.split('?').next().unwrap_or("/").to_string();

    let mut headers = HashMap::new();
    loop {
        let mut header = String::new();
        if reader.read_line(&mut header).is_err() {
            return Err(Response::error(400, "malformed headers"));
        }
        let header = header.trim_end();
        if header.is_empty() {
            break;
        }
        if let Some((k, v)) = header.split_once(':') {
            headers.insert(k.trim().to_lowercase(), v.trim().to_string());
        }
    }

    let len: usize = headers
        .get("content-length")
        .and_then(|v| v.parse().ok())
        .unwrap_or(0);
    if len > MAX_BODY {
        return Err(Response::error(413, "payload too large"));
    }

    let mut body = vec![0u8; len];
    if len > 0 && reader.read_exact(&mut body).is_err() {
        return Err(Response::error(400, "truncated body"));
    }

    Ok(Some(Request {
        method,
        path,
        headers,
        body,
    }))
}

fn write_response(writer: &mut TcpStream, resp: &Response) -> std::io::Result<()> {
    let head = format!(
        "HTTP/1.1 {} {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
        resp.status,
        reason(resp.status),
        resp.content_type,
        resp.body.len()
    );
    writer.write_all(head.as_bytes())?;
    writer.write_all(&resp.body)?;
    writer.flush()
}

fn reason(status: u16) -> &'static str {
    match status {
        200 => "OK",
        201 => "Created",
        202 => "Accepted",
        400 => "Bad Request",
        404 => "Not Found",
        413 => "Payload Too Large",
        500 => "Internal Server Error",
        _ => "Unknown",
    }
}

/// Escapes the characters that would break out of a JSON string literal.
fn escape(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
}

/// Reads a port from `var`, falling back to `default`.
pub fn port_from_env(var: &str, default: u16) -> u16 {
    std::env::var(var)
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(default)
}

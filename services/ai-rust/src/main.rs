//! AI service: model inference.
//!
//! `POST /classify` currently runs a deterministic keyword rule that sorts a
//! transaction description into a spending category. It exists to fix the
//! request/response contract; replace `classify` with a real model (ONNX
//! Runtime, `candle`, or a call out to a hosted model) without the gateway or
//! the Flutter client changing.

use httpmini::{port_from_env, serve, Response, Router};

/// Keyword rules, checked in order. First match wins.
const RULES: &[(&str, &[&str])] = &[
    (
        "groceries",
        &["market", "grocery", "supermarket", "aldi", "kroger"],
    ),
    (
        "transport",
        &["uber", "lyft", "metro", "fuel", "petrol", "gas station"],
    ),
    (
        "dining",
        &["cafe", "coffee", "restaurant", "pizza", "diner"],
    ),
    (
        "utilities",
        &["electric", "water", "internet", "broadband", "phone bill"],
    ),
    ("income", &["salary", "payroll", "refund", "deposit"]),
];

fn main() -> std::io::Result<()> {
    let port = port_from_env("PORT", 9092);

    let router = Router::new()
        .health("ai")
        .route("POST", "/classify", |req| {
            let text = match std::str::from_utf8(&req.body) {
                Ok(t) if !t.trim().is_empty() => t,
                _ => return Response::error(400, "body must be non-empty UTF-8 text"),
            };

            let (category, confidence) = classify(text);
            Response::json(
                200,
                format!(r#"{{"category":"{category}","confidence":{confidence:.2}}}"#),
            )
        });

    serve(&format!("0.0.0.0:{port}"), router)
}

/// Returns the best category for `text` and a confidence in [0, 1].
fn classify(text: &str) -> (&'static str, f32) {
    let lower = text.to_lowercase();
    for (category, keywords) in RULES {
        if keywords.iter().any(|k| lower.contains(k)) {
            return (category, 0.9);
        }
    }
    ("uncategorised", 0.3)
}

#[cfg(test)]
mod tests {
    use super::classify;

    #[test]
    fn matches_keywords_case_insensitively() {
        assert_eq!(classify("WHOLE FOODS MARKET").0, "groceries");
        assert_eq!(classify("Uber trip").0, "transport");
    }

    #[test]
    fn falls_back_when_nothing_matches() {
        let (category, confidence) = classify("zzz unknown vendor");
        assert_eq!(category, "uncategorised");
        assert!(confidence < 0.5);
    }
}

//! Media service: image and video processing.
//!
//! `POST /inspect` sniffs an uploaded image's format and dimensions from its
//! header bytes — no decoding, so it is cheap enough to run inline. Real
//! transcoding belongs behind `POST /transform`, backed by the `image` crate
//! (or ffmpeg for video) and a Kafka job queue once the work outlasts a
//! request.

use httpmini::{port_from_env, serve, Response, Router};

fn main() -> std::io::Result<()> {
    let port = port_from_env("PORT", 9091);

    let router = Router::new()
        .health("media")
        .route("POST", "/inspect", |req| match inspect(&req.body) {
            Some(info) => Response::json(
                200,
                format!(
                    r#"{{"format":"{}","width":{},"height":{},"bytes":{}}}"#,
                    info.format,
                    info.width,
                    info.height,
                    req.body.len()
                ),
            ),
            None => Response::error(400, "unrecognised or truncated image"),
        });

    serve(&format!("0.0.0.0:{port}"), router)
}

struct ImageInfo {
    format: &'static str,
    width: u32,
    height: u32,
}

/// Reads dimensions straight out of the file header for PNG, GIF and JPEG.
fn inspect(data: &[u8]) -> Option<ImageInfo> {
    if data.starts_with(b"\x89PNG\r\n\x1a\n") {
        // IHDR width/height sit at fixed offsets 16..24.
        return Some(ImageInfo {
            format: "png",
            width: be_u32(data.get(16..20)?),
            height: be_u32(data.get(20..24)?),
        });
    }

    if data.starts_with(b"GIF87a") || data.starts_with(b"GIF89a") {
        return Some(ImageInfo {
            format: "gif",
            width: le_u16(data.get(6..8)?) as u32,
            height: le_u16(data.get(8..10)?) as u32,
        });
    }

    if data.starts_with(b"\xff\xd8") {
        return inspect_jpeg(data);
    }

    None
}

/// Walks JPEG segments until a start-of-frame marker carries the dimensions.
fn inspect_jpeg(data: &[u8]) -> Option<ImageInfo> {
    let mut i = 2;
    // A frame header is 9 bytes, so i + 9 == len is still a complete header.
    while i + 9 <= data.len() {
        if data[i] != 0xff {
            i += 1;
            continue;
        }

        let marker = data[i + 1];
        // SOF0..SOF15, excluding the non-frame markers DHT/JPG/DAC.
        if (0xc0..=0xcf).contains(&marker) && !matches!(marker, 0xc4 | 0xc8 | 0xcc) {
            return Some(ImageInfo {
                format: "jpeg",
                height: be_u16(data.get(i + 5..i + 7)?) as u32,
                width: be_u16(data.get(i + 7..i + 9)?) as u32,
            });
        }

        let len = be_u16(data.get(i + 2..i + 4)?) as usize;
        if len < 2 {
            return None;
        }
        i += 2 + len;
    }
    None
}

fn be_u32(b: &[u8]) -> u32 {
    u32::from_be_bytes([b[0], b[1], b[2], b[3]])
}

fn be_u16(b: &[u8]) -> u16 {
    u16::from_be_bytes([b[0], b[1]])
}

fn le_u16(b: &[u8]) -> u16 {
    u16::from_le_bytes([b[0], b[1]])
}

#[cfg(test)]
mod tests {
    use super::inspect;

    #[test]
    fn reads_png_dimensions() {
        let mut png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR".to_vec();
        png.extend_from_slice(&300u32.to_be_bytes());
        png.extend_from_slice(&200u32.to_be_bytes());

        let info = inspect(&png).expect("png should be recognised");
        assert_eq!((info.format, info.width, info.height), ("png", 300, 200));
    }

    #[test]
    fn reads_gif_dimensions() {
        let mut gif = b"GIF89a".to_vec();
        gif.extend_from_slice(&64u16.to_le_bytes());
        gif.extend_from_slice(&48u16.to_le_bytes());

        let info = inspect(&gif).expect("gif should be recognised");
        assert_eq!((info.format, info.width, info.height), ("gif", 64, 48));
    }

    #[test]
    fn skips_jpeg_segments_before_the_frame_header() {
        // SOI, then an APP0 segment of 4 bytes, then SOF0 carrying 32x16.
        let jpeg = b"\xff\xd8\xff\xe0\x00\x04\x00\x00\
                     \xff\xc0\x00\x11\x08\x00\x10\x00\x20";
        let info = inspect(jpeg).expect("jpeg should be recognised");
        assert_eq!((info.format, info.width, info.height), ("jpeg", 32, 16));
    }

    #[test]
    fn rejects_unknown_and_truncated_input() {
        assert!(inspect(b"not an image").is_none());
        // PNG magic but no IHDR payload.
        assert!(inspect(b"\x89PNG\r\n\x1a\n").is_none());
    }
}

package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

// signer produces and validates HS256 JWTs. HMAC keeps every service able to
// verify a token with a shared secret; switch to RS256 once the services stop
// sharing a trust boundary.
type signer struct {
	secret []byte
}

type claims struct {
	Sub   string `json:"sub"`
	Email string `json:"email"`
	Exp   int64  `json:"exp"`
}

func newSigner(secret string) *signer {
	return &signer{secret: []byte(secret)}
}

func (s *signer) sign(c claims) (string, error) {
	header, err := encodeSegment(map[string]string{"alg": "HS256", "typ": "JWT"})
	if err != nil {
		return "", err
	}
	payload, err := encodeSegment(c)
	if err != nil {
		return "", err
	}

	body := header + "." + payload
	return body + "." + s.mac(body), nil
}

func (s *signer) verify(token string) (claims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return claims{}, errors.New("malformed token")
	}

	body := parts[0] + "." + parts[1]
	// Constant-time compare so signature checks do not leak timing information.
	if !hmac.Equal([]byte(s.mac(body)), []byte(parts[2])) {
		return claims{}, errors.New("bad signature")
	}

	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return claims{}, errors.New("malformed payload")
	}

	var c claims
	if err := json.Unmarshal(raw, &c); err != nil {
		return claims{}, errors.New("malformed payload")
	}
	if time.Now().Unix() >= c.Exp {
		return claims{}, errors.New("token expired")
	}

	return c, nil
}

func (s *signer) mac(body string) string {
	h := hmac.New(sha256.New, s.secret)
	h.Write([]byte(body))
	return base64.RawURLEncoding.EncodeToString(h.Sum(nil))
}

func encodeSegment(v any) (string, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

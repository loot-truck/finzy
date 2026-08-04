package main

import (
	"encoding/hex"
	"testing"
	"time"
)

// Vectors from RFC 7914 §11 / the PBKDF2-HMAC-SHA256 test set.
func TestPBKDF2SHA256(t *testing.T) {
	cases := []struct {
		password, salt string
		iter, keyLen   int
		want           string
	}{
		{"password", "salt", 1, 32,
			"120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"},
		{"password", "salt", 2, 32,
			"ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"},
		// keyLen past one hash block exercises the multi-block path.
		{"passwd", "salt", 1, 64,
			"55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc" +
				"49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783"},
	}

	for _, c := range cases {
		got := hex.EncodeToString(pbkdf2SHA256([]byte(c.password), []byte(c.salt), c.iter, c.keyLen))
		if got != c.want {
			t.Errorf("pbkdf2(%q, %q, %d, %d)\n got %s\nwant %s",
				c.password, c.salt, c.iter, c.keyLen, got, c.want)
		}
	}
}

func TestPasswordRoundTrip(t *testing.T) {
	encoded, err := hashPassword("correct horse battery staple")
	if err != nil {
		t.Fatalf("hashPassword: %v", err)
	}

	if !checkPassword("correct horse battery staple", encoded) {
		t.Error("correct password rejected")
	}
	if checkPassword("wrong password entirely", encoded) {
		t.Error("wrong password accepted")
	}
	if checkPassword("anything", "not-a-valid-hash") {
		t.Error("malformed hash accepted")
	}
}

func TestSaltsAreUnique(t *testing.T) {
	a, _ := hashPassword("same password")
	b, _ := hashPassword("same password")
	if a == b {
		t.Error("identical passwords produced identical hashes; salt is not random")
	}
}

func TestStoreRejectsDuplicateEmail(t *testing.T) {
	s := newUserStore()
	if _, err := s.create("User@Example.com", "supersecret"); err != nil {
		t.Fatalf("create: %v", err)
	}

	// Addresses are compared case-insensitively.
	if _, err := s.create("user@example.com", "supersecret"); err == nil {
		t.Error("duplicate email accepted")
	}

	if _, ok := s.verify("USER@example.com ", "supersecret"); !ok {
		t.Error("login failed for a differently-cased address")
	}
	if _, ok := s.verify("user@example.com", "wrongpassword"); ok {
		t.Error("login succeeded with the wrong password")
	}
}

func TestTokenRoundTrip(t *testing.T) {
	s := newSigner("test-secret")
	token, err := s.sign(claims{Sub: "u1", Email: "a@b.c", Exp: time.Now().Add(time.Hour).Unix()})
	if err != nil {
		t.Fatalf("sign: %v", err)
	}

	got, err := s.verify(token)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if got.Sub != "u1" || got.Email != "a@b.c" {
		t.Errorf("claims round-tripped as %+v", got)
	}
}

func TestTokenRejectsTamperingAndExpiry(t *testing.T) {
	s := newSigner("test-secret")

	valid, _ := s.sign(claims{Sub: "u1", Exp: time.Now().Add(time.Hour).Unix()})
	if _, err := s.verify(valid[:len(valid)-1]); err == nil {
		t.Error("token with a truncated signature accepted")
	}
	if _, err := newSigner("other-secret").verify(valid); err == nil {
		t.Error("token accepted under the wrong secret")
	}

	expired, _ := s.sign(claims{Sub: "u1", Exp: time.Now().Add(-time.Minute).Unix()})
	if _, err := s.verify(expired); err == nil {
		t.Error("expired token accepted")
	}

	if _, err := s.verify("not.a.jwt.at.all"); err == nil {
		t.Error("malformed token accepted")
	}
}

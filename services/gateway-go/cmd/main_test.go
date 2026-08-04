package main

import "testing"

func TestStripServicePrefix(t *testing.T) {
	cases := map[string]string{
		"/api/v1/auth/login":        "/login",
		"/api/v1/users/profiles/u1": "/profiles/u1",
		"/api/v1/media/inspect":     "/inspect",
		"/api/v1/auth":              "/",
		"/api/v1/auth/":             "/",
		"/api/v1/crypto/a/b/c":      "/a/b/c",
	}

	for in, want := range cases {
		if got := stripServicePrefix(in); got != want {
			t.Errorf("stripServicePrefix(%q) = %q, want %q", in, got, want)
		}
	}
}

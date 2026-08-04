// Command auth issues and verifies access tokens. It owns credentials only;
// profile data lives in the users service.
package main

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/finance-tracker/shared/go/httpx"
)

func main() {
	svc := &service{
		users:  newUserStore(),
		signer: newSigner(httpx.Env("JWT_SECRET", "dev-secret-change-me")),
		ttl:    24 * time.Hour,
	}

	mux := http.NewServeMux()
	httpx.Health(mux, "auth")
	mux.HandleFunc("POST /register", svc.register)
	mux.HandleFunc("POST /login", svc.login)
	mux.HandleFunc("GET /me", svc.me)

	httpx.Serve(":8081", mux)
}

type service struct {
	users  *userStore
	signer *signer
	ttl    time.Duration
}

type credentials struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (s *service) register(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid body")
		return
	}
	if c.Email == "" || len(c.Password) < 8 {
		httpx.Error(w, http.StatusBadRequest, "email required and password must be at least 8 characters")
		return
	}

	u, err := s.users.create(c.Email, c.Password)
	if err != nil {
		httpx.Error(w, http.StatusConflict, err.Error())
		return
	}

	httpx.JSON(w, http.StatusCreated, map[string]string{"id": u.ID, "email": u.Email})
}

func (s *service) login(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid body")
		return
	}

	u, ok := s.users.verify(c.Email, c.Password)
	if !ok {
		// Same response for unknown user and wrong password: do not leak
		// which addresses are registered.
		httpx.Error(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	token, err := s.signer.sign(claims{Sub: u.ID, Email: u.Email, Exp: time.Now().Add(s.ttl).Unix()})
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "could not issue token")
		return
	}

	httpx.JSON(w, http.StatusOK, map[string]any{
		"access_token": token,
		"token_type":   "Bearer",
		"expires_in":   int(s.ttl.Seconds()),
	})
}

func (s *service) me(w http.ResponseWriter, r *http.Request) {
	raw := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	cl, err := s.signer.verify(raw)
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "invalid token")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"id": cl.Sub, "email": cl.Email})
}

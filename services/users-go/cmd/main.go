// Command users owns profile data: the record a person sees and edits,
// keyed by the subject id the auth service puts in the token.
package main

import (
	"encoding/json"
	"net/http"
	"sync"

	"github.com/finance-tracker/shared/go/httpx"
)

type profile struct {
	ID       string `json:"id"`
	Email    string `json:"email"`
	Name     string `json:"name"`
	Currency string `json:"currency"`
}

func main() {
	s := &store{profiles: map[string]profile{}}

	mux := http.NewServeMux()
	httpx.Health(mux, "users")
	mux.HandleFunc("GET /profiles/{id}", s.get)
	mux.HandleFunc("PUT /profiles/{id}", s.put)

	httpx.Serve(":8082", mux)
}

// store is in-memory; swap for PostgreSQL when persistence is wired up.
type store struct {
	mu       sync.RWMutex
	profiles map[string]profile
}

func (s *store) get(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	p, ok := s.profiles[r.PathValue("id")]
	s.mu.RUnlock()

	if !ok {
		httpx.Error(w, http.StatusNotFound, "profile not found")
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

func (s *store) put(w http.ResponseWriter, r *http.Request) {
	var p profile
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid body")
		return
	}

	// The path is authoritative for identity; the body cannot reassign it.
	p.ID = r.PathValue("id")
	if p.Currency == "" {
		p.Currency = "USD"
	}

	s.mu.Lock()
	s.profiles[p.ID] = p
	s.mu.Unlock()

	httpx.JSON(w, http.StatusOK, p)
}

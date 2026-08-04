package main

import (
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/finance-tracker/shared/go/httpx"
)

// rateLimiter is a fixed-window counter keyed by client IP. It is deliberately
// in-memory: with more than one gateway replica, move the counters to Redis so
// the limit is shared across instances.
type rateLimiter struct {
	window time.Duration
	limit  int

	mu      sync.Mutex
	clients map[string]*window
}

type window struct {
	count int
	reset time.Time
}

func newRateLimiter(w time.Duration, limit int) *rateLimiter {
	rl := &rateLimiter{window: w, limit: limit, clients: map[string]*window{}}
	go rl.reap()
	return rl
}

func (rl *rateLimiter) allow(key string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	c, ok := rl.clients[key]
	if !ok || now.After(c.reset) {
		rl.clients[key] = &window{count: 1, reset: now.Add(rl.window)}
		return true
	}

	c.count++
	return c.count <= rl.limit
}

// reap drops expired windows so the map does not grow without bound.
func (rl *rateLimiter) reap() {
	for range time.Tick(rl.window) {
		now := time.Now()
		rl.mu.Lock()
		for k, c := range rl.clients {
			if now.After(c.reset) {
				delete(rl.clients, k)
			}
		}
		rl.mu.Unlock()
	}
}

func (rl *rateLimiter) middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !rl.allow(clientIP(r)) {
			httpx.Error(w, http.StatusTooManyRequests, "rate limit exceeded")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func clientIP(r *http.Request) string {
	// Nginx sets X-Real-IP; fall back to the socket address when running direct.
	if ip := r.Header.Get("X-Real-IP"); ip != "" {
		return ip
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

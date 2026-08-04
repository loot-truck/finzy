// Command gateway is the single entry point the Flutter app talks to.
// It terminates client requests, applies cross-cutting concerns (CORS,
// logging, rate limiting) and forwards each route to the owning service.
package main

import (
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"github.com/finance-tracker/shared/go/httpx"
)

// route maps a public path prefix onto the upstream service that owns it.
type route struct {
	prefix string
	target string
}

func main() {
	routes := []route{
		{"/api/v1/auth", httpx.Env("AUTH_URL", "http://auth:8081")},
		{"/api/v1/users", httpx.Env("USERS_URL", "http://users:8082")},
		{"/api/v1/notifications", httpx.Env("NOTIFICATIONS_URL", "http://notifications:8083")},
		{"/api/v1/media", httpx.Env("MEDIA_URL", "http://media:9091")},
		{"/api/v1/ai", httpx.Env("AI_URL", "http://ai:9092")},
		{"/api/v1/crypto", httpx.Env("CRYPTO_URL", "http://crypto:9093")},
	}

	mux := http.NewServeMux()
	httpx.Health(mux, "gateway")

	for _, r := range routes {
		proxy, err := newProxy(r.target)
		if err != nil {
			log.Fatalf("route %s: %v", r.prefix, err)
		}
		// Both the bare prefix and everything beneath it belong to the service.
		mux.Handle(r.prefix, proxy)
		mux.Handle(r.prefix+"/", proxy)
		log.Printf("route %s -> %s", r.prefix, r.target)
	}

	limiter := newRateLimiter(
		time.Minute,
		100, // requests per client per window
	)

	httpx.Serve(":8080", cors(limiter.middleware(mux)))
}

// newProxy builds a reverse proxy that strips the /api/v1 prefix, so each
// service only ever sees its own routes (/login rather than /api/v1/auth/login).
func newProxy(target string) (http.Handler, error) {
	u, err := url.Parse(target)
	if err != nil {
		return nil, err
	}

	proxy := httputil.NewSingleHostReverseProxy(u)
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("upstream %s: %v", target, err)
		httpx.Error(w, http.StatusBadGateway, "upstream unavailable")
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.URL.Path = stripServicePrefix(r.URL.Path)
		proxy.ServeHTTP(w, r)
	}), nil
}

// stripServicePrefix turns /api/v1/auth/login into /login.
func stripServicePrefix(path string) string {
	trimmed := strings.TrimPrefix(path, "/api/v1/")
	if i := strings.Index(trimmed, "/"); i >= 0 {
		return trimmed[i:]
	}
	return "/"
}

func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", httpx.Env("CORS_ORIGIN", "*"))
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization,Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

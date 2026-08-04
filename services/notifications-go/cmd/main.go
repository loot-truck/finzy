// Command notifications accepts send requests and queues them. Today the queue
// is a bounded channel drained by a worker; point publish() at Kafka when
// delivery needs to survive a restart.
package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/finance-tracker/shared/go/httpx"
)

type notification struct {
	UserID  string `json:"user_id"`
	Channel string `json:"channel"` // push | email | sms
	Title   string `json:"title"`
	Body    string `json:"body"`
}

func main() {
	queue := make(chan notification, 1024)
	go deliver(queue)

	mux := http.NewServeMux()
	httpx.Health(mux, "notifications")
	mux.HandleFunc("POST /send", func(w http.ResponseWriter, r *http.Request) {
		var n notification
		if err := json.NewDecoder(r.Body).Decode(&n); err != nil {
			httpx.Error(w, http.StatusBadRequest, "invalid body")
			return
		}
		if n.UserID == "" || n.Channel == "" {
			httpx.Error(w, http.StatusBadRequest, "user_id and channel are required")
			return
		}

		select {
		case queue <- n:
			httpx.JSON(w, http.StatusAccepted, map[string]string{"status": "queued"})
		default:
			// Shed load rather than block the request goroutine.
			httpx.Error(w, http.StatusServiceUnavailable, "queue full")
		}
	})

	httpx.Serve(":8083", mux)
}

func deliver(queue <-chan notification) {
	for n := range queue {
		log.Printf("deliver %s to %s: %s", n.Channel, n.UserID, n.Title)
	}
}

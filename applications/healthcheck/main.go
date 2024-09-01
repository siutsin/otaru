package main

import (
	"io"
	"log/slog"
	"net/http"
	"os"
	"time"
)

func main() {
	client := &http.Client{Timeout: 5 * time.Second}

	var resp *http.Response
	var err error

	targetURL := os.Getenv("TARGET_URL")
	for i := 0; i < 3; i++ {
		slog.Info("Sending GET request", "targetURL", targetURL, "attempt", i+1)
		resp, err = client.Get(targetURL)
		if err == nil && resp.StatusCode >= 200 && resp.StatusCode < 300 {
			break
		}
		slog.Error("Failed to send GET request", "attempt", i+1, "StatusCode", resp.StatusCode, "error", err)
		time.Sleep(2 * time.Second)
	}

	if err != nil {
		panic(err)
	}
	defer func(Body io.ReadCloser) {
		_ = Body.Close()
	}(resp.Body)

	var healthCheckIOURL string
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		healthCheckIOURL = os.Getenv("HEALTH_CHECK_IO_SUCCESS_URL")
	} else {
		healthCheckIOURL = os.Getenv("HEALTH_CHECK_IO_FAILURE_URL")
	}

	slog.Info("Sending GET request", "healthCheckIOURL", healthCheckIOURL)
	_, err = client.Get(healthCheckIOURL)
	if err != nil {
		slog.Error("Failed to send GET request", "healthCheckIOURL", healthCheckIOURL, "error", err)
		panic(err)
	}
}

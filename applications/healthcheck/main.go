package main

import (
	"fmt"
	"io"
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
		fmt.Printf("Sending GET request to %s, attempt %d\n", targetURL, i+1)
		resp, err = client.Get(targetURL)
		if err == nil && resp.StatusCode >= 200 && resp.StatusCode < 300 {
			break
		}
		fmt.Printf("Retry %d failed. Error: %s StatusCode: %d\n", i+1, err, resp.StatusCode)
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

	fmt.Printf("Sending GET request to %s\n", healthCheckIOURL)
	_, err = client.Get(healthCheckIOURL)
	if err != nil {
		fmt.Printf("Failed to send GET request: %s\n", err)
		panic(err)
	}
}

FROM golang:1.23 AS builder
WORKDIR /app
COPY go.mod .
RUN go mod download
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/main .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/main /app/main
CMD ["/app/main"]

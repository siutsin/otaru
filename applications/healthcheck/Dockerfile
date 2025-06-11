FROM golang:1.24@sha256:d1db785fb37feb87d9140d78ed4fb7c75ee787360366a9c5efe39c7a841a0277 AS builder
WORKDIR /app
COPY go.mod .
RUN go mod download
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/main .

FROM gcr.io/distroless/static-debian12:nonroot@sha256:188ddfb9e497f861177352057cb21913d840ecae6c843d39e00d44fa64daa51c
WORKDIR /
COPY --from=builder /app/main .
USER 65532:65532

CMD ["/main"]

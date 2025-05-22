FROM golang:1.24@sha256:baf611fd7d082c08acbf365005971f201017d34ca2e80e6f3415577f82c44af2 AS builder
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

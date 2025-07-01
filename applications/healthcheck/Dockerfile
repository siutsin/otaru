FROM golang:1.24@sha256:1bb140b73b0c33df854496d07cb8d05ac62b358923ab513c18ede977f880c8b6 AS builder
WORKDIR /app
COPY go.mod .
RUN go mod download
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/main .

FROM gcr.io/distroless/static-debian12:nonroot@sha256:627d6c5a23ad24e6bdff827f16c7b60e0289029b0c79e9f7ccd54ae3279fb45f
WORKDIR /
COPY --from=builder /app/main .
USER 65532:65532

CMD ["/main"]

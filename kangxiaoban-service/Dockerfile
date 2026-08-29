FROM golang:1.26-bookworm AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/kangxiaoban-server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app
COPY --from=build /out/kangxiaoban-server /app/kangxiaoban-server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/kangxiaoban-server"]

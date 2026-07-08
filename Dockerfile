FROM rust:1.96.1-bookworm AS builder
WORKDIR /app
COPY backend/Cargo.toml backend/Cargo.lock ./backend/
COPY backend/src ./backend/src
COPY backend/migrations ./backend/migrations
WORKDIR /app/backend
RUN cargo build --release --bin quotes-backend

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/backend/target/release/quotes-backend /usr/local/bin/quotes-backend
ENV DATABASE_PATH=/data/quotes.db \
    STORAGE_DIR=/data/uploads \
    BIND_ADDR=0.0.0.0:8080
EXPOSE 8080
CMD ["quotes-backend"]

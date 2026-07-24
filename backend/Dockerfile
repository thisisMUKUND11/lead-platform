# ── Build stage ───────────────────────────────────────────────
FROM dart:stable AS build

WORKDIR /app

# Resolve dependencies first (better layer caching).
COPY pubspec.* ./
RUN dart pub get

# Build the Dart Frog production server.
COPY . .
RUN dart pub global activate dart_frog_cli
RUN dart pub global run dart_frog_cli:dart_frog build
RUN dart pub get --offline -C build
RUN dart compile exe build/bin/server.dart -o build/bin/server

# ── Runtime stage (minimal) ───────────────────────────────────
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/build/bin/server /app/bin/server

# Dart Frog honors PORT; Fly.io sets it. Default 8080.
ENV PORT=8080
EXPOSE 8080

CMD ["/app/bin/server"]

# Structured Logging

**Last reviewed:** 2026-03-11

All services must emit structured JSON logs so dashboards, alerts, and log-based metrics can query them consistently.

---

## Required fields (every log entry)

```json
{
  "severity": "INFO",
  "message": "human readable description",
  "timestamp": "2026-03-11T12:00:00.000Z",
  "request_id": "uuid",
  "user_id": "uid or null",
  "service": "service-name",
  "version": "git-sha",
  "duration_ms": 42
}
```

Field naming is non-negotiable — dashboards and alerts query these field names.

**Severity:** Use only these values (GCP Cloud Logging maps them automatically):  
`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`

---

## Error entries

For errors, add:

```json
{
  "error_type": "ValueError",
  "error_message": "...",
  "stack_trace": "..."
}
```

---

## HTTP request entries

For HTTP requests, add:

```json
{
  "http_method": "POST",
  "http_path": "/api/v1/estimate",
  "http_status": 200,
  "latency_ms": 87
}
```

---

## How to apply this in your project

1. Use a structured logging library (e.g. `structlog` in Python, `pino` or `winston` with JSON in Node) and configure it to output JSON to stdout.
2. Define a common schema or middleware that adds `severity`, `message`, `timestamp`, `request_id`, `user_id`, `service`, `version` to every log line.
3. For uncaught exceptions, log with `severity: "ERROR"` and include `error_type`, `error_message`, and `stack_trace`.
4. In HTTP middleware, log each request with `http_method`, `http_path`, `http_status`, and `latency_ms` (and other required fields). Use the same field names so GCP log queries and alerts work across services.

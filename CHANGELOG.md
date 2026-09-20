# Changelog

All notable changes to SentinelStack are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.0.0] — 2026-09-20

### Added
- **Grafana Alloy** — replaces Promtail for log collection (main stack + agents)
- **Tempo** — distributed tracing backend (7-day retention, OTLP gRPC/HTTP receivers)
- **Caddy** — reverse proxy with auto TLS and basic auth for Prometheus/Alertmanager
- **File-based service discovery** — add nodes by editing `prometheus/targets/*.yml` (no restart)
- **Modular alert rules** — split into `prometheus/rules/{node,proxmox,docker,service,storage}.yml`
- **New alerts** — SSL cert expiry, OOM kill detection, host reboot, network saturation, probe failure, Watchdog (dead man's switch)
- **`scripts/backup.sh`** — config + Docker volume backup with 7-day retention
- **`scripts/render-configs.sh`** — renders config templates with secrets from `.env` (envsubst)
- **Network segmentation** — 3 Docker networks: frontend, backend, exporters (internal-only)
- **Healthchecks + resource limits** on all services

### Security
- Secrets no longer hardcoded in tracked files — all credentials in `.env` (gitignored), rendered via templates
- Prometheus and Alertmanager behind Caddy basic auth (not directly exposed)
- Exporters isolated in `internal: true` network

### Changed
- Upgraded: Grafana 11.2, Prometheus 2.54, Alertmanager 0.27, Loki 3.1, Uptime Kuma 1.23
- Proxmox agent: Docker → systemd native install (node_exporter + Alloy)
- Dokploy agent: Promtail → Grafana Alloy

### Removed
- Promtail (all configs, main stack and agents)
- Hardcoded IPs from all scripts and docs
- 13 stale documentation/report files

---

## [1.0.0] — Initial Release

Initial monitoring stack with Prometheus, Grafana, Loki, Promtail, Alertmanager, Uptime Kuma.

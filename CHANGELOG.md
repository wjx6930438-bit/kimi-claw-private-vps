# Changelog

## 0.1.0 - 2026-08-02

- Published the first privacy-sanitized public workflow.
- Made pure Tailscale SSH the only quick-start path.
- Added hard checks for sudo, PID 1/systemd, TUN and official-source HTTPS.
- Separated server-side automation from Policy, external-device, public-port and reboot acceptance.
- Added explicit warnings for existing OpenSSH and `tailscale set --ssh` session interruption.

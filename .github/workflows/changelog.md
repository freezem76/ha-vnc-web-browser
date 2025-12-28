# Unreleased

## [0.12.1] - 2025-12-28

### Changed
- run_vnc.sh
    - Fixed port → display mapping regression (display_number = port - 5900) and strengthened validation when parsing `.displays[]` from `/data/options.json`.
    - Ensure per-display Chromium state directories are created under `/data/chromium-data-<display_number>` and are owned by `vnc_user`.
    - Hardened command composition for Xvnc and Chromium while preserving existing kiosk/privacy flags.
    - Added validation for resolution (WIDTHxHEIGHT) and depth values before launching Xvnc.
    - Improved logging for startup steps and failures to aid debugging.

- Dockerfile
    - Ensure required runtime utilities (jq, Xvnc deps, Chromium) are installed and available at build time.
    - Create `vnc_user` and set correct ownership for copied scripts and xstartup files.
    - Preserve executable bits on startup scripts and set `CMD` to `/home/vnc_user/startup.sh`.
    - Set proper file permissions for runtime (`/data` usage) and ensure the image preserves runtime conventions used by scripts.

### Rationale
- Fixes startup and ownership issues that could cause Chromium instances to run with invalid state or fail to start.
- Improves robustness of JSON parsing and input validation to reduce runtime failures.

### Migration / Notes
- No changes to addon config schema required; existing `options.json` remains compatible.
- If you mount or reuse `/data` from an earlier container, ensure `/data/chromium-data-*` directories are owned by the UID/GID of `vnc_user` inside the container (recreate or `chown` if needed).

### Tests
- Validate JSON parsing with `jq` against the example `options.json`.
- Verify port→display mapping for ports 5901–5904.
- Start container with mounted `/data/options.json` and confirm each VNC display starts and Chromium uses `/data/chromium-data-<display_number>`.
- Confirm scripts retain executable permissions inside the image.
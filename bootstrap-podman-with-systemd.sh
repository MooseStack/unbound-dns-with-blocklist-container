#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="unbound"
CONTAINER_PORT=5335
IMAGE="registry.access.redhat.com/hi/unbound:1.26"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="${SCRIPT_DIR}/update-hagezi-blocklist.sh"

MODE=""
HOST_PORT=""
UNIT_DIR=""
PODMAN=(podman)
SYSTEMCTL=(systemctl)

usage() {
    echo "Usage: $0 {rootless|root|cleanup}"
    exit 1
}

configure_mode() {
    case "$1" in
        rootless)
            MODE="rootless"
            HOST_PORT=5335
            UNIT_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
            SYSTEMCTL=(systemctl --user)
            ;;

        root)
            MODE="root"
            HOST_PORT=53
            UNIT_DIR="/etc/systemd/system"
            SYSTEMCTL=(systemctl)
            ;;

        cleanup)
            MODE="cleanup"
            ;;

        *)
            usage
            ;;
    esac
}

check_dependencies() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "ERROR: systemctl is required" >&2
        exit 1
    fi

    if ! command -v podman >/dev/null 2>&1; then
        echo "ERROR: podman is required" >&2
        exit 1
    fi

    if [[ ! -x "$UPDATE_SCRIPT" ]]; then
        echo "ERROR: expected executable updater at $UPDATE_SCRIPT" >&2
        exit 1
    fi
}

check_rootless_session() {
    if [[ "$MODE" != rootless ]]; then
        return
    fi

    if ! systemctl --user show-environment >/dev/null 2>&1; then
        echo "ERROR: a user systemd session is required" >&2
        exit 1
    fi
}

create_container() {
    if "${PODMAN[@]}" container exists "$CONTAINER_NAME"; then
        echo "Container '$CONTAINER_NAME' already exists."

        CURRENT_PORT="$(
            "${PODMAN[@]}" port "$CONTAINER_NAME" "${CONTAINER_PORT}/udp" 2>/dev/null ||
            true
        )"

        if [[ "$CURRENT_PORT" != *":${HOST_PORT}"* ]]; then
            echo "Recreating container for host port ${HOST_PORT}..."
            "${PODMAN[@]}" rm --force "$CONTAINER_NAME"
        else
            echo "Container already uses host port ${HOST_PORT}."
            return
        fi
    fi

    echo "Creating '$CONTAINER_NAME' on ${HOST_PORT}:${CONTAINER_PORT}..."

    "${PODMAN[@]}" run --detach \
        --name "$CONTAINER_NAME" \
        --publish "${HOST_PORT}:${CONTAINER_PORT}/udp" \
        --publish "${HOST_PORT}:${CONTAINER_PORT}/tcp" \
        --volume "${SCRIPT_DIR}/unbound-custom.conf:/etc/unbound/conf.d/unbound-custom.conf:ro,Z" \
        --volume "${SCRIPT_DIR}/responsepolicyzone/hagezi-rpz.txt:/etc/unbound/responsepolicyzone/hagezi-rpz.txt:ro,Z" \
        --volume "${SCRIPT_DIR}/responsepolicyzone/allowlist-rpz.txt:/etc/unbound/responsepolicyzone/allowlist-rpz.txt:ro,Z" \
        --volume "${SCRIPT_DIR}/responsepolicyzone/homelab-rpz.txt:/etc/unbound/responsepolicyzone/homelab-rpz.txt:ro,Z" \
        "$IMAGE"
}

write_container_service() {
    cat > "${UNIT_DIR}/unbound-container.service" <<EOF
[Unit]
Description=Unbound DNS container
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${PODMAN[*]} start ${CONTAINER_NAME}
ExecStop=${PODMAN[*]} stop --time 10 ${CONTAINER_NAME}

[Install]
WantedBy=default.target
EOF
}

write_update_service() {
    cat > "${UNIT_DIR}/hagezi-blocklist-update.service" <<EOF
[Unit]
Description=Update the HaGeZi Unbound blocklist
Requires=unbound-container.service
After=unbound-container.service

[Service]
Type=oneshot
WorkingDirectory=${SCRIPT_DIR}
ExecStart=/usr/bin/env bash ${UPDATE_SCRIPT}
EOF
}

write_timer() {
    cat > "${UNIT_DIR}/hagezi-blocklist-update.timer" <<'EOF'
[Unit]
Description=Weekly HaGeZi Unbound blocklist update

[Timer]
OnCalendar=Fri *-*-* 02:00:00
Persistent=true
Unit=hagezi-blocklist-update.service

[Install]
WantedBy=timers.target
EOF
}

enable_services() {
    "${SYSTEMCTL[@]}" daemon-reload
    "${SYSTEMCTL[@]}" enable --now unbound-container.service
    "${SYSTEMCTL[@]}" enable --now hagezi-blocklist-update.timer
}

cleanup_rootless() {
    local unit_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"

    if systemctl --user show-environment >/dev/null 2>&1; then
        systemctl --user disable --now \
            hagezi-blocklist-update.timer \
            hagezi-blocklist-update.service \
            unbound-container.service \
            2>/dev/null || true

        rm -f \
            "${unit_dir}/hagezi-blocklist-update.timer" \
            "${unit_dir}/hagezi-blocklist-update.service" \
            "${unit_dir}/unbound-container.service"

        systemctl --user daemon-reload
    fi

    if podman container exists "$CONTAINER_NAME"; then
        podman rm --force "$CONTAINER_NAME"
    fi
}

cleanup_root() {
    local unit_dir="/etc/systemd/system"

    systemctl disable --now \
        hagezi-blocklist-update.timer \
        hagezi-blocklist-update.service \
        unbound-container.service \
        2>/dev/null || true

    rm -f \
        "${unit_dir}/hagezi-blocklist-update.timer" \
        "${unit_dir}/hagezi-blocklist-update.service" \
        "${unit_dir}/unbound-container.service"

    systemctl daemon-reload

    if podman container exists "$CONTAINER_NAME"; then
        podman rm --force "$CONTAINER_NAME"
    fi
}

cleanup() {
    echo "Cleaning up rootless resources..."
    cleanup_rootless

    echo "Cleaning up root resources..."
    cleanup_root

    echo
    echo "Cleanup complete."
    echo "No configuration or RPZ files were removed."
}

main() {
    [[ $# -eq 1 ]] || usage

    configure_mode "$1"
    check_dependencies

    if [[ "$MODE" == "cleanup" ]]; then
        cleanup
        exit 0
    fi

    check_rootless_session

    mkdir -p "$UNIT_DIR"

    create_container
    write_container_service
    write_update_service
    write_timer
    enable_services

    echo
    echo "Mode:       $MODE"
    echo "Host port:  $HOST_PORT"
    echo "Container:  $CONTAINER_PORT"
    echo
    echo "Unbound is running on ${HOST_PORT} -> ${CONTAINER_PORT}."
    echo "HaGeZi update timer enabled for Fridays at 02:00."
}

main "$@"


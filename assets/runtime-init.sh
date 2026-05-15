#!/usr/bin/env bash

set -e

ORACLE_BASE_DIR="${ORACLE_BASE_DIR:-/opt/oracle}"
ORACLE_PROFILE="${ORACLE_PROFILE:-/assets/profile}"
ORACLE_SHM_SIZE="${ORACLE_SHM_SIZE:-2g}"
ORACLE_HOME_DIR="$ORACLE_BASE_DIR/app/product/11.2.0/dbhome_1"

ensure_profile() {
	local target="$1"

	touch "$target"
	if ! grep -q 'ORACLE_HOME=' "$target"; then
		cat "$ORACLE_PROFILE" >> "$target"
	fi
}

prepare_oracle_home() {
	mkdir -p -m 755 \
		"$ORACLE_BASE_DIR/app" \
		"$ORACLE_BASE_DIR/oraInventory" \
		"$ORACLE_BASE_DIR/dpdump"

	ensure_profile "$ORACLE_BASE_DIR/.bash_profile"
	ensure_profile "$ORACLE_BASE_DIR/.bashrc"

	if getent passwd oracle >/dev/null && getent group oinstall >/dev/null && [ ! -d "$ORACLE_HOME_DIR" ]; then
		chown -R oracle:oinstall "$ORACLE_BASE_DIR"
	fi
}

configure_shm() {
	if [ "${SKIP_SHM_RECONFIGURE:-false}" = "true" ]; then
		return 0
	fi

	if ! mountpoint -q /dev/shm; then
		echo "Shared memory /dev/shm is not mounted." >&2
		exit 1
	fi

	if mount | grep -qE ' /dev/shm .*noexec| /dev/shm .*size=65536k'; then
		if ! mount -o "remount,rw,exec,nosuid,nodev,size=$ORACLE_SHM_SIZE" /dev/shm; then
			echo "Failed to remount /dev/shm. Run the container with privileged: true or configure tmpfs manually." >&2
			exit 1
		fi
	fi
}

prepare_oracle_home
configure_shm

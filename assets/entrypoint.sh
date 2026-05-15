#!/usr/bin/env bash

set -e
source /assets/colorecho

/assets/runtime-init.sh

if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
	ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
	echo "$TZ" > /etc/timezone
fi

if [ ! -d "/opt/oracle/app/product/11.2.0/dbhome_1" ]; then
	echo_yellow "Database is not installed. Installing..."
	/assets/install.sh
fi

su oracle -c "/assets/entrypoint_oracle.sh"

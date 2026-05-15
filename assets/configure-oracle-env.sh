#!/usr/bin/env bash

set -euo pipefail

DBCA_TEMPLATE="${DBCA_TEMPLATE:-/assets/dbca.rsp}"
DBCA_RESPONSE="${DBCA_RESPONSE:-/tmp/dbca.rsp}"
ORACLE_SID="${ORACLE_SID:-orcl}"
ORACLE_PWD="${ORACLE_PWD:-oracle}"
ORACLE_CHARACTERSET="${ORACLE_CHARACTERSET:-AL32UTF8}"
ORACLE_TOTALMEMORY="${ORACLE_TOTALMEMORY:-}"

fail() {
	echo "Invalid Oracle environment: $*" >&2
	exit 1
}

[[ -f "$DBCA_TEMPLATE" ]] || fail "DBCA template not found: $DBCA_TEMPLATE"
[[ "$ORACLE_SID" =~ ^[A-Za-z][A-Za-z0-9_#]{0,11}$ ]] || fail "ORACLE_SID must start with a letter and be 1-12 characters: letters, digits, _, #"
[[ -n "$ORACLE_PWD" ]] || fail "ORACLE_PWD must not be empty"
[[ "$ORACLE_PWD" != *\"* && "$ORACLE_PWD" != *$'\n'* && "$ORACLE_PWD" != *$'\r'* ]] || fail "ORACLE_PWD must not contain quotes or newlines"
[[ "$ORACLE_CHARACTERSET" =~ ^[A-Za-z0-9_]+$ ]] || fail "ORACLE_CHARACTERSET must contain only letters, digits, and _"

if [[ -n "$ORACLE_TOTALMEMORY" ]]; then
	[[ "$ORACLE_TOTALMEMORY" =~ ^[0-9]+$ ]] || fail "ORACLE_TOTALMEMORY must be an integer number of MB"
	(( ORACLE_TOTALMEMORY >= 256 )) || fail "ORACLE_TOTALMEMORY must be at least 256 MB"
fi

mkdir -p "$(dirname "$DBCA_RESPONSE")"

awk \
	-v sid="$ORACLE_SID" \
	-v pwd="$ORACLE_PWD" \
	-v charset="$ORACLE_CHARACTERSET" \
	-v total_memory="$ORACLE_TOTALMEMORY" '
		$0 == "[CREATEDATABASE]" {
			in_create_database = 1
			print
			next
		}

		in_create_database && $0 ~ /^\[/ {
			in_create_database = 0
		}

		in_create_database && $0 ~ /^GDBNAME[[:space:]]*=/ {
			print "GDBNAME = \"" sid "\""
			next
		}

		in_create_database && $0 ~ /^SID[[:space:]]*=/ {
			print "SID = \"" sid "\""
			next
		}

		in_create_database && $0 ~ /^SYSPASSWORD[[:space:]]*=/ {
			print "SYSPASSWORD = \"" pwd "\""
			next
		}

		in_create_database && $0 ~ /^SYSTEMPASSWORD[[:space:]]*=/ {
			print "SYSTEMPASSWORD = \"" pwd "\""
			next
		}

		in_create_database && $0 ~ /^CHARACTERSET[[:space:]]*=/ {
			print "CHARACTERSET=\"" charset "\""
			next
		}

		in_create_database && total_memory != "" && $0 ~ /^AUTOMATICMEMORYMANAGEMENT[[:space:]]*=/ {
			print "AUTOMATICMEMORYMANAGEMENT=\"TRUE\""
			next
		}

		in_create_database && total_memory != "" && $0 ~ /^#?TOTALMEMORY[[:space:]]*=/ {
			print "TOTALMEMORY = \"" total_memory "\""
			next
		}

		in_create_database && total_memory != "" && $0 ~ /^INITPARAMS[[:space:]]*=/ {
			print "INITPARAMS=\"\""
			next
		}

		{ print }
	' "$DBCA_TEMPLATE" > "$DBCA_RESPONSE"

echo "Rendered DBCA response file: $DBCA_RESPONSE"

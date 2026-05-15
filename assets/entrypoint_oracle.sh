#!/usr/bin/env bash

set -e
source /assets/colorecho
source ~/.bashrc

db_name="$(echo "$ORACLE_SID" | tr '[:upper:]' '[:lower:]')"
alert_log="$ORACLE_BASE/diag/rdbms/$db_name/$ORACLE_SID/trace/alert_$ORACLE_SID.log"
listener_log="$ORACLE_BASE/diag/tnslsnr/$HOSTNAME/listener/trace/listener.log"
pfile=$ORACLE_HOME/dbs/init$ORACLE_SID.ora
dbca_response="${DBCA_RESPONSE:-/tmp/dbca.rsp}"
password_no_expire="${PASSWORD_NO_EXPIRE:-true}"
login_attempts_unlimited="${LOGIN_ATTEMPTS_UNLIMITED:-true}"

# monitor $logfile
monitor() {
    tail -F -n 0 $1 | while read line; do echo -e "$2: $line"; done
}


trap_db() {
	trap "echo_red 'Caught SIGTERM signal, shutting down...'; stop" SIGTERM;
	trap "echo_red 'Caught SIGINT signal, shutting down...'; stop" SIGINT;
}

start_db() {
	echo_yellow "Starting listener..."
	monitor $listener_log listener &
	lsnrctl start | while read line; do echo -e "lsnrctl: $line"; done
	MON_LSNR_PID=$!
	echo_yellow "Starting database..."
	trap_db
	monitor $alert_log alertlog &
	MON_ALERT_PID=$!
	sqlplus / as sysdba <<-EOF |
		pro Starting database ...
		startup;
		alter system register;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
	configure_default_profile_limits
	wait $MON_ALERT_PID
}

create_db() {
	echo_yellow "Database does not exist. Creating database..."
	date "+%F %T"
	/assets/configure-oracle-env.sh
	monitor $alert_log alertlog &
	MON_ALERT_PID=$!
	monitor $listener_log listener &
	#lsnrctl start | while read line; do echo -e "lsnrctl: $line"; done
	#MON_LSNR_PID=$!
        echo "START DBCA"
	dbca -silent -createDatabase -responseFile "$dbca_response"
	echo_green "Database created."
	date "+%F %T"
	change_dpdump_dir
	configure_default_profile_limits
        touch $pfile
	trap_db
        kill $MON_ALERT_PID
	#wait $MON_ALERT_PID
}

stop() {
    trap '' SIGINT SIGTERM
	shu_immediate
	echo_yellow "Shutting down listener..."
	lsnrctl stop | while read line; do echo -e "lsnrctl: $line"; done
	kill $MON_ALERT_PID $MON_LSNR_PID
	exit 0
}

shu_immediate() {
	ps -ef | grep ora_pmon | grep -v grep > /dev/null && \
	echo_yellow "Shutting down the database..." && \
	sqlplus / as sysdba <<-EOF |
		set echo on
		shutdown immediate;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
}

change_dpdump_dir () {
	echo_green "Changind dpdump dir to /opt/oracle/dpdump"
	sqlplus / as sysdba <<-EOF |
		create or replace directory data_pump_dir as '/opt/oracle/dpdump';
		commit;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
}

is_enabled () {
	local name="$1"
	local value="$2"

	case "$value" in
		true|TRUE|1|yes|YES|on|ON)
			return 0
			;;
		false|FALSE|0|no|NO|off|OFF)
			return 1
			;;
		*)
			echo_red "Invalid $name value: $value"
			exit 1
			;;
	esac
}

configure_default_profile_limits () {
	local password_life_time_sql=""
	local failed_login_attempts_sql=""

	if is_enabled PASSWORD_NO_EXPIRE "$password_no_expire"; then
		password_life_time_sql="alter profile default limit password_life_time unlimited;"
	fi

	if is_enabled LOGIN_ATTEMPTS_UNLIMITED "$login_attempts_unlimited"; then
		failed_login_attempts_sql="alter profile default limit failed_login_attempts unlimited;"
	fi

	if [ -z "$password_life_time_sql$failed_login_attempts_sql" ]; then
		echo_yellow "Skipping default password profile limits configuration"
		return 0
	fi

	echo_green "Configuring default password profile limits"
	sqlplus / as sysdba <<-EOF |
		set echo on
		$password_life_time_sql
		$failed_login_attempts_sql
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
}

chmod 777 /opt/oracle/dpdump

echo "Checking shared memory..."
df -h | grep "Mounted on" && df -h | egrep --color "^.*/dev/shm" || echo "Shared memory is not mounted."
if [ ! -f $pfile ]; then
  create_db;
fi 
start_db

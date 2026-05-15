set -e

source /assets/colorecho
trap "echo_red '******* ERROR: Something went wrong.'; exit 1" SIGTERM
trap "echo_red '******* Caught SIGINT signal. Stopping...'; exit 2" SIGINT

YUM_RETRIES="${YUM_RETRIES:-3}"

#Install prerequisites directly without virtual package
configure_yum_repos () {

	if [ -f /etc/yum.repos.d/CentOS-Base.repo ]; then
		echo "Configuring CentOS 7 vault repositories"
		sed -i \
			-e 's|^mirrorlist=|#mirrorlist=|g' \
			-e 's|^#baseurl=http://mirror.centos.org/centos/$releasever|baseurl=https://vault.centos.org/7.9.2009|g' \
			/etc/yum.repos.d/CentOS-Base.repo
	fi

}

yum_install_with_retry () {

	local attempt=1
	while [ "$attempt" -le "$YUM_RETRIES" ]; do
		if yum -y install "$@"; then
			return 0
		fi

		echo_yellow "yum install failed on attempt $attempt/$YUM_RETRIES"
		yum clean metadata || true
		attempt=$((attempt + 1))
		sleep 5
	done

	return 1

}

deps () {

	echo "Installing dependencies"
	yum_install_with_retry binutils compat-libstdc++-33 compat-libstdc++-33.i686 ksh elfutils-libelf elfutils-libelf-devel glibc glibc-common glibc-devel gcc gcc-c++ libaio libaio.i686 libaio-devel libaio-devel.i686 libgcc libstdc++ libstdc++.i686 libstdc++-devel libstdc++-devel.i686 make sysstat unixODBC unixODBC-devel
	yum clean all
	rm -rf /var/lib/{cache,log} /var/log/lastlog

}

users () {

	echo "Configuring users"
	groupadd -g 200 oinstall
	groupadd -g 201 dba
	useradd -u 440 -g oinstall -G dba -d /opt/oracle oracle
	echo "oracle:install" | chpasswd
	echo "root:install" | chpasswd
	sed -i "s/pam_namespace.so/pam_namespace.so\nsession    required     pam_limits.so/g" /etc/pam.d/login
	mkdir -p -m 755 /opt/oracle/app
	mkdir -p -m 755 /opt/oracle/oraInventory
	mkdir -p -m 755 /opt/oracle/dpdump
	chown -R oracle:oinstall /opt/oracle
	cat /assets/profile >> ~oracle/.bash_profile
	cat /assets/profile >> ~oracle/.bashrc

}

sysctl_and_limits () {

	cp /assets/sysctl.conf /etc/sysctl.conf
	cat /assets/limits.conf >> /etc/security/limits.conf

}

configure_yum_repos
deps
users
sysctl_and_limits

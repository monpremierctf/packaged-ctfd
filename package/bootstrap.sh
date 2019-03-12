#!/bin/sh

## GLOBAL VARIABLES
__dir="$(cd "$(dirname "${0}")" && pwd)"
__user="${SUDO_USER:-$USER}"
__homeDir="$(eval echo ~"${__user}")"

__dockerVersion="18.09.0-3.el7"
__dockerComposeVersion="1.23.1"

realpath() {
	case ${1} in
		/*) echo "${1}" ;;
		~/*) echo "${__homeDir}/${1#*/}" ;;
		*) echo "${PWD}/${1#./}" ;;
	esac
}

install_docker() {
	local docker_version="${1}" && shift

	local linux_distrib="$(. /etc/os-release; echo "$ID")"

	yum remove --quiet \
		docker \
		docker-client \
		docker-client-latest \
		docker-common \
		docker-latest \
		docker-latest-logrotate \
		docker-logrotate \
		docker-selinux \
		docker-engine-selinux \
		docker-engine

	yum install --assumeyes --quiet \
		yum-utils \
		device-mapper-persistent-data \
		lvm2

	yum-config-manager --quiet \
		--add-repo \
		"https://download.docker.com/linux/${linux_distrib}/docker-ce.repo"

	yum install --assumeyes --quiet docker-ce-${docker_version}

	if [ ! -z "${HTTP_PROXY}" ]; then
		mkdir -p '/etc/systemd/system/docker.service.d/'
		cat > "/etc/systemd/system/docker.service.d/http-proxy.conf" <<-EOF
		[Service]
		Environment="HTTP_PROXY=${HTTP_PROXY}" "HTTPS_PROXY=${HTTPS_PROXY}" "NO_PROXY=${NO_PROXY}"
		EOF
		systemctl daemon-reload
	fi

	systemctl enable docker && systemctl start docker
}


install_docker_compose() {
	local dockerComposeVersion="${1}" && shift;

	curl -L "https://github.com/docker/compose/releases/download/${dockerComposeVersion}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/sbin/docker-compose

	chmod +x /usr/sbin/docker-compose
}


render_http_basic_auth() {
	local user="${1}" && shift;
	local password="${1}" && shift;

	docker image pull "httpd:2.4-alpine" &> /dev/null;
	docker run -it --rm "httpd:2.4-alpine" htpasswd -nbB -C 6 "${user}" "${password}" | head -n 1
}


render_traefik_conf() {
	local domain="${1}" && shift;
	local traefik_ui_user="${1}" && shift;
	local traefik_ui_password="${1}" && shift;

	local traefik_ui_htpasswd=$(render_http_basic_auth "${traefik_ui_user}" "${traefik_ui_password}")

	DOMAIN="${domain}" \
	HTPASSWD_TRAEFIK_UI="${traefik_ui_htpasswd%$'\r'}" \
	envsubst < "./traefik/traefik.toml"
}

gen_password() {
	local size="${1:-30}" && shift;

	tr -cd '0-9a-zA-Z' < '/dev/urandom' | fold -w"${size}" | head -n1
}

gen_certs() {
	local domain="${1}" && shift;
	local target_dir="$(realpath ${1})" && shift;

	local country="FR"
	local state="Occitanie"
	local locality="Toulouse"
	local organization="none"
	local organizationalunit="IT"
	local email="never_ever_sendmeanemail@nope.eu"

	if ! command -v "openssl" > /dev/null 2>&1; then
		yum install --assumeyes openssl
	fi

	openssl req \
		-x509 \
		-nodes \
		-newkey rsa:4096 \
		-keyout "${target_dir}/${domain}.key" \
		-out "${target_dir}/${domain}.cert" \
		-days 365 \
		-subj "/C=${country}/ST=${state}/L=${locality}/O=${organization}/OU=${organizationalunit}/CN=${domain}/emailAddress=${email}"
}

render_docker_compose_yml() {
	local domain="${1}" && shift;
	local mysql_user_password="${1:-$(gen_password 30)}" && shift;
	local mysql_root_password="${1:-$(gen_password 30)}" && shift;

	EXPOSED_HOSTNAME="${domain}" \
	MYSQL_ROOT_PASSWORD="${mysql_root_password}" \
	MYSQL_PASSWORD="${mysql_user_password}" \
	envsubst < "${__dir}/docker-compose.yml"
}


provision_app() {
	local target_root_directory="$(realpath ${1})" && shift;

	if [[ ! -d "${target_root_directory}" ]]; then
		mkdir -p "${target_root_directory}"
	fi

	cp --recursive "." "${target_root_directory}/"
	rm -vf "${target_root_directory}/bootstrap.sh"

	chmod -R g-rwx "${target_root_directory}/"
	chmod -R o-rwx "${target_root_directory}/"

}


main() {
	local user="${__user}"
	local interactive="yes"
	local domain=""
	local install_path="/opt/ctfd"

	if [[ "$(id -u)" != "0" ]]; then
		echo "Not root, must be root !"
		exit -1
	fi

	for option in "${@}"; do
		case ${option} in
			 --domain=*)
			domain="${option#*=}"
			shift
			;;

			*)
			break
			;;
		esac
	done

	if [[ ! "${domain}" ]]; then
		read -p "Please enter the domain name that will be used to reach all the Web-UI
		(or any IP address that can be used by client to reach the web server) : " domain
	fi

	if ! command -v "docker" > /dev/null 2>&1; then
		install_docker "${__dockerVersion}"
	fi

	if ! command -v "docker-compose" > /dev/null 2>&1; then
		install_docker_compose "${__dockerComposeVersion}"
	fi


	provision_app "${install_path}"

	render_traefik_conf "${domain}" "admin" "passroot" > "${install_path}/traefik/traefik.toml"

	if [[ ! -f "${install_path}/traefik/ssl/${domain}.key" ]] && [[ ! -f "${install_path}/traefik/ssl/${domain}.cert" ]]; then
		gen_certs "${domain}" "${install_path}/traefik/ssl"
	fi

	render_docker_compose_yml "${domain}" > "${install_path}/docker-compose.yml"

	docker-compose --file "${install_path}/docker-compose.yml" pull;
	docker-compose --file "${install_path}/docker-compose.yml" up -d;
}


if [[ "$0" == "$BASH_SOURCE" ]]; then
	main "$@"
fi
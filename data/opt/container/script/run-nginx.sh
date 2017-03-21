#!/bin/bash

units_dir=/opt/container/shared/etc/nginx/host/units

function createServerConf () {
     local common_config=/etc/nginx/host/servers/${1}.conf.common
     local headers_clear=""
     local server_config=/etc/nginx/host/servers/${1}.conf

     cp /opt/container/template/common.conf.template ${common_config}
     cp /opt/container/template/server.conf.template ${server_config}
     fileSubstitute ${server_config} NGINX_PROXY_READ_TIMEOUT ${NGINX_PROXY_READ_TIMEOUT}
     fileSubstitute ${common_config} NGINX_RESOLVER ${NGINX_RESOLVER}
     fileSubstitute ${common_config} nginx_hosts ${1}
     fileSubstitute ${server_config} nginx_hosts ${1}
     fileSubstitute ${server_config} nginx_units `echo ${1} | sed "s/,/ /g"`

     if [ -f /etc/ssl/dhparam.pem ]
     then
          sed -i "s/#ssl_dhparam/ssl_dhparam/g" ${common_config}
     fi

     # For NGINX_HEADERS_REMOVE, strip whitespace and split on commas.  Then massage the values a bit to fit the format
     # of more_clear_headers.

     for header in `echo ${NGINX_HEADERS_REMOVE} | xargs | tr "," "\n"`
     do
          headers_clear="${headers_clear} '"`echo ${header} | xargs`"'"
     done

     if [ ! -z "${headers_clear}" ]
     then
          sed -i "s/\${headers_clear}/${headers_clear}/g" ${common_config}
          sed -i "s/#more_clear_headers/more_clear_headers/g" ${common_config}
     fi

     # Include any extra configuration for the virtual host if available.

     if [ -f /etc/nginx/extra/${1}.extra.conf ]
     then
          cp /etc/nginx/extra/${1}.extra.conf ${server_config}.extra

          sed -i "s/#include/include/g" ${common_config}
     fi
}

function createWWWRedirectConf () {
     local www_redirect_config=/etc/nginx/host/servers/${1}.conf.www_redirect

     cp /opt/container/template/www_redirect.conf.template ${www_redirect_config}
     fileSubstitute ${www_redirect_config} nginx_hosts ${1}

     sed -i "s/#include/include/g" /etc/nginx/host/servers/${1}.conf
}

function fileSubstitute () {
     sed -i "s/\${"${2}"}/"${3}"/g" ${1}
}

function nginxConfSubstitute () {
     fileSubstitute /etc/nginx/nginx.conf ${1} ${2}
}

function onProcessStopped () {
     kill -TERM ${1}

     # Clean up if the process was terminated by Docker.

     rm -rf /opt/container/shared/*

     exit 0
}

mkdir -p /etc/nginx/host/servers
mkdir -p /var/www/letsencrypt-well-known

# Expose /etc/letsencrypt to other units so they can make use of certificates, if necessary.

mkdir -p /opt/container/shared/etc
rm -rf /opt/container/shared/etc/letsencrypt
cp -R /etc/letsencrypt /opt/container/shared/etc/letsencrypt

# Fix /etc/nginx/nginx.conf.

cp /opt/container/template/nginx.conf.template /etc/nginx/nginx.conf
nginxConfSubstitute NGINX_GZIP ${NGINX_GZIP}
nginxConfSubstitute NGINX_KEEPALIVE_TIMEOUT ${NGINX_KEEPALIVE_TIMEOUT}
nginxConfSubstitute NGINX_TYPES_HASH_MAX_SIZE ${NGINX_TYPES_HASH_MAX_SIZE}
nginxConfSubstitute NGINX_WORKER_PROCESSES ${NGINX_WORKER_PROCESSES}
nginxConfSubstitute NGINX_WORKER_CONNECTIONS ${NGINX_WORKER_CONNECTIONS}

# Insert a brief pause to give us time for all the units to launch.

echo "[info] waiting ${NGINX_UNIT_WAIT} second(s) for units to launch"

sleep ${NGINX_UNIT_WAIT}

echo "[info] found "`ls ${units_dir}/__launched__ | wc -w`" unit(s) to start"

# Ping each unit to let it proceed with starting its main process.

for unit in `ls ${units_dir}/__launched__ 2> /dev/null`
do
     echo "[info] starting unit ${unit}..."

     until echo "start" | nc ${unit} 1234
     do
          sleep 0.1
     done
done

echo "[info] started "`ls ${units_dir}/__launched__ | wc -w`" unit(s)"

rm -rf ${units_dir}/__launched__

# Create a server configuration for each host containing units.

for host in `ls ${units_dir} 2> /dev/null`
do
     createServerConf ${host}

     # Turn NGINX_WWW_REDIRECT_HOSTS into an array.  If the current host is found, create the appropriate configuration.

     IFS=',' read -r -a www_redirect_hosts <<< ${NGINX_WWW_REDIRECT_HOSTS}

     for www_redirect_host in "${www_redirect_hosts[@]}"
     do
          if [ "${www_redirect_host}" == "${host}" ]
          then
               createWWWRedirectConf ${host}
          fi
     done
done

# Add any extra global configuration.

if [ -f /etc/nginx/extra.conf ]
then
     sed -i "s/#include/include/g" /etc/nginx/nginx.conf
fi

# Start cron for automated certificate renewal.

crond

/usr/share/nginx/sbin/nginx -g "daemon off;" &

pid=$!

trap "onProcessStopped ${pid}" INT KILL TERM

wait ${pid}

# Clean up if the process was terminated unexpectedly.

rm -rf /opt/container/shared/*
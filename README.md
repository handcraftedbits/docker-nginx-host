# NGINX Host [![Docker Pulls](https://img.shields.io/docker/pulls/handcraftedbits/nginx-host.svg?maxAge=2592000)](https://hub.docker.com/r/handcraftedbits/nginx-host)

A [Docker](https://www.docker.com) container used to easily create a secure [NGINX](http://nginx.org) server that is
capable of hosting one or more Docker-based "units" of functionality, such as static content or web applications.

# Features

* Designed to make creating an HTTPS server simple -- simply pick the parts you need.
* Default SSL settings score an **A+** grade on [SSL Labs](https://www.ssllabs.com/ssltest/) when including custom
  [Diffie-Hellman parameters](https://scotthelme.co.uk/squeezing-a-little-more-out-of-your-qualys-score/).
* Designed to be used with [Let's Encrypt](https://letsencrypt.org) certificates.
  * Certificates are automatically renewed.
* Default header settings score a **B** grade on [securityheaders.io](https://securityheaders.io).
  * Score can be improved with the addition of
    [Content Security Policy](https://www.owasp.org/index.php/Content_Security_Policy) headers and
    [HTTP Public Key Pinning](https://developer.mozilla.org/en-US/docs/Web/Security/Public_Key_Pinning).

# Available Units

The following units are available -- simply pick and choose which ones you want to sit behind your NGINX server:

| Unit                                                                                              | Description                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [bamboo](https://github.com/handcraftedbits/docker-nginx-unit-bamboo)                             | The [Atlassian Bamboo](https://www.atlassian.com/software/bamboo) continuous integration server.                                                                                                                                        |
| [bitbucket-server](https://github.com/handcraftedbits/docker-nginx-unit-bitbucket-server)         | The [Atlassian Bitbucket Server](https://www.atlassian.com/software/bitbucket/server) collaborative Git server.
| [confluence](https://github.com/handcraftedbits/docker-nginx-unit-confluence)                     | The [Atlassian Confluence](https://www.atlassian.com/software/confluence) team collaboration server.                                                                                                                                    |
| [go-import-redirector](https://github.com/handcraftedbits/docker-nginx-unit-go-import-redirector) | A unit based off of [rsc/go-import-redirector](https://github.com/rsc/go-import-redirector), which simplifies the hosting of [Go](https://golang.org) [custom remote import paths](https://golang.org/cmd/go/#hdr-Remote_import_paths). |
| [hugo](https://github.com/handcraftedbits/docker-nginx-unit-hugo)                                 | the [Hugo](https://gohugo.io) static site generator, designed for sites whose source code is hosted on GitHub.  Includes the ability to regenerate the site whenever you push a commit.                                                 |
| [jira](https://github.com/handcraftedbits/docker-nginx-unit-jira)                                 | The [Atlassian JIRA](https://www.atlassian.com/software/jira) software development tool.                                                                                                                                                |
| [static](https://github.com/handcraftedbits/docker-nginx-unit-static)                             | A unit that hosts simple static content.                                                                                                                                                                                                |
| [webhook](https://github.com/handcraftedbits/docker-nginx-unit-webhook)                           | A unit based off of [adnanh/webhook](https://github.com/adnanh/webhook), which allows you to execute arbitrary commands whenever a particular URL is accessed.                                                                          |

# Usage

## Prerequisites

### SSL Certificates

You must obtain SSL certificates from Let's Encrypt by following the
[getting started guide](https://letsencrypt.org/getting-started/).  Don't worry about writing a renewal script -- this
Docker container handles that for you.

#### A Note on Certificate Directory Names and Units

Keep in mind that Let's Encrypt certificates are registered in terms of single hostnames and the directory structure
it creates will reflect that.  For example, if you create a certificate for `mysite.com`, Let's Encrypt will create a
directory named `/etc/letsencrypt/live/mysite.com`.  As long as the units you use are configured to be served from
that same host (via `NGINX_UNIT_HOSTS` environment variable), there will be no problem.

However, you can configure units to be served from multiple discrete hosts, via wildcard, etc.  Consider a unit that is
served from `*.mysite.com` and `othersite.com` by setting the environment variable
`NGINX_UNIT_HOSTS=*.mysite.com,othersite.com`.  NGINX Host will attempt to look for the certificate in the directory
`/etc/letsencrypt/live/*.mysite.com,othersite.com`.  Since no such directory exists (after all, you registered your
certificate against `mysite.com`), NGINX Host won't be able to find your certificate.  To fix this, you need to create
a symbolic link in your local `/etc/letsencrypt` directory from `*.mysite.com,othersite.com` to `mysite.com`.

### Custom Diffie-Hellman parameters

Though not required, it is strongly recommended that you create custom Diffie-Hellman parameters for added security.
If you're unsure how to do this, please follow
[this guide](https://scotthelme.co.uk/squeezing-a-little-more-out-of-your-qualys-score/).

## Configuration

It is highly recommended that you use Docker orchestration software such as
[Docker Compose](https://www.docker.com/products/docker-compose) as any NGINX Host setup you are likely to use will
involve several Docker containers.  This guide will assume that you are using Docker Compose.

To begin, let's create a `docker-compose.yml` file that contains the bare minimum set of services required:

```yaml
version: '2'

services:
  data:
    image: handcraftedbits/nginx-host-data

  host:
    image: handcraftedbits/nginx-host
    ports:
      - "443:443"
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt
      - /home/me/dhparam.pem:/etc/ssl/dhparam.pem
    volumes_from:
      - data
```

The `data` service creates an instance of the
[handcraftedbits/nginx-host-data](https://github.com/handcraftedbits/docker-nginx-host-data) container in order for
common data to be shared between NGINX Host and its units.  Note that every unit and NGINX Host must reference this
container (represented by the service `data` in this example) in its `volumes_from` section in order to mount the
exported volumes, as seen in the example.

The `host` service creates an instance of NGINX Host, listening on port `443`.  If you wish, you can also listen on
port `80` and NGINX Host will automatically redirect HTTP requests to HTTPS.

Next, we mount the following volumes:

* `/etc/letsencrypt`: the location of your Let's Encrypt certificates and renewal information.  Typically this will be
  located in the `/etc/letsencrypt` directory on your local system.
* `/etc/ssl/dhparam.pem`: the file containing your custom Diffie-Hellman parameters.  Note that this volume does not
  have to be mounted, but it is highly recommended to do so in the interest of increased security.

## Adding Units

The configuration we created in the previous section will start an NGINX server but is not particularly useful as it
hosts nothing.  To fix that, let's add some static content by adding the `static` unit (shown here as the `mysite`
service):

```yaml
version: '2'

services:
  data:
    image: handcraftedbits/nginx-host-data

  mysite:
    image: handcraftedbits/nginx-unit-static
    environment:
      - NGINX_UNIT_HOSTS=mysite.com
      - NGINX_URL_PREFIX=/
    volumes:
      - /home/me/mysite:/opt/container/content
    volumes_from:
      - data

  proxy:
    image: handcraftedbits/nginx-host
    ports:
      - "443:443"
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt
      - /home/me/dhparam.pem:/etc/ssl/dhparam.pem
    volumes_from:
      - data
```

The `NGINX_UNIT_HOSTS` environment variable specifies that we will be listening for requests to `mysite.com` and the
`NGINX_URL_PREFIX` environment variable specifies that all static content will be available under `/`.  Finally, we
mount the local directory `/home/me/mysite` as the root of our static content (for more information on configuring the
`static` unit, refer to the [documentation](https://github.com/handcraftedbits/docker-nginx-unit-static)).

There's more to NGINX Host than just static content though -- there are [several units](#available-units) you can mix
and match to create your ideal server.  Consult the appropriate unit documentation for more information.

## Additional NGINX Configuration

Additional configuration at the virtual host level (i.e., within a `server` block) can be added by mounting a file
containing additional NGINX directives via the location `/etc/nginx/extra/${hosts}.extra.conf`.  For example, if you
have a unit hosted on `*.mysite.com` and `othersite.com` with additional NGINX directives located in the file
`/home/me/myextra.conf`, you would add the volume
`/home/me/myextra.com:/etc/nginx/extra/*.mysite.com,othersite.com.extra.conf` to the `docker run` command used to run
the NGINX Host container.

## Running NGINX Host

Assuming you are using Docker Compose, simply run `docker-compose up` in the same directory as your
`docker-compose.yml` file.  Otherwise, you will need to start each container with `docker run` or a suitable
alternative, making sure to add the appropriate environment variables and volume references.

# Reference

## Environment Variables

### Units

The following environment variables are required by all units (please consult unit documentation for any additional
environment variables that may be required):

#### `NGINX_UNIT_HOSTS`

A comma-delimited list used to specify which virtual server or virtual servers will host the unit.  In terms of NGINX
configuration, this environment variable is used for the
[`server_name`](http://nginx.org/en/docs/http/server_names.html) directive and follows the same syntax, with the
exception that the values are comma-delimited.

**Required**

#### `NGINX_URL_PREFIX`

The URL prefix to use.  Combined with the `NGINX_UNIT_HOSTS` environment variable, this determines the full URL used to
access the unit.  For example, using `NGINX_UNIT_HOSTS=mysite.com` and `NGINX_URL_PREFIX=/site` would cause unit
content to be served via the URL `https://mysite.com/site`.

**Required**

### NGINX

The following environment variables are used to configure the NGINX server used by NGINX Host:

#### `NGINX_GZIP`

Used to set the value of the NGINX [`gzip`](http://nginx.org/en/docs/ngx_http_gzip_module.html#gzip) directive.

**Default value**: `on`

#### `NGINX_HEADERS_REMOVE`

A comma-delimited list used to specify which header or headers will be removed from all responses.  This is generally
used for security purposes by removing headers that identify the server.

**Default value**: `Server,X-Powered-By`

#### `NGINX_KEEPALIVE_TIMEOUT`

Used to set the value of the NGINX
[`keepalive_timeout`](http://nginx.org/en/docs/ngx_http_core_module.html#keepalive_timeout) directive.

**Default value**: `65`

#### `NGINX_PROXY_READ_TIMEOUT`

Used to set the value of the NGINX
[`proxy_read_timeout`](http://nginx.org/en/docs/ngx_http_proxy_module.html#proxy_read_timeout) directive.

**Default value**: `120s`

#### `NGINX_RESOLVER`

Used to set the value of the NGINX [`resolver`](http://nginx.org/en/docs/ngx_http_core_module.html#resolver) directive.

**Default value**: `8.8.8.8 8.8.4.4`

#### `NGINX_TYPES_HASH_MAX_SIZE`

Used to set the value of the NGINX
[`types_hash_max_size`](http://nginx.org/en/docs/ngx_http_core_module.html#types_hash_max_size) directive.

**Default value**: `2048`

#### `NGINX_UNIT_WAIT`

Used to set the time, in seconds, that NGINX Host will wait for units to launch.  The value only needs to be changed if
a particular unit takes an excessively long time to launch.

**Default value**: `2`

#### `NGINX_WORKER_CONNECTIONS`

Used to set the value of the NGINX
[`worker_connections`](http://nginx.org/en/docs/ngx_core_module.html#worker_connections) directive.

**Default value**: `768`

#### `NGINX_WORKER_PROCESSES`

Used to set the value of the NGINX
[`worker_processes`](http://nginx.org/en/docs/ngx_core_module.html#worker_processes) directive.

**Default value**: `auto`

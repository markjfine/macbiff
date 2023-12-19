/*
 * $Id: comms_ssl.c 101 2004-10-28 02:51:15Z bmoore $
 *
 * Copyright (c) 2004  Branden J. Moore.
 *
 * This file is part of MacBiff, and is free software; you can redistribute
 * it and/or modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * MacBiff is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with MacBiff; if not, write to the Free Software Foundation, Inc., 59
 * Temple Place, Suite 330, Boston, MA  02111-1307 USA.
 *
 */

/*
 * Communications Wrapper for SSL Connections
 */

#include <errno.h>
#include <netdb.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <openssl/rand.h>

#if 0
# define EBUG 1
#endif
#include "debug.h"
#include "comms_ssl.h"

extern int comms_conn;

static SSL *ssl = NULL;
static SSL_CTX *ctx = NULL;
static int sock = -1;
static struct sockaddr_in sa;


void seed_SSL( void )
{
	while( !RAND_status() ) {
		RAND_load_file("/dev/random", 1024 );
	}
}


int comms_ssl_setup( const char *server, int port )
{
	struct hostent *hp;
	static int first_run = 1;

	dprintf("%s: Talking to %s\n", __FUNCTION__, server);

	if ( !server || !server[0] ) {
		/*alert("No server defined\n");*/
		return EINVAL;
	}

	if ( !( hp = gethostbyname( server ) ) ) {
		herror("gethostbyname");
		return h_errno;
	}

	sa.sin_family = AF_INET;
	sa.sin_port = htons(port ? port : 993); /* IMAPS Port */
	memcpy(&sa.sin_addr, hp->h_addr_list[0], hp->h_length);

	if ( first_run ) {
		SSL_library_init();
		SSL_load_error_strings();
	}
	seed_SSL();
	ctx = SSL_CTX_new(SSLv23_client_method());
	if ( !ctx ) {
		error("SSL_CTX_new returned %lu\n", ERR_get_error() );
	}
	SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2);

	comms_conn = 0;

	return 0;
}


int comms_ssl_connect( void )
{
	int res;

	if ( comms_conn || sock >= 0 || ssl ) {
		alert("Connecting, but already comms_conn.\n");
		comms_ssl_close();
	}

	sock = socket( AF_INET, SOCK_STREAM, 0 );
	if ( sock < 0 ) {
		return errno;
	}

	if ( connect(sock, (struct sockaddr*)&sa, sizeof(sa) ) < 0 ) {
		return errno;
	}

	/* Set up the SSL connection */
	ssl = SSL_new(ctx);
	SSL_set_fd(ssl, sock);
	if ( (res = SSL_connect(ssl) ) <= 0 ) {
/*		alert("SSL_connect returned code: %d\n",
				SSL_get_error(ssl, res));*/
		return SSL_get_error(ssl,res);
	}

	/* Should verify the cert */

	comms_conn = 1;

	return 0;
}


size_t comms_ssl_read( void *buf, size_t count )
{
	int res = 0;
	int err = SSL_ERROR_NONE;

	dprintf("%s... up to %lu bytes\n", __FUNCTION__, count );
	if ( !comms_conn ) {
		error("System not comms_conn\n");
	}

	do {
		res = SSL_read(ssl, buf, (int)count);
		if ( res <= 0 ) {
			err = SSL_get_error(ssl, res);
			alert("res: %d, err: %d, errno: %d\n", res, err, errno );
		}
		dprintf("Read %d bytes...  {{%s}}\n", res, (char*)buf);
	} while ( res <= 0 && err == SSL_ERROR_WANT_READ && errno != EINTR );

	errno = err != 5 ? err : errno;
	return res > 0 ? res : -1;
}


size_t comms_ssl_write( void *buf, size_t count )
{
	int res = 0;;
	int err = SSL_ERROR_NONE;

	if ( !comms_conn ) {
		error("System not comms_conn\n");
	}

	do {
		res = SSL_write(ssl, buf, (int)count);
		if ( res <= 0 ) {
			err = SSL_get_error(ssl, res);
		}
	} while ( res <= 0 && err == SSL_ERROR_WANT_WRITE );

	errno = err;
	return res > 0 ? res : -1;
}


int comms_ssl_close( void )
{
	if ( !comms_conn ) {
		return 0;
	}

	SSL_shutdown(ssl);
	SSL_free(ssl);
	ssl = NULL;
	close(sock);
	sock = -1;
	comms_conn = 0;
	SSL_CTX_free(ctx);
	ctx = NULL;

	return 0;
}


void comms_ssl_destroy( void )
{
	if ( comms_conn ) {
		comms_ssl_close();
	}
	dprintf("%s:\n", __FUNCTION__);
}

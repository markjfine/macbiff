/*
 * $Id: comms_remote.c 103 2004-11-06 16:33:16Z bmoore $
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
 * Communications Wrapper for Remote Connections
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

#if 0
#define EBUG 1
#endif
#include "debug.h"
#include "comms_remote.h"

static int sock;
static struct sockaddr_in sa;

extern int comms_conn;

int comms_remote_setup( const char *server, int port )
{
	struct hostent *hp;

	dprintf("%s: Talking to %s\n", __FUNCTION__, server);

	if ( !server || !server[0] ) {
		alert("No server defined\n");
		return EINVAL;
	}

	if ( !( hp = gethostbyname( server ) ) ) {
		herror("gethostbyname");
		return EINVAL;
	}

	sa.sin_family = AF_INET;
	sa.sin_port = htons(port ? port : 143); /* IMAP Port */
	memcpy(&sa.sin_addr, hp->h_addr_list[0], hp->h_length);

	comms_conn = 0;

	return 0;
}


int comms_remote_connect( void )
{
	if ( comms_conn || sock != -1 ) {
		alert("Connecting, but already comms_conn.\n");
		comms_remote_close();
	}

	sock = socket( AF_INET, SOCK_STREAM, 0 );
	if ( sock < 0 ) {
		return errno;
	}

	if ( connect(sock, (struct sockaddr*)&sa, sizeof(sa) ) < 0 ) {
		if ( close( sock ) ) {
			perror("close");
		}
		sock = -1;
		return errno;
	}

	comms_conn = 1;

	return 0;
}


size_t comms_remote_read( void *buf, size_t count )
{
	dprintf( "In %s\n", __FUNCTION__ );
	if ( !comms_conn ) {
		error("System not comms_conn\n");
	}

	return read(sock, buf, count);
}


size_t comms_remote_write( void *buf, size_t count )
{
	if ( !comms_conn ) {
		error("System not comms_conn\n");
	}

	return write(sock, buf, count);
}


int comms_remote_close( void )
{
	if ( !comms_conn ) {
		return 0;
	}

	close(sock); sock = -1;
	comms_conn = 0;

	return 0;
}


void comms_remote_destroy( void )
{
	if ( comms_conn ) {
		comms_remote_close();
	}
	dprintf("%s:\n", __FUNCTION__);
}

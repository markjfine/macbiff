/*
 * $Id: comms_local.c 58 2004-04-01 21:19:08Z bmoore $
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
 * Communications Wrapper for Local Connection
 */

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/uio.h>

#include "debug.h"
#include "comms_local.h"

static int readfd;
static int writefd;
static pid_t child = 0;
static char imapd[1024];

extern int comms_conn;

int comms_local_setup( const char *server )
{

	dprintf("%s: Talking to %s\n", __FUNCTION__, server);

	if ( !server || !server[0] ) {
		/*alert("No server defined\n");*/
		return EINVAL;
	}

	strncpy(imapd, server, 1023);
	comms_conn = 0;

	return 0;
}


int comms_local_connect( void )
{
	int to_child[2];
	int from_child[2];

/*	if ( comms_conn ) {
		alert("Connecting, but already comms_conn.\n");
	}*/

	if ( pipe(to_child) || pipe(from_child) ) {
		return errno;
	}
	child = fork();
	if ( child < 0 ) {
		return errno;
	} else if ( !child ) { /* Child */
		if ( dup2(to_child[0], 0) == -1 ||
				dup2(from_child[1], 1) == -1 ||
				dup2(from_child[1], 2) == -1 ) {
			perror("dup2");
			exit(1);
		}

		execlp( imapd, imapd, NULL );
		perror("exec");
		exit(1);
	}

	readfd = from_child[0];
	writefd = to_child[1];

	comms_conn = 1;

	return 0;
}

size_t comms_local_read( void *buf, size_t count )
{
	if ( !comms_conn ) {
		error("System not connected\n");
	}

	return read( readfd, buf, count );
}


size_t comms_local_write( void *buf, size_t count )
{
	if ( !comms_conn ) {
		error("System not comms_conn\n");
	}

	return write(writefd, buf, count);
}


int comms_local_close( void )
{
	int status;

	if ( !comms_conn ) {
		return 0;
	}

	kill( child, SIGTERM );
	waitpid( child, &status, 0);
	close(readfd); readfd = -1;
	close(writefd); writefd = -1;
	comms_conn = 0;

	return 0;
}


void comms_local_destroy( void )
{
	if ( comms_conn ) {
		comms_local_close();
	}
	dprintf("%s:\n", __FUNCTION__);
}

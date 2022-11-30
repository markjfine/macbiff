/*
 * $Id: comms.c 180 2012-02-12 16:29:03Z lhagan $
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
 * Communications Wrapper
 */

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/uio.h>

#if 0
# define EBUG 1
#endif
#include "debug.h"
#include "comms.h"
#include "comms_local.h"
#include "comms_remote.h"
#include "comms_ssl.h"

#define MIN(a,b) a<b?a:b

static cmode_t comms_mode = NIL;
static cmode_t used = NIL;
int comms_conn = 0;

int comms_setup( cmode_t mode, const char *server, int port )
{
	static int first_run = 1;
	int res = 1;
	dprintf("%s: Mode: %d\t Talking to %s\n", __FUNCTION__, mode, server);

	if ( !server || !server[0] ) {
		alert("No server defined\n");
		return EINVAL;
	}
	if ( mode == NIL ) {
		alert("Calling comms_setup on NIL\n");
		return EINVAL;
	}

	comms_mode = mode;
	used |= mode;

	switch ( comms_mode ) {
	case NIL:						break;
	case LOCAL: res = comms_local_setup(server);		break;
	case REMOTE: res = comms_remote_setup(server, port);	break;
	case REMOTESSL: res = comms_ssl_setup(server, port);	break;
	}

	if ( first_run ) {
		atexit(comms_destroy);
		first_run = 0;
	}
	return res;
}


int comms_connect( void )
{
	int res = 1;
	comms_conn = 0;
	switch ( comms_mode ) {
	case NIL:					break;
	case LOCAL: res = comms_local_connect();	break;
	case REMOTE: res = comms_remote_connect();	break;
	case REMOTESSL: res = comms_ssl_connect();	break;
	}
	return res;
}


size_t comms_read( void *buf, size_t count )
{
	size_t i = 0;
	size_t returnlen = 0;
	char *optr = NULL;
	char *sptr = NULL;		/* Start of buffer */
	static size_t rbufdatalen = 0;
	static char rbuf[2048];

	if ( !comms_conn ) {
		error("System not comms_conn\n");
	}

	if ( !count ) return 0;
	if ( !buf ) {
		error("Must pass a valid buffer\n");
	}

	bzero(buf, count);

	dprintf("Buffer contains %lu bytes: [[[%s]]]\n",
			rbufdatalen, rbuf);

	/* Look for a newline */
	optr = strchr(rbuf, '\n');
	dprintf("optr:   %p\n", optr);
	if ( optr || rbufdatalen > count ) {
		i = optr ? optr-rbuf+1 : rbufdatalen;
		/* Copy into buf, rbuf up to min(buffer size, newline,
		 * rbufdatalen
		 */
		returnlen = MIN(count-1, i);
		memcpy( buf, rbuf, returnlen );

		memmove( rbuf, rbuf+returnlen, 2048-returnlen );
		rbufdatalen = rbufdatalen - returnlen;
		memset( rbuf+rbufdatalen, 0, returnlen );
		dprintf("returning %lu bytes [%s]\n", returnlen, (char*)buf);
		return returnlen;
	} else {
		sptr = rbuf+rbufdatalen;
		returnlen = 2048 - rbufdatalen;
		/* Fill up the buffer */
		switch ( comms_mode ) {
			case NIL:
				break;
			case LOCAL: i = comms_local_read(sptr, returnlen);
				break;
			case REMOTE: i = comms_remote_read(sptr, returnlen);
				break;
			case REMOTESSL: i = comms_ssl_read(sptr, returnlen);
				break;
		}
		if ( (int)i <= 0 ) {
			if ( errno != EINTR && ( errno || (int)i < 0 ) )
				alert("read: %s\n", strerror(errno));
			return i;
		}
		dprintf("Read %d bytes: [[[%s]]]\n", (int)i, sptr);
		sptr += i;
		rbufdatalen += i;
		dprintf("Buffer contains %d bytes: [[[%s]]]\n",
				sptr - rbuf, rbuf);
		return comms_read( buf, count );
	}
}


size_t comms_write( void *buf, size_t count )
{
	size_t res = 1;
	switch ( comms_mode ) {
	case NIL:						break;
	case LOCAL: res = comms_local_write(buf, count);	break;
	case REMOTE: res = comms_remote_write(buf, count);	break;
	case REMOTESSL: res = comms_ssl_write(buf, count);	break;
	}
	return res;

}


int comms_close( void )
{
	int res = 1;
	switch ( comms_mode ) {
	case NIL:					break;
	case LOCAL: res = comms_local_close();		break;
	case REMOTE: res = comms_remote_close();	break;
	case REMOTESSL: res = comms_ssl_close();	break;
	}
	return res;

}


void comms_destroy( void )
{
	if ( used & LOCAL ) {
		comms_local_destroy();
	}
	if ( used & REMOTE ) {
		comms_remote_destroy();
	}
	if ( used & REMOTESSL ) {
		comms_ssl_destroy();
	}
	dprintf("%s:\n", __FUNCTION__);
	comms_mode = NIL;
}


int comms_connected( void )
{
	return comms_conn;
}

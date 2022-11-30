/*
 * $Id: comms_remote.h 76 2004-07-07 19:22:43Z bmoore $
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
 * comms_remote.h - Communications wrapper for remote connections
 */

#ifndef COMMS_REMOTE_H_
#define COMMS_REMOTE_H_

#include <sys/types.h>

int comms_remote_setup( const char *server, int port );
int comms_remote_connect( void );
size_t comms_remote_read( void *buf, size_t count );
size_t comms_remote_write( void *buf, size_t count );
int comms_remote_close( void );
void comms_remote_destroy( void );

#endif /* COMMS_REMOTE_H_ */

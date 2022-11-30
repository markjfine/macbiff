/*
 * $Id: comms_local.h 42 2004-03-22 23:45:52Z bmoore $
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
 * comms_local.h - Communications wrapper for LOCAL connections
 */

#ifndef COMMS_LOCAL_H_
#define COMMS_LOCAL_H_

#include <sys/types.h>
#include "comms.h"

int comms_local_setup( const char *server );
int comms_local_connect( void );
size_t comms_local_read( void *buf, size_t count );
size_t comms_local_write( void *buf, size_t count );
int comms_local_close( void );
void comms_local_destroy( void );

#endif /* COMMS_LOCAL_H_ */

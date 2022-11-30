/*
 * $Id: xmalloc.h 58 2004-04-01 21:19:08Z bmoore $
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


#ifndef XMALLOC_H_
#define XMALLOC_H_


#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include "debug.h"

#define xmalloc(var, type, count) \
	do { \
		size_t _size = count * sizeof(type); \
		if ( ( var = (type *)malloc( _size ) ) == NULL ) { \
			error("malloc: %s\n", strerror( errno ) ); \
		} else { \
			memset( var, 0, _size ); \
		} \
	} while ( 0 )

#define xrealloc(var, type, count) \
	do { \
		type *_tmp = NULL; \
		size_t _size = count * sizeof(type);  \
		_tmp = (void*)realloc( var, _size ); \
		if ( _tmp == NULL ) { \
			alert("realloc: %s\n", strerror( errno ) ); \
		} else { \
			var = _tmp; \
		} \
	} while ( 0 )


#define xfree( var ) \
	do { \
		if ( var != NULL ) { \
			free( var ); \
			var = NULL; \
		} else { \
			alert("Double Free on " #var "!\n"); \
		} \
	} while ( 0 )

#endif /* XMALLOC_H_ */


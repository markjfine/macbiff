/*
 * $Id: debug.h 165 2009-11-29 03:22:51Z lhagan $
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
 * Debugging routines
 *  - Defines:  dprintf(), alert() and error()
 */

#ifndef DEBUG_H_
#define DEBUG_H_

#include <stdio.h>
#include <stdlib.h>

// don't print the absolute file path in alerts
#define THIS_FILE ((strrchr(__FILE__, '/') ?: __FILE__ - 1) + 1)

extern FILE *_dbgfp;
extern int debug;
#if defined(__GNUC__) && (__GNUC__==3)
# define alert(...) \
	do { \
		fprintf(_dbgfp, "ALERT: [%s:%d] ", THIS_FILE, __LINE__ ); \
		fprintf(_dbgfp, ##__VA_ARGS__); \
		fflush(_dbgfp); \
	} while (0)
#else
# define alert(fmt, ...) \
	do { \
		fprintf(_dbgfp, "ALERT: [%s:%d] " fmt, \
			THIS_FILE, __LINE__ , ##__VA_ARGS__); \
		fflush(_dbgfp); \
	} while (0)
#endif


#if defined(__GNUC__) && (__GNUC__==3)
# define error(...) \
	do { \
		fprintf(_dbgfp, "ERROR: [%s:%d] ", THIS_FILE, __LINE__ ); \
		fprintf(_dbgfp, ##__VA_ARGS__); \
		fflush(_dbgfp); \
		abort(); \
	} while (0)
#else
# define error(fmt, ...) \
	do { \
		fprintf(_dbgfp, "ERROR: [%s:%d] " fmt, \
			THIS_FILE, __LINE__ , ##__VA_ARGS__); \
		fflush(_dbgfp); \
		abort(); \
	} while (0)
#endif

#if defined(EBUG) && EBUG
#  if defined(__GNUC__) && (__GNUC__==3)
#    define dprintf(...) \
	do { \
		fprintf(_dbgfp, "DEBUG: [%s:%d] ", THIS_FILE, __LINE__); \
		fprintf(_dbgfp, ##__VA_ARGS__); \
		fflush(_dbgfp); \
	} while(0)
#  else
#    define dprintf(fmt, ...) \
	do { \
		fprintf(_dbgfp, "DEBUG: [%s:%d] " fmt, \
			THIS_FILE, __LINE__ , ##__VA_ARGS__); \
		fflush(_dbgfp); \
	} while(0)
#  endif
#else
#  if defined(__GNUC__) && (__GNUC__==3)
#    define dprintf(...) do { } while(0)
#  else
#    define dprintf(fmt, ...) do { } while(0)
#  endif
#endif

#endif /* DEBUG_H_ */

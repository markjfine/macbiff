/*
 * $Id: main.m 165 2009-11-29 03:22:51Z lhagan $
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

#import <Cocoa/Cocoa.h>
#include <sys/types.h>
#include <unistd.h>
#if 0
#define EBUG 1
#define EBUGFILE 1
#endif
#include "debug.h"

//FILE *_dbgfp = stderr;
// stderr fix from http://gcc.gnu.org/ml/gcc-help/2005-01/msg00273.html
FILE * _dbgfp;

//void init_dbgfp()
void init_dbgfp(void)
{
	_dbgfp = stderr;
}


int main(int argc, const char *argv[])
{
	init_dbgfp();
#if defined(EBUG) && EBUG && defined(EBUGFILE)
	char debugfile[64];
	snprintf(debugfile, 64, "/tmp/MacBiff.debug.%u", getpid());
	_dbgfp = fopen(debugfile, "w");
#endif
	return NSApplicationMain(argc, argv);
}

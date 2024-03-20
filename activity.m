/* vim:set ft=objc:
* $Id: activity.m 171 2010-03-04 00:56:53Z lhagan $
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

#import "activity.h"

#if 0
# define EBUG 1
#endif
#include "debug.h"

activity* actWin = NULL;


@implementation activity

- (void) reset
{
	dprintf("Resetting Activity Window\n");
	[ProgOverall setDoubleValue: 0.0];
	[ProgServer setDoubleValue: 0.0];
	[Server setStringValue: idleString];
	[Activity setStringValue: nullString];
	_currCount = 0;
	_outOf = 0;
}

- (id) init
{
	self = [super init];
	actWin = self;
	serverpctg = 1.0;
	idleString = [[NSString alloc] initWithString: @"--- idle ---"];
	nullString = [[NSString alloc] initWithString: @""];
	[self reset];

	return self;
}


- (void) dealloc
{
	[idleString release];
	[nullString release];
	actWin = NULL;
	[super dealloc];
}


- (IBAction) display: (id) sender
{
	[Window makeKeyAndOrderFront: self];
	[NSApp activateIgnoringOtherApps: YES];
}


- (void) close
{
    dispatch_queue_main_t queue;

    queue = dispatch_get_main_queue();
    dispatch_async(queue, ^{
        [Window close];
    });
}


- (bool) isOpen
{
	return [Window isVisible];
}


- (IBAction) startChecking: (id) sender;
{
	NSNumber *num = (NSNumber*)sender;
	dprintf("Starting a check of %d servers\n", [num intValue]);
	_outOf = [num intValue];
	_currCount = 0;
}


- (IBAction) startServer: (id) sender;
{
	NSString *serverName = (NSString*)sender;
	_currCount++;

	dprintf("Starting server %s\n", [serverName UTF8String]);
	[Server setStringValue: serverName];
	serverpctg = 1.0 / (double)_outOf;

	dprintf("Setting overall to: %lf (serverpctg: %lf)\n",
			(serverpctg*_currCount), serverpctg);
	[ProgOverall setDoubleValue: (serverpctg*_currCount)];
	[ProgServer setDoubleValue: 0.0];
}


- (IBAction) doingActivity: (id) sender;
{
	NSString *chore = (NSString*)sender;
	[Activity setStringValue: chore];
}


- (IBAction) activityDone: (id) sender
{
	NSNumber *increment = (NSNumber*)sender;
	[ProgServer incrementBy: [increment doubleValue]];
	[ProgOverall incrementBy: [increment doubleValue]*serverpctg];
	[Activity setStringValue: nullString];
}


- (IBAction) finished: (id) sender
{
	[self reset];
}


@end

/*
 * $Id: folderlist.m 181 2012-02-12 18:39:45Z lhagan $
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

#if 0
# define EBUG 1
#endif
#include "debug.h"

#import "imap.h"
#import "mailbox.h"
#import "folderlist.h"

@implementation folderlist

- (id) init
{
	self = [super init];
	rootBox = [[[mailbox alloc] init: @"temporary"
			andShortName: @"temp"] retain];
	return self;
}


- (void) setServer: (imap*) server
{
	int i;
	self = [super init];

	[rootBox setShortName: [server name]];
	[[rootBox subBoxes] removeAllObjects];
	for ( i = 0 ; i < [[server mailboxes] count]; ++i ) {
		[[rootBox subBoxes] addObject: [[server mailboxes] objectAtIndex: i]];
	}

	[outlineView reloadData];

}


- (void) dealloc
{
	[rootBox release];
	[super dealloc];
}


/* Data Source */

- (int) outlineView: (NSOutlineView *) ov
	numberOfChildrenOfItem: (id)item
{
//    return (item == nil) ? [[rootBox subBoxes] count] : [[item subBoxes] count];
	return (item == nil) ? (int)[[rootBox subBoxes] count] : (int)[[item subBoxes] count];
}


- (BOOL) outlineView: (NSOutlineView *) ov
	isItemExpandable: (id)item
{
	return (item == nil) ? [[rootBox subBoxes] count] : ([[item subBoxes] count]);
}


- (id) outlineView: (NSOutlineView *) ov
	child: (int)index
	ofItem: (id)item
{
	return (item == nil) ? [[rootBox subBoxes] objectAtIndex: index] :
		[[item subBoxes] objectAtIndex: index];
}

- (id) outlineView: (NSOutlineView *) ov
	objectValueForTableColumn: (NSTableColumn *)tableColumn
	byItem:(id)item
{
	NSString *identifier = [tableColumn identifier];
	if ( [identifier isEqual: @"Ignore"] ) {
		return item ? [NSNumber numberWithBool:
				[item isIgnored]] :
			[NSNumber numberWithInt:
				[rootBox isIgnored]];
	} else if ( [identifier isEqual: @"Disabled"] ) {
		return item ? [NSNumber numberWithBool: [item isDisabled]] :
			       [NSNumber numberWithInt: [rootBox isDisabled]];
	} else {
		return item ? (id)[item name] : [rootBox name];
	}

}


- (void) outlineView: (NSOutlineView *) ov
	setObjectValue: (id)object
	forTableColumn: (NSTableColumn *)tableColumn
	byItem: (id)item
{
	NSString *identifier = [tableColumn identifier];
	if ( [identifier isEqual: @"Ignore"] ) {
		[item setIgnored: [object boolValue]];
	} else if ( [identifier isEqual: @"Disabled"] ) {
		[item setDisabled: [object boolValue]];
	}

	[ov reloadItem: item reloadChildren: YES];
}


@end

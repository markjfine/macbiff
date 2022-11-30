/*
 * $Id: detachlist.m 99 2004-10-20 23:25:12Z bmoore $
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
#import "detachlist.h"

@implementation detachlist

- (id) init
{
	self = [super init];
	_servers = [[NSMutableArray alloc] initWithCapacity: 5];
	_pruned = YES;
	[unreadButton setState: NSOnState];
	return self;
}


- (void) dealloc
{
	[_servers release];
	[super dealloc];
}


- (void) setServers: (NSArray*) servers
{
	int i;

	[_servers removeAllObjects];
	for ( i = 0 ; i < [servers count]; ++i ) {
		[_servers addObject: [servers objectAtIndex: i]];
	}

	[self switchUnread: self];

}

- (IBAction) switchUnread: (id) sender
{
	int i;
	/* Switch modes */
	_pruned = ( [unreadButton state] == NSOnState );

	[outlineView reloadData];

	for ( i = 0 ; i < [_servers count] ; ++i ) {
		[outlineView expandItem: [_servers objectAtIndex: i]
			expandChildren: _pruned];
		[outlineView reloadItem: [_servers objectAtIndex: i]
			reloadChildren: YES];
	}
}


- (void) updateData
{
	[outlineView reloadData];
}


/* Data Source */

- (int) numberOfChildrenOfItemFull: (id)item
{
	if ( [item isKindOfClass: [imap class]]  ) {
		return [[item mailboxes] count];
	} else if ( [item isKindOfClass: [mailbox class]] ) {
		return [[item subBoxes] count];
	} else {
		dprintf("Unknown class for %p\n", item);
		return 0;
	}
}


- (int) countNonPruned: (NSArray*)list
{
	int i;
	int sum = 0;
	mailbox *box;
	for ( i = 0 ; i < [list count] ; ++i ) {
		box = [list objectAtIndex: i];
		if ( ![box isPruned] ) {
			sum++;
		}
	}
	return sum;
}


- (int) numberOfChildrenOfItemPruned: (id)item
{
	if ( [item isKindOfClass: [imap class]] ) {
		return [self countNonPruned: [item mailboxes]];
	} else if ( [item isKindOfClass: [mailbox class]] ) {
		return [self countNonPruned: [item subBoxes]];
	} else {
		dprintf("Unknown class for %p\n", item);
		return 0;
	}
}


- (int) outlineView: (NSOutlineView *) ov
	numberOfChildrenOfItem: (id)item
{
	if ( item ) {
		if ( [item isKindOfClass: [imap class]] && ![item enabled] ) {
			return 0;
		} else if ( _pruned ) {
			return [self numberOfChildrenOfItemPruned: item];
		} else {
			return [self numberOfChildrenOfItemFull: item];
		}
	} else {
		return [_servers count];
	}
}


- (BOOL) outlineView: (NSOutlineView *) ov
	isItemExpandable: (id)item
{
	return [self outlineView: ov numberOfChildrenOfItem: item];
}


- (id) prunedChild: (int) index ofArray: (NSArray*) list
{
	int count = -1;
	int i = 0;
	mailbox *box = nil;
	while ( count < index && i < [list count] ) {
		box = [list objectAtIndex: i++];

		if ( ![box isPruned] ) count++;
	}
	return box;
}


- (id) outlineView: (NSOutlineView *) ov
	child: (int)index
	ofItem: (id)item
{
	NSArray *array;

	if ( item ) {
		if ( [item isKindOfClass: [imap class]]  ) {
			array = [item mailboxes];
		} else if ( [item isKindOfClass: [mailbox class]] ) {
			array = [item subBoxes];
		} else {
			dprintf("Unknown class for %p\n", item);
			return nil;
		}
		if ( _pruned ) {
			return [self prunedChild: index ofArray: array];
		} else {
			return [array objectAtIndex: index];
		}
	} else if ( item && _pruned ) {
		return [self prunedChild: index ofArray: item];
	} else {
		return [_servers objectAtIndex: index];
	}
}

- (id) outlineView: (NSOutlineView *) ov
	objectValueForTableColumn: (NSTableColumn *)tableColumn
	byItem:(id)item
{
	if ( !item ) return nil;

	NSString *identifier = [tableColumn identifier];
	if ( [identifier isEqual:@"Unread"] ) {
		if ( [item isKindOfClass: [imap class]] ) {
			return [NSNumber numberWithInt: [item messagesUnread]];
		} else if ( [item isKindOfClass: [mailbox class]] ) {
			if ( [item isSelected] )
				return [NSNumber numberWithInt: [item unread]];
			else
				return @"-";
		} else {
			dprintf("Unknown class for %p\n", item);
			return nil;
		}
	} else if ( [identifier isEqual:@"Total"] ) {
		if ( [item isKindOfClass: [imap class]] ) {
			return [NSNumber numberWithInt: [item messagesTotal]];
		} else if ( [item isKindOfClass: [mailbox class]] ) {
			if ( [item isSelected] )
				return [NSNumber numberWithInt: [item total]];
			else
				return @"-";
		} else {
			dprintf("Unknown class for %p\n", item);
			return nil;
		}
	} else {
		if ( [item isKindOfClass: [imap class]] ) {
			return [item name];
		} else if ( [item isKindOfClass: [mailbox class]] ) {
			return [item name];
		} else {
			dprintf("Unknown class for %p\n", item);
			return nil;
		}
	}

}


@end

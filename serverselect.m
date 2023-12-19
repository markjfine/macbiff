/*
 * $Id: serverselect.m 42 2004-03-22 23:45:52Z bmoore $
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


#import "imap.h"
#import "serverselect.h"
#include "debug.h"

@implementation serverselect

- (id) initWithServers: (NSArray*)servers
{
	_names = servers;
	[TV reloadData];
	return self;
}


- (void) replaceServers: (NSArray*)servers
{
	[self initWithServers: servers];
}




/* Protocol Support */
- (int) numberOfRowsInTableView: (NSTableView *)tableView
{
//    return [_names count];
	return (int)[_names count];
}


- (id) tableView: (NSTableView *)tableView
	objectValueForTableColumn: (NSTableColumn *)tableColumn
	row: (int)row
{
	imap *server = [_names objectAtIndex: row];
	NSString *identifier = [tableColumn identifier];
	if ( [identifier isEqual: @"Enabled"] ) {
		return [NSNumber numberWithBool: [server enabled]];
	} else {
		return [server name];
	}
}


- (void) tableView: (NSTableView *)tableView
	setObjectValue: (id)object
	forTableColumn: (NSTableColumn *)tableColumn
	row: (int)row
{
	NSString *identifier = [tableColumn identifier];
	if ( row >= [_names count] ) {
		alert("Attempting to insert into non-existant row.\n");
	} else {
		imap *server = [_names objectAtIndex: row];
		if ( [identifier isEqual: @"Enabled"] ) {
			[server setEnabled: [object boolValue]];
		} else {
			[server setName: object];
		}
	}
}



@end

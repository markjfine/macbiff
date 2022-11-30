/* vim:set ft=objc:
 * $Id: detachlist.h 71 2004-06-03 03:15:33Z bmoore $
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

@interface detachlist : NSObject {
	NSMutableArray *_servers;
	bool _pruned;
	IBOutlet NSOutlineView *outlineView;
	IBOutlet NSButton *unreadButton;
}

- (void) setServers: (NSArray*) servers;
- (void) updateData;
- (IBAction) switchUnread: (id) sender;

@end

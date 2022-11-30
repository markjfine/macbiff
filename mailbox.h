/* vim:set ft=objc:
 * $Id: mailbox.h 180 2012-02-12 16:29:03Z lhagan $
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

@interface mailbox : NSObject {
	NSString *_name;
	NSString *_fullname;
	bool _selected;
	bool _pruned;
	int _newmail;
	int _total;
	int _unread;
	NSMutableArray *_subBoxes;
	NSMutableArray *_envelopes;
	bool _ignored;
	bool _disabled;
}

- (id) init: (NSString*) fullname andShortName: (NSString*) name;
- (NSUInteger) hash;
- (NSString*) fullname;
- (void) setFullname: (NSString*) name;
- (NSString*) name;
- (void) setShortName: (NSString*) name;
- (bool) isSelected;
- (void) setSelected: (bool) sel;
- (bool) isPruned;
- (void) setPruned: (bool) pruned;
- (int)  total;
- (void) setTotal: (int) total;
- (int)  unread;
- (void) setUnread: (int) unread;
- (bool) isIgnored;
- (void) setIgnored: (bool) ignored;
- (bool) isDisabled;
- (void) setDisabled: (bool) disabled;
- (int) newMail;
- (void) setNewMail: (int) newmail;
- (void) addNewMail: (int) newmail;
- (NSMutableArray*) subBoxes;
- (NSMutableArray*) envelopes;
- (NSMenu*) headerMenu;
- (NSString*) newMailDetails;
- (NSString*) descName;
- (NSComparisonResult) compareNames: (mailbox*) obox;
- (bool) isEqual: (id) anObject;

@end

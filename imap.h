/* vim:set ft=objc:
 * $Id: imap.h 167 2010-01-16 19:54:11Z lhagan $
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
#import "imapd.h"
#import "envelope.h"
#include "comms.h"
#import "mailbox.h"

@interface imap : NSObject {
	imapd *_remote;
	NSString *_name;
	NSString *_server;
	NSString *_username;
	NSString *_passwd;
	bool	  _storedPW;
	NSString *_prefix;
	NSString *_sep;
	int _port;
	bool _subscribedOnly;
	cmode_t _mode;
	NSMutableArray *_mailboxes;
	NSMutableArray *_boxesWithNewMail;
	int _cmduid;
	unsigned _messagesTotal;
	unsigned _messagesUnread;
	bool _newMail;
	bool _enabled;
	unsigned _boxesTotal;
	envelope *_tenv;
	bool _firstCheck;
	NSString *_newMailDetails;
}

- (id) init;
- (id) initFromPrefs: (NSString*) name;

- (void) setName: (NSString*) name;
- (NSString*) name;
- (void) setServer: (NSString*) server;
- (NSString*) server;
- (void) setUsername: (NSString*) username;
- (NSString*) username;
- (void) setPrefix: (NSString*) prefix;
- (NSString*) prefix;
- (void) setPassword: (NSString*) passwd andKeep: (bool) keep;
- (void) setMode: (cmode_t) mode;
- (cmode_t) mode;
- (mailbox*) findBox: (NSArray*) path
		inBoxArray: (NSMutableArray*) boxes
		withDepth: (int) depth;
- (NSArray*) mailboxes;
- (bool) savesPW;
- (void) setEnabled: (bool) enable;
- (bool) enabled;
- (void) setPort: (int) port;
- (int) port;
- (void) setSubOnly: (bool) sub;
- (bool) subOnly;

- (NSString*) newMailDetails;

- (unsigned) messagesTotal;
- (unsigned) messagesUnread;
- (bool) newMail;
- (NSArray*) newMailFolders;

- (void) storePrefs;

- (int) checkMail;
- (void) addToMenu: (NSMenu*) menu;
- (IBAction)touched:(id)sender;


@end

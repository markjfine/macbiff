/* vim:set ft=objc:
 * $Id: imapd.h 170 2010-03-03 12:50:58Z lhagan $
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
#include "comms.h"

@interface imapd : NSObject {
	bool _conn;
	unsigned _cmduid;

	NSMutableArray *_responseArr;
}

- (bool) connected;
- (NSString*) connectTo: (NSString*) server via: (cmode_t) mode atPort: (int) port;
- (NSArray*) authenticate: (NSString*) username password: (NSString*) passwd;
- (NSString*) quotePassword: (NSString*) passwd;
- (void) disconnect;
- (NSArray*) query: (NSString*) command;
- (bool) isStringOK: (NSString*) str;
- (bool) isOK: (NSArray*) arr;
- (NSString*) getLineWithContents: (NSString*) str fromResponse: (NSArray*)arr;

@end

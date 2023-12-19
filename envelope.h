/* vim:set ft=objc:
 * $Id: envelope.h 180 2012-02-12 16:29:03Z lhagan $
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

void deBase64(char* bin, char* bout);

@interface envelope : NSObject {
	unsigned _uid;
	bool _initialized;
//    NSCalendarDate *_date;
	NSDate *_date;
	NSString *_subject;
	NSString *_from;
	NSString *_sender;
	NSString *_reply_to;
	NSString *_to;
	NSString *_cc;
	NSString *_bcc;
	NSString *_in_reply_to;
	NSString *_message_id;
}

- (id) initWithIMAPEnvelope: (NSString*) env andUID: (unsigned) uid;

- (void) setUID: (unsigned) uid;
- (unsigned) uid;
//- (NSCalendarDate*) date;
- (NSDate*) date;
- (NSString*) subject;
- (NSString*) from;
- (NSString*) sender;
- (NSString*) reply_to;
- (NSString*) to;
- (NSString*) cc;
- (NSString*) bcc;
- (NSString*) in_reply_to;
- (NSString*) message_id;
- (bool) initialized;

@end

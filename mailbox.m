/*
 * $Id: mailbox.m 180 2012-02-12 16:29:03Z lhagan $
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

#import "mailbox.h"
#import "envelope.h"

#if 0
# define EBUG 1
#endif

#include "debug.h"

NSString* deUTF7IMAPString(NSString* istr) {
	dprintf("encoded name: %s\n", [istr UTF8String]); 
	NSMutableString* ostr = [NSMutableString stringWithString: istr];
	NSRange range = [ostr rangeOfString: @"&"];
	while (range.location != NSNotFound) {
		NSRange range2 = [ostr rangeOfString: @"-"
									  options: NSLiteralSearch
										range: NSMakeRange(range.location + 1, 
										   [ostr length] - range.location - 1)];
		if (range2.location == NSNotFound) {
			return ostr;
		}
		range.length = range2.location - range.location + 1;
		dprintf("location: %d, length: %d\n", range.location, range.length);
		if (range.length > 2) {	/* decode base64 */
			int lpad = 4 - (range.length - 2) % 4;
			if (lpad != 4) {
				[ostr insertString: [[[NSString alloc] initWithCString: "===" length: lpad] autorelease]
						   atIndex: range.location + range.length - 1];
				range.length += lpad;
			}
			[ostr replaceOccurrencesOfString: @"," withString: @"/" options: NSLiteralSearch range: range];
			NSString* encodedText = [ostr substringWithRange: NSMakeRange(range.location + 1, range.length - 2)];
			dprintf("tmp base64: %s\n", [encodedText UTF8String]); 
			NSMutableData* encodedData = [[[NSMutableData alloc] init] autorelease];
			[encodedData setData: [encodedText dataUsingEncoding: NSASCIIStringEncoding
										allowLossyConversion: YES]]; 
			char fdata[4];
			char tdata[3];
			NSRange buf;
			int i;
			for (i = encodedData.length - 4; i >= 0; i -= 4) {
				buf = NSMakeRange(i, 4);
				[encodedData getBytes: fdata range: buf];
				deBase64(fdata, tdata);
				[encodedData replaceBytesInRange: buf
									   withBytes: tdata length: 3];
			}
			encodedText = [[[NSString alloc] initWithData: encodedData
										   encoding: NSUnicodeStringEncoding] autorelease];
			[ostr replaceCharactersInRange: range withString: encodedText];
		}
		if (range.length == 2) {	/* '&-' -> '&' */
			[ostr replaceCharactersInRange: range withString: @"&"];
		}
		range.location++;
		range.length = [ostr length] - range.location;
		range = [ostr rangeOfString: @"&"
							options: NSLiteralSearch
							  range: range];
	}
	dprintf("decoded name: %s\n", [ostr UTF8String]); 
	return ostr;
}

@implementation mailbox

- (id) init: (NSString*) fullname
		andShortName: (NSString*) name
{
	self = [super init];
	_name = [[NSString alloc] initWithString: name];
	_fullname = [[NSString alloc] initWithString: fullname];
	_subBoxes = [[NSMutableArray alloc] initWithCapacity: 10];
	_envelopes = [[NSMutableArray alloc] initWithCapacity: 10];
	_ignored = NO;
	_disabled = NO;
	_selected = NO;
	_pruned = NO;
	_total = 0;
	_unread = 0;
	return self;
}


- (void) dealloc
{
	[_subBoxes removeAllObjects];
	[_subBoxes release];

	[_fullname release];
	[_name release];

	[super dealloc];
}


- (NSUInteger) hash
{
	return [_name hash];
}


- (NSString*) fullname
{
	return _fullname;
}


- (void) setFullname: (NSString*) name
{
	if ( _fullname ) [_fullname release];
	_fullname = [[NSString alloc] initWithString: name];
	[_fullname retain];
}


- (NSString*) name
{
	return deUTF7IMAPString(_name);
}


- (void) setShortName: (NSString*) name
{
	if ( _name ) [_name release];
	_name = [[NSString alloc] initWithString: name];
	[_name retain];
}


- (bool) isSelected
{
	return _selected;
}


- (void) setSelected: (bool) sel
{
	_selected = sel;
}


- (bool) isPruned
{
	return _pruned;
}

- (void) setPruned: (bool) pruned
{
	_pruned = pruned;
}


- (int) total
{
	return _total;
}


- (void) setTotal: (int) total
{
	_total = total;
}


- (int)  unread
{
	return _unread < 0 ? 0 : _unread;
}


- (void) setUnread: (int) unread
{
	_unread = unread;
}

- (int) newMail
{
	return _newmail;
}


- (void) setNewMail: (int) newmail
{
	_newmail = newmail;
}


- (void) addNewMail: (int) newmail
{
	_newmail += newmail;
}


- (NSMutableArray*) subBoxes
{
	return _subBoxes;
}


- (NSMutableArray*) envelopes;
{
	return _envelopes;
}


- (IBAction) blank: (id) sender { }

- (NSMenu*) headerMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle: [self name]];
	NSMenuItem *item;
	NSString *tstr;
	envelope *tenv;
	int i;

	for ( i = 0 ; i < [_envelopes count] ; ++i ) {
		tenv = [_envelopes objectAtIndex: i];
		tstr = [NSString stringWithFormat: @"%45@ | %30@ | %@",
			[[tenv date] description],
			[tenv from],
			[tenv subject]];
		item = [[NSMenuItem alloc] initWithTitle: tstr
			action: @selector(blank:) keyEquivalent: @""];
		[item setTarget: self];
		[menu addItem: item];
	}

	return menu;
}

// provide access to message details (sender, description)
- (NSString*) newMailDetails
{
	NSString *tstr = @"";
	NSString *tempstr;
	envelope *tenv;
	int i;
	
	for ( i = 0 ; i < [_envelopes count] ; ++i ) {
		tenv = [_envelopes objectAtIndex: i];
		if ( [tenv from] && [tenv subject] ) {
			tempstr = [NSString stringWithFormat:@"\n\n%15@ | %30@", [tenv from], [tenv subject]];
			tstr = [tstr stringByAppendingString:tempstr];
		}
				
	}
	
	return tstr;
}


- (bool) isIgnored
{
	return _ignored;
}


- (void) setIgnored: (bool) ignored
{
	_ignored = ignored;
}


- (bool) isDisabled
{
	return _disabled;
}

- (void) setDisabled: (bool) disabled
{
	int i;

	_disabled = disabled;
	for ( i = 0 ; i < [_subBoxes count] ; ++i ) {
		[[_subBoxes objectAtIndex: i] setDisabled: disabled];
	}
}


- (NSString*) descName
{
	if ( _selected ) {
		return [NSString stringWithFormat: @"%@ [%d/%d]",
			[self name], _unread < 0 ? 0 : _unread, _total];
	} else {
		return _name;
	}
}


- (NSComparisonResult) compareNames: (mailbox*) obox
{
	return [_name caseInsensitiveCompare: obox->_name];
}


- (bool) isEqual: (id) anObject
{
	return [self hash] == [anObject hash];
}


@end

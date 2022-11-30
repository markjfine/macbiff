/*
 * $Id: envelope.m 180 2012-02-12 16:29:03Z lhagan $
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

#import "envelope.h"
#include <string.h>

#if 0
# define EBUG 1
#endif

#include "debug.h"

int b64translate( char bin )
{
	if ( bin >= 'A' && bin <= 'Z' )
		return bin-65;
	else if ( bin >= 'a' && bin <= 'z' )
		return ((bin-97) + 26);
	else if ( bin >= '0' && bin <= '9' )
		return ((bin-48) + 52);
	else if ( bin == '+' )
		return 62;
	else if ( bin == '/' )
		return 63;
	else
		return 0;
}

void deBase64(char* bin, char* bout)
{
	char buf[4];
	buf[0] = b64translate(bin[0]);
	buf[1] = b64translate(bin[1]);
	buf[2] = b64translate(bin[2]);
	buf[3] = b64translate(bin[3]);
	bout[0] = ((buf[0] << 2) & 0xfc) | ((buf[1] >> 4) & 0x03);
	bout[1] = ((buf[1] << 4) & 0xf0) | ((buf[2] >> 2) & 0x0f);
	bout[2] = ((buf[2] << 6) & 0xc0) | (buf[3] & 0x3f);
}

NSString* deMIMEEncodedWord(NSString* instr)
{
	NSArray *parts = [instr componentsSeparatedByString: @"?"];
	if ( !parts || [parts count] != 5 ) {
		return [NSString stringWithString: instr];
	}
	
	NSString *charset = [parts objectAtIndex: 1];
	NSStringEncoding charEncode =
	CFStringConvertEncodingToNSStringEncoding(
											  CFStringConvertIANACharSetNameToEncoding(
																					   (CFStringRef)charset));
	
	NSString *encoding = [parts objectAtIndex: 2];
	
	NSString *encodedText = [parts objectAtIndex: 3];
	NSMutableData *encodedData = [[[NSMutableData alloc] init] autorelease];
	[encodedData setData: [encodedText dataUsingEncoding:
						   NSASCIIStringEncoding
									allowLossyConversion: YES]];
	int len = [encodedData length];
	
	if ([encoding caseInsensitiveCompare: @"Q"] == NSOrderedSame ) {
		char hex[3] = {0};
		int val = 0;
		char byte;
		int i;
		char *data = (char*)malloc(len);
		[encodedData getBytes: data];
		
		NSRange range;
		for ( i = len-3 ; i >= 0 ; --i ) {
			if ( data[i] != '=' ) {
				continue;
			} else {
				range = NSMakeRange(i, 3);
				hex[0] = data[i+1];
				hex[1] = data[i+2];
				sscanf(hex, "%x", &val);
				byte = val & 0xff;
				[encodedData replaceBytesInRange: range
									   withBytes: (void*)&byte length: 1];
			}
		}
		free(data);
	} else if ([encoding caseInsensitiveCompare: @"B"] == NSOrderedSame ) {
		char fdata[4];
		char tdata[3];
		NSRange range;
		int i;
		for ( i = len-4 ; i >= 0 ; i-=4 ) {
			range = NSMakeRange(i, 4);
			[encodedData getBytes: fdata range: range];
			deBase64(fdata, tdata);
			[encodedData replaceBytesInRange: range
								   withBytes: tdata length: 3];
		}
	}
	
	NSString *ostr= [[[NSString alloc] initWithData: encodedData
										   encoding: charEncode] autorelease];
	return ostr;
}

NSString* deMIMEString( NSString *str )
{
	dprintf("deMIMEing string: '%s' [length: %d]\n", [str UTF8String], [str length]);
	NSMutableString *nStr = [[[NSMutableString alloc] init] autorelease];
	[nStr setString: str];
	NSRange MIMERange = [nStr rangeOfString: @"=?"];
	while ( MIMERange.location != NSNotFound ) {
		NSRange MIMERange2 = [nStr rangeOfString: @"?"
										 options: NSLiteralSearch
										   range: NSMakeRange(MIMERange.location +2,
															  [nStr length] - MIMERange.location -2)];
		MIMERange2 = [nStr rangeOfString: @"?="
								 options: NSLiteralSearch
								   range: NSMakeRange(MIMERange2.location+3,
													  [nStr length] - MIMERange2.location -3)];
		if ( MIMERange2.location == NSNotFound ) {
			return nStr;
		}
		MIMERange.length = MIMERange2.location - MIMERange.location +2;
		NSString *pStr = deMIMEEncodedWord([nStr substringWithRange: MIMERange]);
		dprintf("deMIMEd component: '%s'\n", [pStr UTF8String]);
		if ( pStr ) {
			/* Successful decoding */
			[nStr replaceCharactersInRange: MIMERange withString: pStr];
			MIMERange = [nStr rangeOfString: @"=?"];
		} else {
			/* Failed decoding.  Skip */
			MIMERange.location++;
			MIMERange.length = [nStr length] - MIMERange.location;
			MIMERange = [nStr rangeOfString: @"=?"
									options: NSLiteralSearch
									  range: MIMERange];
		}
	}
	
	return nStr;
}

@implementation envelope

- (NSArray*) parseStringArray: (NSString*) sArr
{
	unsigned length;
	char *i;
	char *j;
	char tchar;
	int pcount;
	char *str = nil;
	NSMutableArray *arr = nil;
	NSArray *tarr;
	NSMutableString *tstr;

	if ( !sArr )
		return nil;

	str = strdup( [sArr UTF8String] );

	if ( str[0] != '(' )
		goto out;

	arr = [[NSMutableArray alloc] initWithCapacity: 4];

	length = strlen( str );
	if ( length != [sArr length] ) {
		alert("Warning, c string length (%u) != NSString length (%u)\n",
				length, [sArr length]);
	}
	dprintf("Analyzing '%s'...\n", str);
	for ( i = str+1 ; *i ; i++ ) {
		if ( *i == ' ' ) {
			continue;
		} else if ( *i == '(' ) {
			/* Start of an array */
			pcount = 1; j = i;
			do {
				j++;
				if ( *j == '(' ) pcount++;
				else if ( *j == ')' ) pcount--;
			} while ( pcount && *j );
			/* Note: Arrays are paren-bound */
			j++;
			tchar = *j;
			*j = '\0';
			tstr = [NSString stringWithCString: i encoding: 4];
			*j = tchar;
			i = j;
			dprintf("Sending '%s' to parse as an array.\n",
					[tstr UTF8String]);
			tarr = [self parseStringArray: tstr];
			if ( tarr ) {
				[arr addObject: tarr];
			}
		} else if ( *i == ')' ) {
			/* End of an array */
			dprintf("Found end of array at %d of %lu\n",
					i-str, strlen(str));
			/* MDaemon 7.0.1 does NOT follow RFC3501 */
			[arr addObject: @"NIL"];
			break;
		} else if ( *i == '\"' ) {
			/* Start of a string */
			j = i+1;

			while ( *j != '\"' ||
					(*j == '\"' && *(j-1) == '\\' &&
						*(j-2) != '\\') ) {
				j++;
			}
			tchar = *j;
			*j = '\0';
			dprintf("Taking string: '%s'\n", i+1);
			tstr = [NSMutableString stringWithCString: i+1 encoding: 4];
			[tstr replaceOccurrencesOfString: @"\\\""
				withString: @"\""
				options: NSLiteralSearch
				range: NSMakeRange(0, [tstr length])];
			*j = tchar;
			i = j;
			dprintf("Storing '%s'\n", [tstr UTF8String]);
			[arr addObject: tstr];
		} else {
			if ( *i != 'N' && *i != 'n' ) {
				dprintf("Unexpected character: %c at"
					" position %d\n", *i, i-str);
			} else {
				dprintf("Storing NIL\n");
				[arr addObject: @"NIL"];
				do { i++; } while ( *i != ' ' && *i != ')');
			}
		}
	}

out:
	free( str );
	dprintf("Returning from %s [[%s]]\n", __FUNCTION__, [sArr UTF8String]);
	return [arr autorelease];
}


- (NSString*) stringFromAddrArray: (NSArray*) arr
{
	if ( !arr ) return @"NA";

	if ( [[arr objectAtIndex: 0] isKindOfClass: [NSArray class]] ) {
		return [self stringFromAddrArray: [arr objectAtIndex: 0]];
	}
	if ( ![[arr objectAtIndex: 0] isEqualTo: @"NIL"] ) {
		return [arr objectAtIndex: 0];
	} else {
		return [NSString stringWithFormat: @"%@@%@",
			[arr objectAtIndex: 2],
			[arr objectAtIndex: 3]];
	}
}


- (NSString*) stringFromObject: (id) obj
{
	if ( [obj isKindOfClass: [NSString class]] ) {
		return obj;
	} else if ( [obj isKindOfClass: [NSArray class]] ) {
	       return [self stringFromAddrArray: obj];
	} else {
		alert("Unrecognized class %s\n", [[obj className] UTF8String]);
		return @"NA";
	}

}



- (id) initWithIMAPEnvelope: (NSString*) env andUID: (unsigned) uid;
{

	if ( !env ) return env;
	self = [super init];

	dprintf("In %s for '%s'\n", __FUNCTION__, [env UTF8String]);
	NSArray* envArr = [self parseStringArray: env];

	_uid = uid;

	int i;
	for ( i = 0 ; i < [envArr count] ; ++i ) {
		dprintf("Object %d is of type %s\n", i,
				[[[envArr objectAtIndex: i] className] UTF8String]);
	}

	_date = [[NSCalendarDate dateWithNaturalLanguageString:
			[envArr objectAtIndex: 0]] retain];
	_subject = [deMIMEString([envArr objectAtIndex: 1]) copy];
	_from = [deMIMEString([self stringFromObject: [envArr objectAtIndex: 2]]) copy];
	_sender = [deMIMEString([self stringFromObject: [envArr objectAtIndex: 3]]) copy];
	_reply_to = [deMIMEString([self stringFromObject: [envArr objectAtIndex: 4]]) copy];
	_to = [deMIMEString([self stringFromObject: [envArr objectAtIndex: 5]]) copy];
	_cc = [deMIMEString([self stringFromObject: [envArr objectAtIndex: 6]]) copy];
	_bcc = [deMIMEString([self stringFromObject: [envArr objectAtIndex: 7]]) copy];
	_in_reply_to = [deMIMEString([envArr objectAtIndex: 8]) copy];
	_message_id = [[envArr objectAtIndex: 9] retain];

	_initialized = YES;

	return (self);
}




- (void) dealloc
{
	[_date release];
	[_subject release];
	[_from release];
	[_sender release];
	[_reply_to release];
	[_to release];
	[_cc release];
	[_bcc release];
	[_in_reply_to release];
	[_message_id release];

	[super dealloc];
}

- (BOOL) isEqual: (id) anObject
{
	envelope *other = anObject;
	return (_uid == [other uid]);
}

- (NSUInteger) hash
{
	return _uid;
}


- (void) setUID: (unsigned) uid
{
	_uid = uid;
}


- (unsigned) uid
{
	return _uid;
}


- (NSCalendarDate*) date
{
	return _date;
}


- (NSString*) subject
{
	return _subject;
}


- (NSString*) from
{
	return _from;
}


- (NSString*) sender
{
	return _sender;
}


- (NSString*) reply_to
{
	return _reply_to;
}


- (NSString*) to
{
	return _to;
}


- (NSString*) cc
{
	return _cc;
}


- (NSString*) bcc
{
	return _bcc;
}


- (NSString*) in_reply_to
{
	return _in_reply_to;
}


- (NSString*) message_id
{
	return _message_id;
}


- (bool) initialized
{
	return _initialized;
}


@end


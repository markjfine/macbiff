/*
 * $Id: imapd.m 181 2012-02-12 18:39:45Z lhagan $
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

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <strings.h>
#include <string.h>

/*#define DEBUG 0*/

#if 0
# define EBUG 1
#endif
#include "debug.h"

#import "imapd.h"
#include "comms.h"
#include "xmalloc.h"

#if DEBUG
#define dwrite(a,b) do { \
		fprintf(_dbgfp, "%s%s", a, b); \
	} while (0)
#else
#define dwrite(a,b) do { } while (0)
#endif

#define isend(msg) do { \
	int _res; \
	int _foo = (int)strlen( msg ); \
	dwrite("> ", msg ); \
	if ( (_res = (int)comms_write( msg, _foo ) ) != _foo) { \
		/*alert("Received %d from write\n", _res ); */ \
		goto out; \
	} \
	dprintf("Sent [%s]\n", msg);  \
} while (0)


#define igets(msg, size) do { \
	int _res; \
    bzero( msg, size ); \
	errno = 0; \
	if ( (_res = (int)comms_read( msg, size ) ) <= 0 ) { \
		/*alert("Received %d from read\n", _res ); */ \
		goto out; \
	} \
	dprintf("Received [%s]\n", msg);  \
} while (0)
#define iget(msg) igets(msg, sizeof(msg))


int escape_quotes( char * buf, int length )
{
	int i = length;

	while ( !buf[i] || isspace(buf[i]) ) i--;

	for ( ; i >1 ; --i ) {
		if ( buf[i] == '\"' && buf[i-1] != '\\' ) {
			/* need to escape */
			memmove(buf+i+1, buf+i, length-i);
			buf[i] = '\\';
			length++;
		}
	}
	if ( buf[0] == '\"' ) {
		memmove(buf+1, buf, length );
		buf[0] = '\\';
		length++;
	}
	return length;
}


@implementation imapd

- (void) close
{
	if ( comms_connected() ) {
		comms_close();
	}
	_conn = NO;
}


- (NSArray *) responseTo: (int) uid
{
	char buf[1024];
	unsigned tmp;
	NSString *str = nil;
	NSString *cleanstr = nil;
	bool done = NO;
	bool startstring = YES;
	bool remoteclosed = NO;
	char *literalbuf = NULL;
	char *literalstart = NULL;
	char *fullbuf = NULL;
	int literallength = 0;
	int x, i;

	[_responseArr removeAllObjects];
	do {
		memset(buf,0,1024);
        iget( buf );

		/* Check for literal string */
		x = (int)strlen( buf );
		literallength = 0;
		literalstart = NULL;
		if (buf[x-2] == 13 && buf[x-3] == '}' ) {
			i = 4;
			while ( isdigit(buf[x-i]) ) i++;
			if ( buf[x-i] == '{' ) {
				literallength = atoi( &(buf[x-i+1]) );
				literalstart = &(buf[x-i]);
			}
		}
		if ( literalstart ) {
			/* found a literal */
			*literalstart = '\"';
			*(literalstart+1) = '\0';
			xmalloc( literalbuf, char, 2*(literallength+2) );
			igets( literalbuf, literallength+1 );
			literallength = escape_quotes( literalbuf, literallength );
			xmalloc( fullbuf, char, strlen(buf)+literallength+3 );
			sprintf( fullbuf, "%s%s\"", buf, literalbuf );
		} else {
			fullbuf = buf;
		}


		if (startstring) {
			str = [NSString stringWithCString: fullbuf encoding: 4];
		} else {
			str = [str stringByAppendingString:
				[NSString stringWithCString: fullbuf encoding: 4]];
		}
		/* startstring : Is there a newline? */
		startstring = (strchr(fullbuf,'\r') != NULL);
		if (startstring) {
			dprintf("added: %s\n", [str UTF8String]);
			cleanstr = [str stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];

			/*
			 * Check for a BYE command
			 */
			remoteclosed |= [cleanstr hasPrefix: @"* BYE"];

			dwrite("< ", [cleanstr UTF8String] );
			dwrite("\n", "");
			[_responseArr addObject: cleanstr];
		}
		done = ( sscanf(fullbuf, "%u", &tmp ) && ( tmp == uid ) );
		if ( literalbuf ) {
			xfree( literalbuf );
			xfree( fullbuf );
		}
	} while ( !done );

	if ( remoteclosed ) {
out:
		dwrite("", "Server closed the connection.\n");
		[self close];
		return nil;
	}

	return _responseArr;
}


- (id) init
{
	self = [super init];
	_conn = NO;
	_cmduid = 0;
	_responseArr = [[NSMutableArray alloc] initWithCapacity: 5];
	return self;
}


- (void) dealloc
{
	if ( _conn ) {
		[self disconnect];
	}
	[_responseArr release];
	[super dealloc];
}


- (bool) connected
{
	return _conn;
}



- (NSString*) connectTo: (NSString*) server via: (cmode_t) mode atPort: (int) port
{
	char buf[1024];
	int res;

	if ( _conn ) {
		alert("Attempting to connect while connected\n");
		[self disconnect];
	}

	if ( ( res = comms_setup( mode, [server UTF8String], port ) ) ) {
		/*alert("comms_setup returned %d\n", res);*/
		errno = res;
		return nil;
	}

	if ( ( res = comms_connect() ) ) {
		alert("comms_connect returned %d\n\t%s\n",
				res, strerror(errno));
		errno = res;
		return nil;
	}
	_conn = YES;

	dwrite("---------------------------   ", [server UTF8String]);
	dwrite(" ----", "\n");
	/* Verify IMAP 4rev1 */
	iget( buf );
	return [NSString stringWithCString: buf encoding: 4];
out:
	errno = 1;
	return nil;
}


- (NSArray*) authenticate: (NSString*) username password: (NSString*) passwd
{
	char buf[1024];
	int res, len;
	if ( !username || !passwd ) return nil;

#if DEBUG
	char buf2[1024];
	memset(buf2, 0, 1024);
	snprintf(buf, 1024, "%05u LOGIN %s \"XXXXXXXX\"\r\n", _cmduid,
			[username UTF8String]);
	dwrite("> ", buf);
#endif


	memset(buf, 0, 1024);
	snprintf(buf, 1024, "%05u LOGIN %s \"%s\"\r\n", _cmduid++,
			[username UTF8String], [[self quotePassword:passwd] UTF8String]);

//    len = strlen( buf );
	len = (int)strlen( buf );
//    if ( (res = comms_write( buf, len ) ) != len) {
	if ( (res = (int)comms_write( buf, len ) ) != len) {
		/*alert("Received %d from write\n", res ); */
		goto out;
	}

	return [self responseTo: (_cmduid-1)];
out:
	return nil;

}

// Fix for: Password with RFC3501 quoted-specials mangled - ID: 2958875
- (NSString*) quotePassword: (NSString*) passwd
{
	char quotedspecials[2] = {'\\', '"'};
	NSString *quote = [NSString stringWithUTF8String: "\\"];
	
	NSString *retval = passwd;
	
	if (retval != nil) {
		int i = 0;
		for (i = 0; i < sizeof(quotedspecials)/sizeof(quotedspecials[0]); i++) {
			
			char unquotedspecial[2] = {quotedspecials[i], '\0'};
			NSString *unquotedspecialstring = [NSString stringWithUTF8String: unquotedspecial];
			
			NSString *quotedspecialstring = [quote stringByAppendingString:unquotedspecialstring];
			
			retval = [retval stringByReplacingOccurrencesOfString: unquotedspecialstring withString: quotedspecialstring];
		}
	}
	
	return retval;
}


- (void) disconnect
{
	char buf[1024];
	if ( _conn && comms_connected() ) {
		snprintf(buf, 1024, "%05u LOGOUT\r\n", _cmduid++ );
		isend( buf );
		do {
			iget( buf );
		} while ( strncmp( buf+6, "OK", 2 ) );
	}
out:
	[self close];
	return;
}


- (NSArray*) query: (NSString*) command
{
	char buf[1024];
	unsigned uid;
	NSArray *arr = nil;

	if ( !_conn ) {
		errno = ENOTCONN;
		return nil;
	}

	if ( !command ) {
		errno = EINVAL;
		return nil;
	}

	uid = _cmduid++;
	snprintf(buf, 1024, "%05u %s\r\n", uid, [command UTF8String] );
	isend( buf );

	arr = [self responseTo: uid];
out:
	if ( !arr ) {
		[NSException raise: @"Bad Comms" format: @"Err: (%d) %s",
			errno, strerror(errno)];
	}
	return arr;
}


- (bool) isStringOK: (NSString*) str
{
	NSArray *arr;
	if ( !str ) return NO;

	arr = [str componentsSeparatedByString: @" "];
	dprintf("Checking %s for OK\n", [str UTF8String] );
	if ( !arr || [arr count] < 2 ) return NO;
	return [[arr objectAtIndex: 1] isEqualToString: @"OK"];
}


- (bool) isOK: (NSArray*) arr
{
	if ( !arr || ![arr count] ) return NO;

	return [self isStringOK: [arr objectAtIndex: [arr count]-1]];
}


- (NSString*) getLineWithContents: (NSString*) str
	fromResponse: (NSArray*)arr
{
	NSString *tstr = nil;
	NSRange range;
	int i = 0;
	if ( !str || !arr ) return nil;

	dprintf("Searching for '%s' in response\n", [str UTF8String]);

	i = -1;
	while ( ++i < [arr count] && !tstr ) {
		range = [[arr objectAtIndex: i] rangeOfString: str];
		if ( range.location != NSNotFound ) {
			tstr = [arr objectAtIndex: i];
		}
	}

	return tstr;
}

@end

/*
 * $Id: imap.m 181 2012-02-12 18:39:45Z lhagan $
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
#include <signal.h>
#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <Security/SecKeychain.h>
#include <Security/SecKeychainItem.h>

#import "activity.h"
#import "imap.h"
#import "mailbox.h"
#import "envelope.h"
#include "comms.h"

#if 0
# define EBUG 1
#endif
#include "debug.h"


extern volatile sig_atomic_t user_pressed_stop;


NSInteger compareMBnames( id s1, id s2, void *ctx )
{
	mailbox *a1 = (mailbox*)s1;
	mailbox *a2 = (mailbox*)s2;
	return [[a1 name] caseInsensitiveCompare: [a2 name]];
}


@implementation imap

/*
 * Private Methods
 */
- (bool) isconfigured
{
	return ( _server && _username && _mode != NIL );
}


- (bool) doHeadersFor: (mailbox*) box
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	return ( [prefs boolForKey: @"Fetch Unread Headers"] &&
			( [prefs boolForKey: @"Fetch Ignored Headers"] ||
				![box isIgnored] ) );
}

- (void) callOutsideProgramOn: (mailbox*)box
{
	NSMutableString *cmd = nil;
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSString *command = [prefs stringForKey: @"New Unread Mail Command"];

	if (command && ![command isEqualToString: @""]) {
		cmd = [[[NSMutableString alloc] init] autorelease];
		[cmd setString:command];
		[cmd replaceOccurrencesOfString: @"%t"
			withString: [NSString stringWithFormat: @"%d",
				[box total]]
			options: NSCaseInsensitiveSearch
			range:  NSMakeRange(0, [cmd length])];
		[cmd replaceOccurrencesOfString: @"%u"
			withString:[NSString stringWithFormat: @"%d",
				[box unread]]
			options: NSCaseInsensitiveSearch
			range:  NSMakeRange(0, [cmd length])];
		[cmd replaceOccurrencesOfString: @"%n"
			withString: [NSString stringWithFormat:@"%d",
				[box newMail]]
			options: NSCaseInsensitiveSearch
			range:  NSMakeRange(0, [cmd length])];
		[cmd replaceOccurrencesOfString: @"%m"
			withString: [box name]
			options: NSCaseInsensitiveSearch
			range:  NSMakeRange(0, [cmd length])];
		[cmd replaceOccurrencesOfString: @"%p"
			withString: [box fullname]
			options: NSCaseInsensitiveSearch
			range:  NSMakeRange(0, [cmd length])];
		[cmd appendString:@" &"];

		dprintf("Execing '%s'\n", [cmd UTF8String]);
		if (system([cmd UTF8String]))
			alert("MacBiff command error: %s\n",
					strerror(errno));
		}
}


- (NSString*) getPWfromKeychain: (SecKeychainItemRef*) ref
	andStatus: (OSStatus*) status
{
//	void *tpw = NULL;
    CFTypeRef tpw = NULL;
	NSString *pw = nil;
    NSMutableData *pwd = nil;
//	UInt32 len;
	UInt32 port = ( _mode == REMOTESSL ) ? 993 : 143;
/*
	*status = SecKeychainFindInternetPassword(
			NULL,
//            [_server length],
			(unsigned)[_server length],
			[_server UTF8String],
			0, NULL,
//            [_username length],
			(unsigned)[_username length],
			[_username UTF8String],
			0,
			NULL,
			port,
			port == 993 ? kSecProtocolTypeIMAPS : kSecProtocolTypeIMAP,
			kSecAuthenticationTypeDefault,
			&len, (void**)&tpw,
			ref);
*/
    NSDictionary *query = @{(__bridge id)kSecClass : (__bridge id)kSecClassInternetPassword,
                            (__bridge id)kSecAttrServer : (__bridge id)_server,
                            (__bridge id)kSecAttrSecurityDomain : @"",
                            (__bridge id)kSecAttrAccount : (__bridge id)_username,
                            (__bridge id)kSecAttrPath : @"",
                            (__bridge id)kSecAttrPort : @(port),
                            (__bridge id)kSecAttrProtocol : (port == 993) ? @"imps" : @"imap",
                            (__bridge id)kSecAttrAuthenticationType : @"dflt",
                            (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
                            (__bridge id)kSecReturnAttributes : @(true),
                            (__bridge id)kSecReturnData : @(true),
                            (__bridge id)kSecReturnRef : @(true)};
        
    *status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &tpw);
    
    if ( tpw && *status == noErr ) {
        pwd = [(id)tpw objectForKey:(__bridge id)kSecValueData];
        ref = (SecKeychainItemRef*)[(id)tpw objectForKey:(__bridge id)kSecValueRef];
//        pw = [NSString stringWithCString: tpw length: len];
        pw = [NSString stringWithCString: pwd.mutableBytes encoding:4];
//		SecKeychainItemFreeContent(NULL, tpw);
	}
	return pw;
}


- (NSString*) getPW
{
	OSStatus status;

	if ( _passwd == nil && _storedPW ) {
		_passwd = [self getPWfromKeychain: NULL andStatus: &status];
		[_passwd retain];
	}

	return _passwd;
}


- (void) storePW
{
	OSStatus status;
	SecKeychainItemRef ref;
	UInt32 port = ( _mode == REMOTESSL ) ? 993 : 143;
	[self getPWfromKeychain: &ref andStatus: &status];
	if ( status == errSecItemNotFound ) {
		/* Add Password */
/*
        SecKeychainAddInternetPassword( NULL,
//            [_server length],
            (unsigned)[_server length],
            [_server UTF8String],
            0, NULL,
//            [_username length],
            (unsigned)[_username length],
            [_username UTF8String],
            0, NULL,
            port,
            ( port == 993 ) ? kSecProtocolTypeIMAPS : kSecProtocolTypeIMAP,
            kSecAuthenticationTypeDefault,
//            [_passwd length],
            (unsigned)[_passwd length],
            [_passwd UTF8String],
            NULL);
*/
        NSDictionary *query = @{(__bridge id)kSecClass : (__bridge id)kSecClassInternetPassword,
                                (__bridge id)kSecAttrServer : (__bridge id)_server,
                                (__bridge id)kSecAttrSecurityDomain : @"",
                                (__bridge id)kSecAttrAccount : (__bridge id)_username,
                                (__bridge id)kSecAttrPath : @"",
                                (__bridge id)kSecAttrPort : @(port),
                                (__bridge id)kSecAttrProtocol : (port == 993) ? @"imps" : @"imap",
                                (__bridge id)kSecAttrAuthenticationType : @"dflt",
                                (__bridge id)kSecValueData : (__bridge id)_passwd};

        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
        if (status != 0) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText: @"Keychain Add Failed!"];
            [alert setInformativeText:
                [NSString stringWithFormat: @"Adding keychain item for %@ failed!\n\n%@",
                 _username, SecCopyErrorMessageString(status, nil)]];
            [alert setAlertStyle: NSAlertStyleInformational];

            [alert runModal];
        }
    } else {
        /* Update Password */
        /*
         SecKeychainItemModifyAttributesAndData(
         ref,
         NULL,
         //            [_passwd length],
         (unsigned)[_passwd length],
         [_passwd UTF8String]);
         */
        NSDictionary *query = @{(__bridge id)kSecClass : (__bridge id)kSecClassInternetPassword,
                                (__bridge id)kSecAttrServer : (__bridge id)_server,
                                (__bridge id)kSecAttrSecurityDomain : @"",
                                (__bridge id)kSecAttrAccount : (__bridge id)_username,
                                (__bridge id)kSecAttrPath : @"",
                                (__bridge id)kSecAttrPort : @(port),
                                (__bridge id)kSecAttrProtocol : (port == 993) ? @"imps" : @"imap",
                                (__bridge id)kSecAttrAuthenticationType : @"dflt",
                                (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
                                (__bridge id)kSecReturnAttributes : @(true),
                                (__bridge id)kSecReturnData : @(true)};
        
        NSDictionary *attr = @{(__bridge id)kSecValueData : [(__bridge id)_passwd dataUsingEncoding:NSUTF8StringEncoding]};

        status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attr);
        if (status != 0) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText: @"Keychain Update Failed!"];
            [alert setInformativeText:
                [NSString stringWithFormat: @"Password Update for keychain item %@ failed!\n\n%@",
                 _username, SecCopyErrorMessageString(status, nil)]];
            [alert setAlertStyle: NSAlertStyleInformational];
            
            [alert runModal];
        }
    }

}


- (int) authenticate
{
	int status = 1;
	NSString *pw = [self getPW];
	NSArray *resp = nil;

	dprintf("Attempting to Auth\n");
	if ( pw == nil ) {
		return EAUTH;
	}

	[actWin performSelectorOnMainThread: @selector(doingActivity:)
				 withObject: @"Logging in..."
			      waitUntilDone: NO];
	resp = [_remote authenticate: _username password: pw];

	if ( [_remote isOK: resp] ) {
		dprintf("Authenticated \n");
		status = 0;
	} else {
//		NSAlert *alert = [NSAlert alertWithMessageText:
//			@"Login Failed!"
//			defaultButton: nil
//			alternateButton: nil
//			otherButton: nil
//			informativeTextWithFormat:
//				@"Login to %@ Failed!",
//				_name];
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: @"Login Failed!"];
        [alert setInformativeText:
            [NSString stringWithFormat: @"Login to %@ Failed!",
                _name]];
        [alert setAlertStyle: NSAlertStyleInformational];

        [alert runModal];
		status = EAUTH;
	}
	[actWin performSelectorOnMainThread: @selector(activityDone:)
				 withObject: [NSNumber numberWithDouble: 10]
			      waitUntilDone: NO];
	return status;
}


- (int) connect
{
	NSArray *response = nil;
	NSString *str = nil;
	NSRange range;

	[actWin performSelectorOnMainThread: @selector(doingActivity:)
				 withObject: @"Connecting..."
			      waitUntilDone: NO];
	_remote = [[imapd alloc] init];
	str = [_remote connectTo: _server via: _mode atPort: _port];
	if ( !str ) {
		return errno;
	}

	range = [str rangeOfString: @"IMAP4REV1"
		options: NSCaseInsensitiveSearch];

	/* Verify IMAP 4rev1 */
	if ( range.location == NSNotFound ) {
		/* Not IMAP4rev1 */
		response = [_remote query: @"CAPABILITY"];
		if ( !response || ![response count] ) {
			return errno;
		}
		str = [response objectAtIndex: 0];
		range = [str rangeOfString: @"IMAP4REV1"
			options: NSCaseInsensitiveSearch];
		if ( range.location == NSNotFound )
			return EPFNOSUPPORT;
	}

	range = [str rangeOfString: @"Pre-authenticated user"
		options: NSCaseInsensitiveSearch];
	if ( range.location != NSNotFound ) {
		dprintf("User Pre-authenticated\n");
		/* User pre-authenticated */
		return 0;
	}

	/* Authenticate */
	[actWin performSelectorOnMainThread: @selector(activityDone:)
				 withObject: [NSNumber numberWithDouble: 10]
			      waitUntilDone: NO];
	return [self authenticate];
}


- (void) disconnect
{
	if ( !_remote ) return;
	[actWin performSelectorOnMainThread: @selector(doingActivity:)
				 withObject: @"Logging Out"
			      waitUntilDone: NO];
	if ( [_remote connected] ) {
		[_remote disconnect];
	}
	[_remote release];
	_remote = Nil;
	[actWin performSelectorOnMainThread: @selector(activityDone:)
				 withObject: [NSNumber numberWithDouble: 1]
			      waitUntilDone: NO];
}


- (envelope*) fetchEnvelopeForUID: (unsigned) uid
{
	envelope *env = nil;
	NSArray *resp = nil;
	NSString *tstr;
	NSRange range1, range2;
	int tuid;

	resp = [_remote query: [NSString stringWithFormat:
		@"UID FETCH %u ENVELOPE", uid]];
	if ( ![_remote isOK: resp] ) {
		return nil;
	}

	if ( ( tstr = [_remote getLineWithContents: @"FETCH ("
		fromResponse: resp] ) == nil ) {
		alert("Unable to get FETCH line\n");
		return nil;
	}

	range1 = [tstr rangeOfString: @"ENVELOPE "];
	range2.location = range1.location + range1.length;
	range2.length = [tstr length] - range2.location;
	dprintf("Setting range to %d -> %d (length %d), and thus: '%s'\n",
			(int)range2.location, (int)(range2.location+range2.length),
			(int)[tstr length],
			[[tstr substringWithRange: range2] UTF8String]);

	env = [[envelope alloc] initWithIMAPEnvelope:
		[tstr substringWithRange: range2]
		andUID: uid];

	/* Verify the UID */
	range1 = [tstr rangeOfString: @"UID "];
	if ( range1.length == 0 ) {
		alert("UID not found... Noncompliant IMAP server suspect\n");
		alert("FETCH response: '%s'\n", [tstr UTF8String]);
	}
	range1.length = [tstr length] - range1.location;
	sscanf([[tstr substringWithRange: range1] UTF8String], "UID %u", &tuid);
	if ( tuid != (int)uid ) {
		alert("Received %d, rather than %u for a UID.\n", tuid, uid);
	}


	return [env autorelease];
}


- (int) updateBox: (mailbox*) box
{
	int status = 1;
	unsigned uid;
	int i;
	NSUInteger idx;
	bool doheaders = NO;
	NSString *tstr = Nil, *uidstr = nil;
	NSArray *statArray = Nil;
	envelope *penv;
	NSArray *resp = nil;
	NSArray *unreadUIDs = nil;
	NSArray *oldenvelopes = [NSArray arrayWithArray: [box envelopes]];
	NSRange range;

	if ( !box ) return 1;

	/* Select box */
	tstr = [NSString stringWithFormat: @"Checking Folder \"%@\"", [box fullname]];
	[actWin performSelectorOnMainThread: @selector(doingActivity:)
				 withObject: tstr
			      waitUntilDone: NO];
	resp = [_remote query: [NSString stringWithFormat:
			@"EXAMINE \"%@\"", [box fullname]]];
	if ( ![_remote isOK: resp] ) {
		alert("Unable to select box '%s'\n", [[box fullname] UTF8String]);
		[box setTotal: -1];
		[box setUnread: errno];
		goto out;
	}

	/* Gather Total */
	tstr = [_remote getLineWithContents: @"EXISTS" fromResponse: resp];
	if ( !tstr ) {
		alert("Did not find EXISTS for box '%s'\n",
				[[box fullname] UTF8String]);
		goto out;
	}
	statArray = [tstr componentsSeparatedByString: @" "];
	[box setTotal: [[statArray objectAtIndex: 1] intValue]];

	dprintf("I claim I (%p) have %d envelopes\n",
			(void*)[box envelopes], (int)[oldenvelopes count]);
#if defined(EBUG) && EBUG
	for ( i = 0 ; i < [[box envelopes] count] ; ++i ) {
		dprintf("Box %d has uid: %u\n", i, [[[box envelopes] objectAtIndex: i] uid]);
	}
#endif
	[[box envelopes] removeAllObjects];
	[box setNewMail: 0];

	/* Gather UIDs of unread messages */
	resp = [_remote query: @"UID SEARCH UNSEEN"];
	if ( ![_remote isOK: resp] ) {
		alert("Invalid search response\n");
		goto out;
	}
	/* Should be of form:
	 * * SEARCH 1 2 5 6 11
	 * XXXXX OK
	 */
	tstr = [_remote getLineWithContents: @"* SEARCH" fromResponse: resp];
	if ( !tstr ) {
		alert("Invalid search response\n");
		goto out;
	}
	range = [tstr rangeOfCharacterFromSet: [NSCharacterSet decimalDigitCharacterSet]];
	if ( range.location == NSNotFound ) {
		[box setUnread: 0];
	} else {
		uidstr = [tstr substringFromIndex: range.location];
		unreadUIDs = [uidstr componentsSeparatedByString: @" "];
		dprintf("Found %d unread UIDs : '%s'\n", (int)[unreadUIDs count],
				[uidstr UTF8String] );
//        [box setUnread: [unreadUIDs count]];
		[box setUnread: (int)[unreadUIDs count]];

		if ( [box unread] ) {
			for ( i = 0 ; i < [unreadUIDs count] ; ++i ) {
				dprintf("objectAtIndex: %d: '%s'\n", i,
					[[unreadUIDs objectAtIndex: i] UTF8String]);
				uid = [[unreadUIDs objectAtIndex: i] intValue];
				dprintf("Looking At UID %u\n", uid);
				[_tenv setUID: uid];

				idx = [oldenvelopes indexOfObject: _tenv];
				doheaders = [self doHeadersFor: box];
				if ( idx != NSNotFound ) {
					penv = [oldenvelopes objectAtIndex: idx];
				} else {
					penv = nil;
				}

				if ( !penv || (doheaders && ![penv initialized]) ) {
					[box addNewMail: 1];
					dprintf("Going to fetch Envelope for %u\n", uid);
					if ( doheaders ) {
						penv = [self fetchEnvelopeForUID: uid];
						if ( !penv ) {
							alert("Fetch Failed!\n");
							continue;
						}
					} else {
						penv = [envelope alloc];
						[penv setUID: uid];
					}
					dprintf("Putting %p into %p\n",
						penv, (void*)[box envelopes]);
					[[box envelopes] addObject: penv];
				} else {
					dprintf("Found in old envelopes\n");
					[[box envelopes] addObject:
						[oldenvelopes objectAtIndex: idx]];

				}
			}
		}
	}

	status = 0;
out:
	[actWin performSelectorOnMainThread: @selector(activityDone:)
				 withObject: [NSNumber numberWithDouble: (59.0*(1.0/_boxesTotal))]
			      waitUntilDone: NO];
	return status;
}


- (void) updateBoxes: (NSMutableArray*) boxlist
{
	unsigned i;
	mailbox *box;

	dprintf("In %s (%p)->[0..%d]\n", __FUNCTION__, boxlist, (int)[boxlist count] );
	for ( i = 0 ; i < [boxlist count] ; ++i ) {
		if ( user_pressed_stop ) {
			break;
		}
		box = [boxlist objectAtIndex: i];
		if ( [box isSelected] && ![box isDisabled] ) {
			dprintf("Updating '%s'\n", [[box fullname] UTF8String]);
			if ( [self updateBox: box] ) {
				[box setDisabled: YES];
				[box setSelected: NO];
			} else if ( [box newMail] && ![box isIgnored] ) {
				[_boxesWithNewMail addObject: [box name]];
				[self callOutsideProgramOn: box];
			}
		}
		[self updateBoxes: [box subBoxes]];
	}
}


- (NSMutableArray*) getboxlist
{
	/* Gather a list of boxes, and store them in the array.
	 * Also, find the seperator
	 */
	char *buf = NULL;
	char *flagptr = NULL;
	char cflags[256], psep[5];
	int i, j, offset;
	bool select;
	bool foundInbox = NO;
	NSArray *resp = nil;
	NSRange range;
	NSString *flags;
	NSString *name;
	NSMutableArray *boxlist = [[NSMutableArray alloc] initWithCapacity: 50];
	char listlsub[5];

	[actWin performSelectorOnMainThread: @selector(doingActivity:)
				 withObject: @"Getting Folder list"
			      waitUntilDone: NO];
	resp = [_remote query: [NSString stringWithFormat:
		@"%s \"%@\" \"*\"", (_subscribedOnly) ? "LSUB" : "LIST",
			_prefix]];
	if ( ![_remote isOK: resp] ) {
		alert("Bad response.\n");
		goto out;
	}

	for ( i = 0 ; i < [resp count]-1 ; ++i ) {

		bzero( cflags, 256 );
		buf = strdup([[resp objectAtIndex: i] UTF8String]);
		/* Hack to support MDaemon IMAP Server */
		flagptr = strchr(buf, '(');
		if ( *(flagptr+1) == ')' ) {
			dprintf("Using Null-flags line\n");
			j = sscanf(buf,
				"* %4s () \"%[^\"]\" %n",
				listlsub,
				psep, &offset);
			cflags[0] = '\0';
			j++;
		} else {
			j = sscanf(buf,
				"* %4s (%[^)]) \"%[^\"]\" %n",
				listlsub,
				cflags, psep, &offset);
		}
		if ( j == 3 ) {
			if ( _sep == Nil || _firstCheck) {
				if ( _sep ) [_sep release];
				_sep = [[NSString alloc] initWithCString: psep
//								length:1];
                                encoding:4];
				dprintf("Set _sep to '%s'\n", [_sep UTF8String]);
			}

			flags = [NSString stringWithCString: cflags encoding: 4];

			/* See if folder is selectable */
			range = [flags rangeOfString: @"NoSelect"
					options: NSCaseInsensitiveSearch];
			select = (range.location == NSNotFound);

			if ( select ) {
				/* Strip quotes and whitespace, if needed */
				if ( !sscanf( buf+offset, "\"%[^\"]\"", cflags ) ) {
					sscanf( buf+offset, "%s", cflags );
				}
				name = [NSString stringWithCString: cflags encoding: 4];
				[boxlist addObject: name];

				if ( !foundInbox && [name isEqualToString: @"INBOX"] ) {
					foundInbox = YES;
				}
			}
		} else {
			dprintf("j = %d, buf: '%s', psep: '%s'\n",
					j, buf, psep);
		}

		if ( buf ) {
			free(buf);
			buf = NULL;
		}
	}
	if ( !foundInbox ) {
//		[boxlist addObject: [NSString stringWithString: @"INBOX"]];
        [boxlist addObject: @"INBOX"];
	}

out:
	if ( _sep == Nil ) {
		dprintf("No separator found.  Defaulting to \'/\'\n");
		_sep = [[NSString alloc] initWithString: @"/"];
	}

	[actWin performSelectorOnMainThread: @selector(activityDone:)
				 withObject: [NSNumber numberWithDouble: 20]
			      waitUntilDone: NO];
	return [boxlist autorelease];
}



- (mailbox*) locateBox: (NSString*) fullname
		inBoxArray: (NSMutableArray*) boxes
		 withDepth: (int) depth
{
	NSArray *parts = [fullname componentsSeparatedByString: _sep];
	NSString *name = [parts objectAtIndex: depth];

	if ( [boxes containsObject: name] ) {
//        unsigned idx = [boxes indexOfObject: name];
		unsigned idx = (int)[boxes indexOfObject: name];
		if ( depth == [parts count]-1 ) {
			return [boxes objectAtIndex: idx];
		} else {
			return [self locateBox: fullname
				inBoxArray: [[boxes objectAtIndex: idx] subBoxes]
				withDepth: depth+1 ];
		}
	} else {
		return Nil;
	}
}



- (mailbox*) findBox: (NSArray*) path
		inBoxArray: (NSMutableArray*) boxes
		withDepth: (int) depth
{
	NSString *name = [path objectAtIndex: depth];
	dprintf("Looking for for folder '%s' (depth: %d) \n",
			[name UTF8String], depth);
#if defined(EBUG) && EBUG
	int i;
	for ( i = 0 ; i < [boxes count] ; ++i ) {
		dprintf(":::: '%s'\n", [[[boxes objectAtIndex: i] name] UTF8String] );
	}
#endif
    NSEnumerator *e = [boxes objectEnumerator];
    BOOL duplicate = NO;
    unsigned idx;
    id object;
    while (object = [e nextObject]) {
        if ( [[object name] isEqualToString: name] ) {
            duplicate = YES;
//            idx = [boxes indexOfObject: object];
            idx = (int)[boxes indexOfObject: object];
        } else {
        }
    }
	//if ( [boxes containsObject: name] ) {
    if ( duplicate ) {
		//unsigned idx = [boxes indexOfObject: name];
		if ( depth == [path count]-1 ) {
			dprintf("Found, and that's the deepest we go\n");
			/* Object found, and we are it */
			[[boxes objectAtIndex: idx] setSelected: YES];
			return [boxes objectAtIndex: idx];
		} else {
			dprintf("Found, but let's recurse\n");
			/* Object found, but we have more to go */
			return [self findBox: path
				inBoxArray: [[boxes objectAtIndex: idx] subBoxes]
				withDepth: depth+1];
		}
	} else {
		/* Never seen before */
		/* Create a fullname: (path up to depth) and shortname (obj @ depth) */
		NSRange range;
		range.location = 0;
		range.length = depth+1;
		NSString *full = [[path subarrayWithRange: range] componentsJoinedByString: _sep];
		mailbox *newbox = [[mailbox alloc] init: full
				andShortName: [path objectAtIndex: depth]];
		[boxes addObject: newbox];
		[boxes sortUsingFunction: compareMBnames context: NULL];

		if ( depth+1 == [path count] ) {
			dprintf("Not found, let's add it\n");
			/* At the end of the line */
			[newbox setSelected: YES];
			return newbox;
		} else {
			dprintf("Not found, recurse\n");
			/* Recurse */
			return [self findBox: path
				inBoxArray: [newbox subBoxes]
				withDepth: depth+1];
		}
	}

}


- (int) countEnabledBoxes: (NSArray*) boxlist
{
	int i;
	int sum = 0;
	for ( i = 0 ; i < [boxlist count] ; ++i ) {
		if ( ![[boxlist objectAtIndex: i] isDisabled] ) {
			sum++;
		}
		sum += [self countEnabledBoxes: [[boxlist objectAtIndex: i] subBoxes]];
	}
	return sum;
}


- (int) setupBoxes
{
	dprintf("In %s\n", __FUNCTION__);
	/* Build List */

	NSArray *boxlist = [self getboxlist];

	int i;
	dprintf("Found %u boxes\n", (unsigned)[boxlist count]);
	for ( i = 0 ; i < [boxlist count] ; ++i ) {
		dprintf("Trying to find box '%s'.\n", [[boxlist objectAtIndex: i] UTF8String]);
		[self findBox: [[boxlist objectAtIndex: i]
				componentsSeparatedByString: _sep]
			inBoxArray: _mailboxes
			withDepth: 0];
	}

	_boxesTotal = [self countEnabledBoxes: _mailboxes];

	if (_firstCheck) {
		NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
		[prefs setObject: _sep forKey:
			[NSString stringWithFormat: @"sep[%@]", _name]];
	}
	_firstCheck = NO;

	return 0;
}


- (int) pruneBoxes: (NSArray*) boxArray
{
	int i;
	NSArray *tarray;
	mailbox *tbox;
	int prune = 1;
	int subs = 0;
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	for ( i = 0 ; i < [boxArray count] ; ++i ) {
		tbox = [boxArray objectAtIndex: i];
		tarray = [tbox subBoxes];
		if ( [tarray count] ) {
			subs = [self pruneBoxes: tarray];
		} else {
			subs = 1;
		}

		if ( ![prefs boolForKey: @"Ignore Ignores"] ||
			![tbox isIgnored] ) {
			_messagesUnread += [tbox unread];
		}
		_messagesTotal += [tbox total];

		[tbox setPruned: (subs && ![tbox unread])];
		prune &= [tbox isPruned];
	}
	return prune;
}


- (void) appendBoxes: (NSArray*) boxArray toMenu: (NSMenu*) menu withDepth: (int) depth
{
	mailbox *tbox;
	NSMenuItem *menuItem;
	int i;

	if ( !boxArray || !menu ) return;

	for ( i = 0 ; i < [boxArray count] ; ++i ) {
		tbox = [boxArray objectAtIndex: i];

		if ( [tbox isPruned] ) continue;

		menuItem = [[NSMenuItem alloc] initWithTitle: [tbox descName]
				action: Nil keyEquivalent: @""];
		[menuItem setRepresentedObject: [tbox fullname]];
		[menuItem setIndentationLevel: depth];

		/* If there are unread, mark it as such */
		if ( [tbox unread] ) {
			[menuItem setTarget: self];
			[menuItem setAction: @selector(touched:)];

			if ( [self doHeadersFor: tbox] ) {
				[menuItem setSubmenu: [tbox headerMenu]];
			}

			/* Now, check for ignoring */
			if ( [tbox isIgnored] ) {
//                [menuItem setState: NSOffState];
				[menuItem setState: NSControlStateValueOff];
			} else {
//				  [menuItem setState: NSOnState];
                [menuItem setState: NSControlStateValueOn];
				_newMail |= [tbox newMail];
			}
			
			// provide access to message details 
			_newMailDetails = [tbox newMailDetails];
		}

		[menu addItem: [menuItem autorelease]];

		if ( [[tbox subBoxes] count] ) {
			[self appendBoxes: [tbox subBoxes]
				toMenu: menu
				withDepth: depth + 1];
		}

	}
}


- (void) addDisabledBoxes: (NSArray *)boxlist toArray: (NSMutableArray*) arr
{
	int i;
	mailbox *box;

	for ( i = 0 ; i < [boxlist count] ; ++i ) {
		box = [boxlist objectAtIndex: i];

		if ( [box isDisabled] ) {
			[arr addObject: [box fullname]];
		}

		[self addDisabledBoxes: [box subBoxes] toArray: arr];
	}
}


- (void) addIgnoredBoxes: (NSArray *)boxlist toArray: (NSMutableArray*) arr
{
	int i;
	mailbox *box;

	for ( i = 0 ; i < [boxlist count] ; ++i ) {
		box = [boxlist objectAtIndex: i];

		if ( [box isIgnored] ) {
			[arr addObject: [box fullname]];
		}

		[self addIgnoredBoxes: [box subBoxes] toArray: arr];
	}
}


/* Function Definitions */

- (id) init
{
	self = [super init];
	dprintf("In %s\n", __FUNCTION__ );
	_remote = nil;
	_name =     [[NSString alloc] initWithString: @""];
	_server =   [[NSString alloc] initWithString: @""];
	_username = [[NSString alloc] initWithString: @""];
	_passwd =   nil;
	_storedPW = NO;
	_prefix =   [[NSString alloc] initWithString: @""];
	_sep = [[NSString alloc] initWithString: @""];
//    _mode = NIL;
	_mode = REMOTESSL;
//    _port = 143;
	_port = 993;
	_subscribedOnly = NO;
	_mailboxes = [[NSMutableArray arrayWithCapacity: 50] retain];
	_boxesWithNewMail = [[NSMutableArray arrayWithCapacity: 5] retain];
	_enabled = YES;
	_tenv = [[envelope alloc] retain];
	_firstCheck = YES;
	_newMailDetails = [[NSString alloc] initWithString: @""];
	return (self);
}


- (id) initFromPrefs: (NSString*) name;
{
	dprintf("In %s\n", __FUNCTION__ );
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	int i;
	NSArray *boxes;
	NSString *tstr;


	self = [super init];

	_remote = nil;
	if ( ![prefs integerForKey: [NSString stringWithFormat:
			@"initServer[%@]", name]] ) {
//		NSAlert *alert = [NSAlert alertWithMessageText:
//				@"Unable to Load Server"
//			defaultButton: nil
//			alternateButton: nil
//			otherButton: nil
//			informativeTextWithFormat:
//				@"Unable to load server '%@' from "
//					"Preferences.", name];
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: @"Unable to Load Server"];
        [alert setInformativeText: 
            [NSString stringWithFormat: @"Unable to load server '%@' from "
                "Preferences", name]];
        [alert setAlertStyle: NSAlertStyleInformational];

		[alert runModal];
		return [self init];
	}

	_name = [[NSString alloc] initWithString: name];
	_server = [[NSString alloc] initWithString:
		[prefs stringForKey:
			[NSString stringWithFormat: @"server[%@]", name]]];
	_username = [[NSString alloc] initWithString:
		[prefs stringForKey:
			[NSString stringWithFormat: @"username[%@]", name]]];
	_storedPW = [prefs boolForKey:
		[NSString stringWithFormat: @"storedPW[%@]", name]];
	_prefix = [[NSString alloc] initWithString:
		[prefs stringForKey:
			[NSString stringWithFormat: @"prefix[%@]", name]]];
//    _mode = [prefs integerForKey:
	_mode = (cmode_t)[prefs integerForKey:
			[NSString stringWithFormat: @"mode[%@]", name]];

	tstr = [prefs stringForKey:
	       		[NSString stringWithFormat: @"sep[%@]", name]];
	if ( tstr ) {
		_sep = [[NSString alloc] initWithString: tstr];
	} else {
		_sep = [[NSString alloc] initWithString: @"/"];
	}

	_enabled = [prefs boolForKey:
			[NSString stringWithFormat: @"enabled[%@]", name]];

	_subscribedOnly = [prefs boolForKey:
			[NSString stringWithFormat: @"subscribed[%@]", name]];
//    _port = [prefs integerForKey:
	_port = (int)[prefs integerForKey:
			[NSString stringWithFormat: @"port[%@]", name]];
	_passwd = Nil;

	if ( !_port ) {
		_port = (_mode == REMOTE) ? 143 : 993;
	}

	_mailboxes = [[NSMutableArray arrayWithCapacity: 50] retain];
	_boxesWithNewMail = [[NSMutableArray arrayWithCapacity: 5] retain];

	_tenv = [[envelope alloc] retain];

	_firstCheck = YES;

	boxes = [prefs stringArrayForKey:
			[NSString stringWithFormat: @"ignoredBoxes[%@]", name]];
	if ( _sep && boxes && [boxes count] ) {
		for ( i = 0 ; i < [boxes count] ; ++i ) {
			mailbox *box = [self findBox: [[boxes objectAtIndex: i]
						componentsSeparatedByString: _sep]
					inBoxArray: _mailboxes
					withDepth: 0];
			[box setIgnored: YES];
			[box setSelected: NO];
		}
	}

	boxes = [prefs stringArrayForKey:
			[NSString stringWithFormat: @"disabledBoxes[%@]", name]];
	if ( _sep && boxes && [boxes count] ) {
		for ( i = 0 ; i < [boxes count] ; ++i ) {
			mailbox *box = [self findBox: [[boxes objectAtIndex: i]
						componentsSeparatedByString: _sep]
					inBoxArray: _mailboxes
					withDepth: 0];
			[box setDisabled: YES];
			[box setSelected: NO];
		}
	}



	return (self);
}


- (void) dealloc
{
	dprintf("In dealloc\n");
	if ( _remote != Nil ) [_remote release];
	if ( _name != Nil ) [_name release];
	if ( _server != Nil ) [_server release];
	if ( _username != Nil ) [_username release];
	if ( _passwd != Nil ) [_passwd release];
	if ( _prefix != Nil ) [_prefix release];
	if ( _sep != Nil ) [_sep release];
	if (_newMailDetails != Nil) [_newMailDetails release];
	if ( _mailboxes != Nil ) {
		[_mailboxes removeAllObjects];
		[_mailboxes release];
	}
	if ( _boxesWithNewMail != Nil ) {
		[_boxesWithNewMail removeAllObjects];
		[_boxesWithNewMail release];
	}
	if ( _tenv != Nil ) [_tenv release];

	[super dealloc];
}

/*
 * Public Methods
 */
- (void) setName: (NSString*) name;
{
	if ( _name != Nil )
		[_name release];

	_name = [[NSString alloc] initWithString: name];
}


- (NSString*) name
{
	return _name;
}


- (void) setServer: (NSString*) server;
{
	if ( _server != Nil )
		[_server release];

	_server = [[NSString alloc] initWithString: server];
}


- (NSString*) server
{
	return _server;
}


- (void) setUsername: (NSString*) username;
{
	if ( _username != Nil )
		[_username release];

	_username = [[NSString alloc] initWithString: username];
}


- (NSString*) username
{
	return _username;
}


- (void) setPrefix: (NSString*) prefix
{
	if ( _prefix != Nil )
		[_prefix release];

	_prefix = [[NSString alloc] initWithString: prefix];
}


- (NSString*) prefix
{
	return _prefix;
}


- (void) setPassword: (NSString*) passwd andKeep: (bool) keep
{
	if ( _passwd != Nil )
		[_passwd release];

	_passwd = [[NSString alloc] initWithString: passwd];
	_storedPW = keep;

	if ( keep ) {
		[self storePW];
	}

}


- (void) setMode: (cmode_t) mode
{
	_mode = mode;
}


- (cmode_t) mode
{
	return _mode;
}


- (NSArray*) mailboxes;
{
	return _mailboxes;
}


- (bool) savesPW
{
	return _storedPW;
}


- (void) setEnabled: (bool) enable
{
	_enabled = enable;
}


- (bool) enabled
{
	return _enabled;
}


- (void) setPort: (int) port
{
	_port = port;
	if ( !_port ) {
		_port = (_mode == REMOTE) ? 143 : 993;
	}
}


- (int) port
{
	return _port;
}

- (void) setSubOnly: (bool) sub
{
	_subscribedOnly = sub;
}


- (bool) subOnly
{
	return _subscribedOnly;
}


- (unsigned) messagesTotal
{
	return _messagesTotal;
}


- (unsigned) messagesUnread
{
	return _messagesUnread;
}


- (bool) newMail
{
	return _newMail;
}


- (NSArray*) newMailFolders
{
	return _boxesWithNewMail;
}

- (NSString*) newMailDetails
{
	return _newMailDetails;
}


- (void) storePrefs
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSMutableArray *igarr = [NSMutableArray arrayWithCapacity: 50];

	[prefs setInteger: 1 forKey:
		[NSString stringWithFormat: @"initServer[%@]", _name]];
	[prefs setObject: _server forKey:
		[NSString stringWithFormat: @"server[%@]", _name]];
	[prefs setObject: _username forKey:
		[NSString stringWithFormat: @"username[%@]", _name]];
	[prefs setBool: _storedPW forKey:
		[NSString stringWithFormat: @"storedPW[%@]", _name]];
	[prefs setObject: _prefix forKey:
		[NSString stringWithFormat: @"prefix[%@]", _name]];
	[prefs setInteger: _mode forKey:
		[NSString stringWithFormat: @"mode[%@]", _name]];
	[prefs setObject: _sep forKey:
		[NSString stringWithFormat: @"sep[%@]", _name]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"ignoredBoxes[%@]", _name]];
	[self addIgnoredBoxes: _mailboxes toArray: igarr];
	[prefs setObject: igarr forKey:
		[NSString stringWithFormat: @"ignoredBoxes[%@]", _name]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"disabledBoxes[%@]", _name]];
	[igarr removeAllObjects];
	[self addDisabledBoxes: _mailboxes toArray: igarr];
	[prefs setObject: igarr forKey:
		[NSString stringWithFormat: @"disabledBoxes[%@]", _name]];
	[prefs setBool: _enabled forKey:
		[NSString stringWithFormat: @"enabled[%@]", _name]];
	[prefs setBool: _subscribedOnly forKey:
		[NSString stringWithFormat: @"subscribed[%@]", _name]];
	[prefs setInteger: _port forKey:
		[NSString stringWithFormat: @"port[%@]", _name]];

}


- (int) checkMail
{
	int res;

	if ( ![self isconfigured] )
		return 1;

	if ( ( res = [self connect] ) != 0 ) {
		[self disconnect];
		return res;
	}

	[_boxesWithNewMail removeAllObjects];
	if ( ![self setupBoxes] )
		[self updateBoxes: _mailboxes];

	[self disconnect];

	return 0;
}


- (void) addToMenu: (NSMenu*) menu
{
	_newMail = NO;
	_messagesTotal = _messagesUnread = 0;
	[self pruneBoxes: _mailboxes]; /* Sets totals */

	/* Sets _newMail */
	[self appendBoxes: _mailboxes toMenu: menu withDepth: 1];
}


- (IBAction) touched: (id) sender
{
	NSMenuItem *menuItem = (NSMenuItem*)sender;
	NSString *boxname = [menuItem representedObject];
	mailbox *box;

	box = [self locateBox: boxname
			inBoxArray: _mailboxes
			withDepth: 0];

//	if ( [menuItem state] == NSOnState ) {
    if ( [menuItem state] == NSControlStateValueOn ) {
		[box setIgnored: YES];
//        [menuItem setState: NSOffState];
		[menuItem setState: NSControlStateValueOff];
	} else {
		[box setIgnored: NO];
//		[menuItem setState: NSOnState];
        [menuItem setState: NSControlStateValueOn];
	}

	[[menuItem menu] itemChanged: menuItem];

	[self storePrefs];
}

@end

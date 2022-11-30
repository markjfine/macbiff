/*
 * $Id: MacBiff.m 181 2012-02-12 18:39:45Z lhagan $
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

#ifdef USE_GROWL
#undef USE_GROWL
#endif

#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/types.h>
#ifdef USE_GROWL
#include "Growl.framework/Headers/GrowlApplicationBridge.h"
#endif

#import "MacBiff.h"
#if 0
#define EBUG 1
#endif
#include "activity.h"
#include "debug.h"
#include "imap.h"
#include "comms.h"
#include "version.h"

volatile sig_atomic_t user_pressed_stop = 0;

static MacBiff * macBiff;

#ifdef USE_GROWL
static NSString *appName = @"MacBiff";
static NSString *newMailNotificationName = @"New Mail";

//these are keys into the Localizable.strings. there are two to handle plurals.
static NSString *growlDescriptionFormats[] = {
	@"Growl notification description (one message)",
	@"Growl notification description (multiple messages, one folder)",
	@"Growl notification description (multiple messages, multiple folders)",
};
#endif

static void sigUSR1( int sig )
{
	/* this trick allows a another process (say, fetchmail) that has no
	 * connection to the window server to tell macBiff to check the mail
	 * status "now". With that you can even set the email check delay to
	 * several hours, since it's the mail fetching process that schedule
	 * the checking.
	 */
	if (macBiff) {
		[macBiff performSelectorOnMainThread:@selector(refresh:)
			withObject: macBiff
			waitUntilDone: NO];
	}
}

static void sigUSR2( int sig )
{
	dprintf("Received SIGUSR2\n");
	alert("Stopping Check.   Received SIGUSR2\n");
	user_pressed_stop = 1;
}


@implementation MacBiff

- (IBAction) checknow: (id) sender
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	CheckNow = ![actWin isOpen];
	if ( [prefs boolForKey: @"Show Activity"] ) {
		[actWin performSelectorOnMainThread: @selector(display:)
					 withObject: self
				      waitUntilDone: YES];
	}

	[self refresh: self];
}


- (IBAction) stopcheck: (id) sender
{
	dprintf("User pressed STOP\n");
	if ( checking_thread ) {
		pthread_kill( checking_thread, SIGUSR2 );
	} else {
		kill( getpid(), SIGUSR2 );
	}
}


- (id) init
{
	if ( self = [super init] ) {
		goRed = NO;
		CheckNow = NO;
		mainMenu = Nil;
		checkStatus = Nil;
		lock = [[NSLock alloc] init];
		timer = Nil;
		servers = [[NSMutableArray alloc] initWithCapacity:5];
		ICcurServer = -1;

		macBiff = self;

		struct sigaction usr1act, usr2act;

		memset(&usr1act, 0, sizeof(struct sigaction));
		memset(&usr2act, 0, sizeof(struct sigaction));

		sigemptyset(&(usr1act.sa_mask));
		sigemptyset(&(usr2act.sa_mask));

		usr1act.sa_handler = sigUSR1;
		usr1act.sa_flags = SA_RESTART;
		sigaction(SIGUSR1, &usr1act, NULL);

		usr2act.sa_handler = sigUSR2;
		sigaction(SIGUSR2, &usr2act, NULL);


#ifdef USE_GROWL
		NSImage *myIcon = [NSImage imageNamed:appName];
		iconData = [[myIcon TIFFRepresentation] retain];
		notificationNames = [[NSArray alloc] initWithObjects:
			newMailNotificationName, nil];

		// commented out old Growl notification code lh 2009-01-12
		//
		/*//register with Growl.
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			appName, GROWL_APP_NAME,
			iconData, GROWL_APP_ICON,
			notificationNames, GROWL_NOTIFICATIONS_DEFAULT,
			notificationNames, GROWL_NOTIFICATIONS_ALL,
			nil];
		[[NSDistributedNotificationCenter defaultCenter]
			postNotificationName:GROWL_APP_REGISTRATION
			object:nil
			userInfo:userInfo];*/
		[GrowlApplicationBridge setGrowlDelegate:self];
#endif
	}

	return (self);
}


- (void) dealloc
{
	[mainMenu release];
	mainMenu = nil;

	[systemBar release];
	systemBar = nil;

	[lock unlock];
	[lock release];
	lock = nil;

	[timer invalidate];
	[timer release];
	timer = nil;

	[servers removeAllObjects];
	[servers release];
	servers = nil;

	[iconData release];
	[notificationNames release];

	[super dealloc];
}


- (void) awakeFromNib
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	[CserverTbl setTarget: self];
	[CserverTbl setDoubleAction: @selector(editServer:)];

	if ( ![prefs integerForKey: @"Server Count"] ) {
		[self registerDefaultPreferences];
		[self openPrefs: self];
	} else {
		[self loadServers];
		[self setupMenuBar];

		if ( [prefs integerForKey: @"checkDelay"] >= 1 ) {
			timer = [NSTimer scheduledTimerWithTimeInterval:
				60 * [prefs integerForKey: @"checkDelay"]
				target: self
				selector: @selector (refresh:)
				userInfo: self
				repeats: YES];
			/* Check Now */
			[timer fire];
		}
	}
}


- (void)applicationDidFinishLaunching
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	[[workspace notificationCenter] addObserver: self
		selector: @selector(wakeUp:)
		name: NSWorkspaceDidWakeNotification
		object: workspace];
}


/*
 * About Box Control
 */

- (IBAction)openAbout:(id)sender
{
	[MacBiffVersion setStringValue:
		[NSString stringWithFormat: @"MacBiff version %s",
		VERSION]];

	[aboutWindow makeKeyAndOrderFront: self];
	[NSApp activateIgnoringOtherApps: YES];

}


- (IBAction)canelAbout:(id)sender
{
	[aboutWindow close];
}


- (IBAction)openURL:(id)sender
{
	[[NSWorkspace sharedWorkspace]
		openURL: [NSURL URLWithString:
			@"http://www.forkit.org/macbiff/macbiff.php"]];
}


/*
 * Preferences Control
 */

- (NSArray*) getSounds
{
	NSSet *aiffSet = [NSSet setWithObject: @"aiff"];
	NSMutableArray *soundNames = [[NSMutableArray alloc]
			initWithCapacity: 15];
	/* Generate listing of all library directories */
	NSArray *tarray = NSSearchPathForDirectoriesInDomains(
			NSLibraryDirectory,
			NSAllDomainsMask,
			YES );
	NSEnumerator *libEnum = [tarray objectEnumerator];
	NSString *libPath;
	NSDirectoryEnumerator *dirEnum;
	NSString *fp;
	NSString *sp;

	while ( (libPath = [libEnum nextObject]) ) {
		/* Append 'Sounds' to the library path */
		sp = [libPath stringByAppendingFormat: @"/%@", @"Sounds"];
		dirEnum = [[NSFileManager defaultManager]
				enumeratorAtPath: sp];
		while ( (fp = [dirEnum nextObject]) ) {
			if ( [aiffSet containsObject: [fp pathExtension]] ) {
				[soundNames addObject:
					[[[sp stringByAppendingFormat: @"/%@", fp]
						stringByDeletingPathExtension]
							lastPathComponent]];
			}
		}

	}
	return (soundNames);
}


- (IBAction)openPrefs:(id)sender
{
	NSArray *sounds;
	int i;
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	int delay = [prefs integerForKey: @"checkDelay"];
	if ( delay > 0 ) {
		[CdelayText setIntValue: delay];
		[CdelayStep setIntValue: delay];
	} else {
		[CdelayText setIntValue: 1];
		[CdelayStep setIntValue: 1];
	}
	[CcountIgnores setState:
		([prefs boolForKey: @"Ignore Ignores"]) ?
			NSControlStateValueOff : NSControlStateValueOn];
	[CcheckHeaders setState:
		([prefs boolForKey: @"Fetch Unread Headers"]) ?
			NSControlStateValueOn : NSControlStateValueOff];
	[CcheckIgnHeaders setState:
		([prefs boolForKey: @"Fetch Ignored Headers"]) ?
			NSControlStateValueOn : NSControlStateValueOff];
	[CchColorBut setState:
		([prefs boolForKey: @"Alert Color"]) ?
			NSControlStateValueOn : NSControlStateValueOff];
	[CdoSoundBut setState:
		([prefs boolForKey: @"Alert Sound"]) ?
			NSControlStateValueOn : NSControlStateValueOff];
	[CuseGrowl setState:
		([prefs boolForKey: @"Notify with Growl"]) ?
			   NSControlStateValueOn : NSControlStateValueOff];
#ifndef USE_GROWL
	//this version of MacBiff was not compiled with Growl support.
	//disable the checkbox to toggle Growl notifications, and set the tool-tip
	//  to inform the user of the binary's lack of the Growl nature.
	[CuseGrowl setEnabled: NO];
	[CuseGrowl setToolTip: @"This version of MacBiff does not support Growl."];
#endif
	[CshowText setState:
		(![prefs boolForKey: @"Hide Text"]) ?
			NSControlStateValueOn : NSControlStateValueOff];
	[CshowTotBut setState:
		(![prefs boolForKey: @"Hide Total"]) ?
			NSControlStateValueOn : NSControlStateValueOff];
	[CshowBrackets setState:
		(![prefs boolForKey: @"Hide Brackets"]) ?
			   NSControlStateValueOn : NSControlStateValueOff];
	[CshowIcon setState:
		([prefs boolForKey: @"Show Icon"]) ?
			NSControlStateValueOn : NSControlStateValueOff];
	[CchColorBut setEnabled: ([CshowText state] == NSControlStateValueOn) ];
	[CshowTotBut setEnabled: ([CshowText state] == NSControlStateValueOn) ];
	[CshowBrackets setEnabled: ([CshowText state] == NSControlStateValueOn) ];
	[CsoundChoicePop setEnabled: ([CdoSoundBut state] == NSControlStateValueOn) ];
	[CcheckIgnHeaders setEnabled: ([CcheckHeaders state] == NSControlStateValueOn) ];
	[CshowActivity setState:
	       ([prefs boolForKey: @"Show Activity"]) ?
			NSControlStateValueOn : NSControlStateValueOff];
	/* Look at sound */
	[CsoundChoicePop removeAllItems];
	[CsoundChoicePop addItemWithTitle: @"System Beep"];
	sounds = [self getSounds];
	for ( i = 0 ; i < [sounds count] ; ++i ) {
		[CsoundChoicePop addItemWithTitle: [sounds objectAtIndex: i]];
	}
	[sounds release];

	[CsoundChoicePop selectItemWithTitle:
		[prefs stringForKey: @"Sound Name"]];

	/* Set up the Server Table */
	[CserverDS replaceServers: servers];
	[CserverTbl reloadData];

	[CmailAppText setStringValue: [prefs stringForKey: @"Mail App"]];
	if ([prefs stringForKey: @"New Unread Mail Command"])
		[CunreadMailCommand setStringValue:
			[prefs stringForKey: @"New Unread Mail Command"]];

	[prefsWindow makeKeyAndOrderFront: self];
	[NSApp activateIgnoringOtherApps: YES];

}


- (IBAction)savePrefs:(id)sender
{
	int i;
	NSMutableArray *serverNames = [NSMutableArray arrayWithCapacity: 5];

	[prefsWindow close];
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	dprintf("In %s\n", __FUNCTION__);

	[prefs setInteger: [servers count] forKey: @"Server Count"];
	
	// make sure delay is not zero or negative
	int delay = 1;
	if ([CdelayText intValue] >= 1) {
		delay = [CdelayText intValue];
	}
	[prefs setInteger: delay forKey: @"checkDelay"];
	
	[prefs setBool: ( [CcountIgnores state] == NSControlStateValueOff )
		forKey: @"Ignore Ignores"];
	[prefs setBool: ( [CcheckHeaders state] == NSControlStateValueOn )
		forKey: @"Fetch Unread Headers"];
	[prefs setBool: ( [CcheckIgnHeaders state] == NSControlStateValueOn )
		forKey: @"Fetch Ignored Headers"];
	[prefs setBool: ( [CshowBrackets state] != NSControlStateValueOn )
			forKey: @"Hide Brackets"];
	[prefs setBool: ( [CshowIcon state] == NSControlStateValueOn )
		forKey: @"Show Icon"];
	[prefs setBool: ( [CshowText state] != NSControlStateValueOn )
		forKey: @"Hide Text"];
	[prefs setBool: ( [CshowTotBut state] != NSControlStateValueOn )
		forKey: @"Hide Total"];
	[prefs setBool: ( [CchColorBut state] == NSControlStateValueOn )
		forKey: @"Alert Color"];
	[prefs setBool: ( [CdoSoundBut state] == NSControlStateValueOn )
		forKey: @"Alert Sound"];
	[prefs setBool: ([CuseGrowl state] == NSControlStateValueOn)
		forKey: @"Notify with Growl"];
	[prefs setObject: [CsoundChoicePop titleOfSelectedItem]
		forKey: @"Sound Name"];
	[prefs setBool: ( [CshowActivity state] == NSControlStateValueOn )
		forKey: @"Show Activity"];
	[prefs setObject: [CmailAppText stringValue] forKey: @"Mail App"];
	[prefs setObject: [CunreadMailCommand stringValue]
		  forKey: @"New Unread Mail Command"];

	for ( i = 0 ; i < [servers count] ; ++i ) {
		[[servers objectAtIndex: i] storePrefs];
		[serverNames addObject: [[servers objectAtIndex: i] name]];
	}

	[prefs removeObjectForKey: @"Server Names"];
	[prefs setObject: serverNames forKey: @"Server Names"];

	dprintf("Doing syncronize\n");
	if ( ![prefs synchronize] ) {
		fprintf(stderr, "Unable to syncronize\n");
	}

	if ( timer ) {
		[timer invalidate];
	}
	if ( [CdelayText intValue] >= 1 ) {
		timer = [NSTimer scheduledTimerWithTimeInterval:
				60 * [CdelayText intValue]
				target: self
				selector: @selector (refresh:)
				userInfo: self
				repeats: YES];
	}

	[self refresh: self];

	dprintf("Leaving %s\n", __FUNCTION__);

}


- (IBAction)cancelPrefs:(id)sender
{
	[prefsWindow close];
}


- (IBAction) editServer: (id) sender
{
	if ( ICcurServer != -1 ) return;

	if ( sender == CeditBut || sender == CserverTbl ) {
		ICcurServer = [CserverTbl selectedRow];
	} else {
		ICcurServer = [sender tag];
	}
	ICadding = NO;

	[self Iconfigure];
}


- (IBAction) addServer: (id) sender
{
	imap *server = [[imap alloc] init];
	dprintf("Server Count:  %d\n", [servers count]);
	[servers addObject: server];
	ICcurServer = [servers count]-1;
	ICadding = YES;
	dprintf("Server Count:  %d\n", [servers count]);

	[self Iconfigure];
}



- (IBAction) delServer: (id) sender
{
	int result;

	if ( ICcurServer != -1 ) return;
	if ( [CserverTbl selectedRow] < 0 ) return;

    NSAlert *alert = [NSAlert alertWithMessageText:
			@"Are you sure?"
			defaultButton: @"Nope"
			alternateButton: @"Yep"
			otherButton: nil
			informativeTextWithFormat:
				@"Are you sure you wish to remove server %@?",
				[[servers objectAtIndex:
					[CserverTbl selectedRow]] name]];
	result = [alert runModal];

	if ( result ) {
		return;
	} else {
		/* Need to remove */
		[self IremoveServer: [CserverTbl selectedRow]];
		[CserverDS replaceServers: servers];
		[CserverTbl reloadData];
	}
}


- (IBAction) stepDelay: (id) sender
{
	[CdelayText setIntValue: [CdelayStep intValue]];
}


- (IBAction) editDelay: (id) sender
{
	if ([CdelayText intValue] <= 0) {
		[CdelayText setIntValue: 1];
	}
	[CdelayStep setIntValue: [CdelayText intValue]];
}


- (IBAction) selectText: (id) sender
{
    [CchColorBut setEnabled: ([CshowText state] == NSControlStateValueOn) ];
    [CshowTotBut setEnabled: ([CshowText state] == NSControlStateValueOn) ];
    [CshowBrackets setEnabled: ([CshowText state] == NSControlStateValueOn) ];
}


- (IBAction) selectSound: (id) sender
{
    [CsoundChoicePop setEnabled: ([CdoSoundBut state] == NSControlStateValueOn) ];
}


- (IBAction) selectUseGrowl: (id) sender
{
	//nothing to do here.
}


- (IBAction) soundChange: (id) sender
{
	if ( [CsoundChoicePop indexOfSelectedItem] == 0 ) {
		//System Beep
		NSBeep();
	} else {
		NSSound *snd = [NSSound soundNamed:
			[CsoundChoicePop titleOfSelectedItem]];
		[snd play];
	}
	[CsoundChoicePop synchronizeTitleAndSelectedItem];
}


- (IBAction) selectFetch: (id) sender
{
    [CcheckIgnHeaders setEnabled: ([CcheckHeaders state] == NSControlStateValueOn) ];
}


- (IBAction) chooseApp: (id) sender
{
	int res;
	NSArray *ft = [NSArray arrayWithObject: @"app"];
	NSOpenPanel *op = [NSOpenPanel openPanel];

	[op setAllowsMultipleSelection: NO];

	res = [op runModalForDirectory: nil
		file: [CmailAppText stringValue]
		types: ft];

    if ( res == NSModalResponseOK ) {
		NSArray *files = [op URLs];
		[CmailAppText setStringValue: [files objectAtIndex: 0]];
	}
}


- (IBAction) launchMail: (id) sender
{

	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	[[NSWorkspace sharedWorkspace] launchApplication:
		[prefs stringForKey: @"Mail App"]];
}


- (IBAction)openGrowlURL:(id)sender;
{
	[[NSWorkspace sharedWorkspace]
		openURL: [NSURL URLWithString:
			NSLocalizedString(@"Growl URL", /*comment*/ nil)]];
}


- (void) registerDefaultPreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	/*
	 Register the default sources in prefs storage.
	 */
	[prefs setInteger: 0 forKey: @"Server Count"];
	[prefs setInteger: 5 forKey: @"checkDelay"];
	[prefs setBool: NO  forKey: @"Ignore Ignores"];
	[prefs setBool: NO  forKey: @"Fetch Unread Headers"];
	[prefs setBool: NO  forKey: @"Fetch Ignored Headers"];
	[prefs setBool: YES forKey: @"Alert Color"];
	[prefs setBool: NO forKey: @"Alert Sound"];
	[prefs setBool: YES  forKey: @"Hide Text"];
	[prefs setBool: NO  forKey: @"Hide Total"];
	[prefs setBool: YES  forKey: @"Hide Brackets"];
	[prefs setBool: YES  forKey: @"Show Icon"];
	[prefs setBool: YES  forKey: @"Notify with Growl"];
	[prefs setObject: @"System Beep" forKey: @"Sound Name"];
	[prefs setObject: @"Mail" forKey: @"Mail App"];
	[prefs setObject: @"" forKey: @"New Unread Mail Command"];
}


- (void) loadServers
{
	int numServers;
	int i;
	NSArray* serverNames;
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	numServers = [prefs integerForKey: @"Server Count"];
	serverNames = [prefs stringArrayForKey: @"Server Names"];
	if ( numServers != [serverNames count] ) {
		alert("Recorded Servers (%d) != Server Count (%d)\n",
				numServers, [serverNames count]);
	}
	for ( i = 0 ; i < [serverNames count] ; ++i ) {
		dprintf("Building Server '%s'\n",
			[[serverNames objectAtIndex: i] UTF8String] );
		[servers addObject: [[imap alloc]
			initFromPrefs: [serverNames objectAtIndex: i]]];
	}
}


/*
 * IMAP Config
 */

- (void) updateIgnores: (NSMutableArray*) igbox fromBoxes: (NSArray*) boxes
{
	int i;
	mailbox *box;
	for ( i = 0 ; i < [boxes count] ; ++i ) {
		box = [boxes objectAtIndex: i];
		if ( [box isIgnored] ) {
			[igbox addObject: [box fullname]];
		}
		if ( [[box subBoxes] count] ) {
			[self updateIgnores: igbox fromBoxes: [box subBoxes]];
		}
	}
}


- (void) Iconfigure
{
	if ( ICcurServer == -1 )
		return;

	imap *server = [servers objectAtIndex: ICcurServer];

	[ICName setStringValue: [server name]];
	[ICServer setStringValue: [server server]];
	[ICUsername setStringValue: [server username]];
	[ICPasswd setStringValue: @""];
	[ICPrefix setStringValue: [server prefix]];
    [ICuseSSL setState: ([server mode] == REMOTE) ? NSControlStateValueOff : NSControlStateValueOn];
    [ICKeepPW setState: [server savesPW] ? NSControlStateValueOn : NSControlStateValueOff ];
    [ICenable setState: [server enabled] ? NSControlStateValueOn : NSControlStateValueOff ];
	[ICPort setIntValue: [server port]];
    [ICsubscribed setState: ([server subOnly]) ? NSControlStateValueOn : NSControlStateValueOff];

	[ICignoreDS setServer: server];

	[ICconfigWindow makeKeyAndOrderFront: self];
	[NSApp activateIgnoringOtherApps: YES];
}


- (void) IremoveServer: (int) num
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	imap *server = [servers objectAtIndex: num];
	NSString *sname = [server name];

	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"initServer[%@]", sname]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"server[%@]", sname]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"username[%@]", sname]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"prefix[%@]", sname]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"mode[%@]", sname]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"storedPW[%@]", sname]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"server[%@]", sname]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"ignoredBoxes[%@]", sname]];
	[prefs removeObjectForKey:
		[NSString stringWithFormat: @"enabled[%@]", sname]];

	[servers removeObjectAtIndex: num];
}


- (IBAction) IcancelConfig: (id) sender
{
	[ICconfigWindow close];
	if ( ICadding ) {
		[servers removeObjectAtIndex: ICcurServer];
	}
	ICcurServer = -1;
}


- (IBAction) IsaveConfig: (id) sender
{
	if ( ICcurServer == -1 ) return;

	imap *server = [servers objectAtIndex: ICcurServer];

	if ( ![[server name] isEqualToString: @""] &&
			![[server name] isEqualToString:
				[ICName stringValue]] ) {
		/* remove old server from preferences */
		[self IremoveServer: ICcurServer];
	}
	[server setName: [ICName stringValue]];
	[server setServer: [ICServer stringValue]];
	[server setUsername: [ICUsername stringValue]];
	[server setPrefix: [ICPrefix stringValue]];
	if ( [[ICPasswd stringValue] length] ) {
		[server setPassword: [ICPasswd stringValue] andKeep:
            ([ICKeepPW state] == NSControlStateValueOn) ];
	}
    [server setMode: ([ICuseSSL state] == NSControlStateValueOn) ? REMOTESSL : REMOTE];
    [server setEnabled: ([ICenable state] == NSControlStateValueOn)];
	[server setPort: [ICPort intValue]];
    [server setSubOnly: ([ICsubscribed state] == NSControlStateValueOn)];

	[server storePrefs];

	[CserverDS replaceServers: servers];
	[CserverTbl reloadData];

	[ICconfigWindow close];
	ICcurServer = -1;
}


- (IBAction) IchangeMode: (id) sender
{
    [ICPort setIntValue: (([ICuseSSL state] == NSControlStateValueOn) ?
		       993 : 143)];
}


/*
 * Ask Password
 */

- (void) askPassForServer: (int) num
{
	if ( ICcurServer != -1 ) return;

	[PWpasswd setStringValue: @""];
	[PWtext setStringValue: [[servers objectAtIndex: num] name]];
    [PWkeepPW setState: NSControlStateValueOff];

	ICcurServer = num;

	[PWpassWindow makeKeyAndOrderFront: self];
	[NSApp activateIgnoringOtherApps: YES];
}


- (IBAction) PWcancel: (id) sender
{
	[PWpassWindow close];
	ICcurServer = -1;
}


- (IBAction) PWOK: (id) sender
{
	[PWpasswd validateEditing];
	[PWpassWindow close];
	[[servers objectAtIndex: ICcurServer] setPassword:
			[PWpasswd stringValue] andKeep:
            ( [PWkeepPW state] == NSControlStateValueOn ) ];
	ICcurServer = -1;
	[self refresh: self];
}


/*
 * Menu Control
 */

- (void) setupMenuBar
{
	NSMenu *tmenu = NULL;
	/*Create the IMAP status item.*/
	systemBar = [[NSStatusBar systemStatusBar]
		statusItemWithLength: 65.0];
	[systemBar retain];

	/*Attach the menu to the status item.*/
	tmenu = [self standardMenu];
	[systemBar setMenu: tmenu];

	/* [systemBar setMenu: mainMenu]; */
    systemBar.button.title = @"MacBiff";
    
	[systemBar setHighlightMode: YES];
}


- (NSMenu*) standardMenu
{
	NSMenu *menu = NULL;
	NSMenuItem *menuItem = NULL;

	goRed = NO;

	menu = [[NSMenu alloc] initWithTitle: @"MacBiff"];

	/* Refresh commands*/
	if ( checkStatus ) {
		[checkStatus release];
	}
	checkStatus = [menu addItemWithTitle: @"Checking..."
		action: NULL
		keyEquivalent: @""];
	[checkStatus retain];

	menuItem = [menu addItemWithTitle: @"Configure"
		action: @selector (openPrefs:)
		keyEquivalent: @""];
	[menuItem setTarget: self];

	menuItem = [menu addItemWithTitle: @"Detach"
		action: @selector (detachList:)
		keyEquivalent: @""];
	[menuItem setTarget: self];

	menuItem = [menu addItemWithTitle: @"Show Activity"
		action: @selector(display:)
		keyEquivalent: @""];
	[menuItem setTarget: actWin];

	menuItem = [menu addItemWithTitle: @"Launch Mail"
		action: @selector (launchMail:)
		keyEquivalent: @""];
	[menuItem setTarget: self];

	menuItem = [menu addItemWithTitle: @"About MacBiff"
		action: @selector (openAbout:)
		keyEquivalent: @""];
	[menuItem setTarget: self];

	menuItem = [menu addItemWithTitle: @"Quit MacBiff"
		action: @selector (terminate:)
		keyEquivalent: @""];
	[menuItem setTarget: NSApp];


	return menu;
}


- (void) checkMail
{
	imap *server;
	NSMenuItem *title;
	int res, i;
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	if ( ![prefs integerForKey: @"Server Count"] ) {
		return;
	}

	total = unread = 0;

	if ( mainMenu ) {
		[mainMenu release];
	}
	mainMenu = [self standardMenu];

	[actWin performSelectorOnMainThread: @selector(startChecking:)
				 withObject: [NSNumber numberWithInt: [servers count]]
			      waitUntilDone: YES];
	/* Check Mail */
	for ( i = 0 ; i < [servers count] ; ++i ) {
		dprintf("%s starting server # %d\n", __FUNCTION__, i);
		server = [servers objectAtIndex: i];
		[mainMenu addItem: [NSMenuItem separatorItem]];
		title = [mainMenu addItemWithTitle:
					[server name]
				action: @selector (editServer:)
				keyEquivalent: @""];
		[title setTarget: self];
		[title setTag: i];
		[actWin performSelectorOnMainThread: @selector(startServer:)
					 withObject: [server name]
				      waitUntilDone: YES];
		if ( ![server enabled] || user_pressed_stop ) {
			[title setEnabled: NO];
			continue;
		}
		dprintf("%s calling [server checkMail]\n", __FUNCTION__ );
		@try {
			res = [server checkMail];
		}
		@catch (NSException *exception) {
			alert("Exception thrown!\n");
			alert("thrown:  '%s'\n", [[exception name] UTF8String]);
			if ( ![[exception name] isEqualTo: @"Bad Comms"] ) {
				alert("Howdy\n");
				@throw;
			}
			res = 1;
		}
		if ( user_pressed_stop ) {
			total = 0;
			continue;
		}
		dprintf("%s back from [server checkMail]\n", __FUNCTION__ );
		if ( res ) {
			if ( res == EAUTH ) {
				/* Get password */
				[self askPassForServer: i];
				continue;
			}
			/* goRed = YES; */
			[mainMenu addItemWithTitle:
					[NSString stringWithFormat:
					@"Err: (%d) %s", errno, strerror(errno)]
				action: NULL
				keyEquivalent: @"" ];
		} else {
			unsigned serverUnread;

			dprintf("%s calling [server addToMenu]\n", __FUNCTION__);
			[server addToMenu: mainMenu];
			dprintf("%s back from [server addToMenu]\n", __FUNCTION__);

			total += [server messagesTotal];
			unread += serverUnread = [server messagesUnread];
			goRed |= [server newMail];

			[title setTitle: [NSString stringWithFormat: @"%@ [%d/%d]",
				[server name], [server messagesUnread],
				[server messagesTotal]]];

#ifdef USE_GROWL
			if ( [server newMail] &&
					[prefs boolForKey:@"Notify with Growl"]) {
				NSString *description;
				if ( serverUnread == 1U ) {
					/* One unread Message */
					description =
						[NSString stringWithFormat:
						NSLocalizedString(growlDescriptionFormats[0], nil),
							[server name], 
							[[server newMailFolders] objectAtIndex: 0]];
				} else if ([[server newMailFolders] count] == 1){
					description =
						[NSString stringWithFormat:
							NSLocalizedString(growlDescriptionFormats[1], nil),
							[server name],
							serverUnread,
							[[server newMailFolders] objectAtIndex: 0]];
				} else {
					description =
						[NSString stringWithFormat:
							NSLocalizedString(growlDescriptionFormats[2], nil),
							[server name],
							serverUnread,
							[[server newMailFolders] objectAtIndex: 0],
							[[server newMailFolders] count] - 1];
				}
				
				if ( [prefs boolForKey: @"Fetch Unread Headers"] ) {
					NSString *detailString = [NSString stringWithFormat:@"%@", [server newMailDetails]] ;
					description = [description stringByAppendingString:detailString];
				}
				[GrowlApplicationBridge notifyWithTitle:@"You have new mail."
					description:description
					notificationName:newMailNotificationName
					iconData:iconData 
					priority:0
					isSticky:NO
					clickContext:nil];
			}
#endif //def USE_GROWL
		}
	}
	if ( total && ![prefs boolForKey: @"Hide Total"]) {
		if ( [prefs boolForKey: @"Hide Brackets"]) {
			[mainMenu setTitle: [NSString stringWithFormat: @"%d/%d", unread, total]];
		} else {
			[mainMenu setTitle: [NSString stringWithFormat: @"[%d/%d]", unread, total]];
		}
	} else if ( total ) {
		if ( [prefs boolForKey: @"Hide Brackets"]) {
			[mainMenu setTitle: [NSString stringWithFormat: @"%d", unread]];
		} else {
			[mainMenu setTitle: [NSString stringWithFormat: @"[%d]", unread]];
		}
	}
	[actWin performSelectorOnMainThread: @selector(finished:)
				 withObject: Nil
			      waitUntilDone: NO];
	if ( CheckNow && [prefs boolForKey: @"Show Activity"] ) {
		[actWin close];
	}
}



- (void) menuUpdate
{
	NSDictionary *attrs;
	NSColor *color = [NSColor blackColor];
	NSAttributedString *attrStr;

	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	dprintf("%s calling checkMail\n", __FUNCTION__);
	[self checkMail];

	dprintf("%s back from checkMail (mainMenu: %p)\n", __FUNCTION__, mainMenu);
	[systemBar setMenu: mainMenu];
	dprintf("%s set the menu (red: %d)\n", __FUNCTION__, goRed);

	if ( goRed || unread ) {
		if ( [prefs boolForKey: @"Alert Color"] ) {
			color = [NSColor redColor];
		}

		/*
		 * "Always Beep" is undocumented... Exists for Kyle.
		 */

		/* Beep */
		if ( (goRed || [prefs boolForKey: @"Always Beep"]) &&
				[prefs boolForKey: @"Alert Sound"] ) {
			dprintf("Going to play sound named: '%s'\n",
					[[prefs stringForKey: @"Sound Name"] UTF8String]);
			if ( [[prefs stringForKey: @"Sound Name"]
					isEqualToString: @"System Beep"] ) {
				NSBeep();
			} else {
				NSSound *snd = [NSSound soundNamed:
					[prefs stringForKey: @"Sound Name"]];
				[snd play];
			}
		}
	}

	dprintf("%s setting attributes\n", __FUNCTION__);
	attrs = [NSDictionary dictionaryWithObject: color
		forKey: NSForegroundColorAttributeName];
	attrStr = [[NSAttributedString alloc] initWithString: [mainMenu title]
		attributes: attrs];

	if ( [prefs boolForKey: @"Show Icon"] ) {
		dprintf("Showing icon\n");
		if ( unread ) {
            systemBar.button.image = [NSImage imageNamed: @"envelope.pdf"];
		} else if ( [prefs boolForKey: @"Hide Text"] ) {
            systemBar.button.image = [NSImage imageNamed: @"dash.pdf"];
        } else {
            systemBar.button.image = nil;
		}
	} else {
		dprintf("No icon selected\n");
        systemBar.button.image = nil;
	}
	dprintf("Setting text\n");
	if ( ![prefs boolForKey: @"Hide Text"] ) {
        if (color == [NSColor redColor]) {
            systemBar.button.attributedTitle = attrStr;
        } else {
            systemBar.button.title = [mainMenu title];
        }
	} else if ( [prefs boolForKey: @"Show Icon"] ) {
        systemBar.button.title = @"";
	} else {
        systemBar.button.title = @"MacBiff";
    }
	dprintf("Setting length\n");
	[systemBar setLength: NSVariableStatusItemLength];
	[attrStr release];
}


/*
 * Miscellaneous Callbacks
 */

- (IBAction) detachList: (id) sender
{
	[Dlist setServers: servers];
	[Dwindow makeKeyAndOrderFront: self];
	[NSApp activateIgnoringOtherApps: YES];
}


- (IBAction) switchUnread: (id) sender
{

}


- (IBAction) refresh: (id) sender
{
	dprintf("In %s\n", __FUNCTION__);

	[NSThread detachNewThreadSelector: @selector (threadRefresh:)
			toTarget: self
			withObject: nil];
}


- (void) threadRefresh: (id) data
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableAttributedString *matstring = NULL;
	NSAttributedString *backtitle = NULL;
	NSMutableString *tstring;

	if ( [lock tryLock] ) {

		struct sigaction usr2act;
		memset(&usr2act, 0, sizeof(struct sigaction));
		sigemptyset(&(usr2act.sa_mask));

		usr2act.sa_handler = sigUSR2;
		sigaction(SIGUSR2, &usr2act, NULL);

		checking_thread = pthread_self();

		if ( !systemBar ) {
			[self setupMenuBar];
		}

		if ( systemBar.button.title ) {
			matstring = [[NSMutableAttributedString alloc]
				initWithAttributedString:
                    systemBar.button.attributedTitle];
            backtitle = [[NSAttributedString alloc]
				initWithAttributedString:
                    systemBar.button.attributedTitle];
            
            tstring = [matstring mutableString];
			if ( tstring && [tstring length] ) {
				[tstring replaceOccurrencesOfString: @"["
					withString: @"{"
					options: NSLiteralSearch
					range: NSMakeRange(0, 1)];
				[tstring replaceOccurrencesOfString: @"]"
					withString: @"}"
					options: NSLiteralSearch|NSBackwardsSearch
					range: NSMakeRange([tstring length]-1, 1)];

                systemBar.button.attributedTitle = matstring;
			}
			[matstring release];

		}
		[checkStatus setTitle: @"Stop Check"];
		[checkStatus setAction: @selector(stopcheck:)];
		[checkStatus setTarget: self];
		[mainMenu itemChanged: checkStatus];

		user_pressed_stop = 0;

		dprintf("%s calling menuUpdate\n", __FUNCTION__);
		[self menuUpdate];
		dprintf("%s back from menuUpdate\n", __FUNCTION__);

		if ( user_pressed_stop == 0 ) {
			[systemBar setMenu: mainMenu];
			[Dlist updateData];
		} else {
            systemBar.button.attributedTitle = backtitle;
        }

		if ( backtitle ) {
			[backtitle release];
		}


		[checkStatus setTitle: @"Check Now"];
		[checkStatus setAction: @selector(checknow:)];
		[checkStatus setTarget: self];
		[mainMenu itemChanged: checkStatus];


		[pool release];
		if ( CheckNow ) {
			CheckNow = NO;
		}

		checking_thread = NULL;

		[lock unlock];
	}
	dprintf("Leaving %s\n", __FUNCTION__);

	return;
}

- (void)wakeUp:(NSAppleEventDescriptor*) event
	withReplyEvent: (NSAppleEventDescriptor*) replyEvent
{
	[self refresh: self];
}


- (void)wakeUp:(NSNotification *)notification
{
	[self refresh:[notification object]];
}


@end

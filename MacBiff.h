/* vim:set ft=objc:
 * $Id: MacBiff.h 180 2012-02-12 16:29:03Z lhagan $
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
#include <pthread.h>
#import "mailbox.h"
#import "serverselect.h"
#import "folderlist.h"
#import "detachlist.h"


@interface MacBiff : NSObject <GrowlApplicationBridgeDelegate> {
	NSStatusItem *systemBar;
	NSMenu *mainMenu;
	NSMenuItem *checkStatus; /* CheckNow/Checking item */
	NSLock *lock;
	pthread_t checking_thread;
	NSTimer *timer;

	NSMutableArray *servers;
	int ICcurServer;
	bool ICadding;

	int unread;
	int total;
	bool goRed;
	bool CheckNow;

	/*the only reason these two aren't static is for code simplicity.
	 *they could be made static, but there would be hoops to be jumped through.
	 *they go together with appName (which is static, in MacBiff.m), and
	 *  together, all three serve to support Growl.
	 */
	NSData *iconData;
	NSArray *notificationNames;

	IBOutlet NSWindow	*prefsWindow;
	IBOutlet NSTableView	*CserverTbl;
	IBOutlet serverselect	*CserverDS;
	IBOutlet NSButton	*CeditBut;
	IBOutlet NSTextField	*CdelayText;
	IBOutlet NSStepper	*CdelayStep;
	IBOutlet NSTextField	*CmailAppText;
	IBOutlet NSTextField	*CunreadMailCommand;
	IBOutlet NSButton	*CcheckHeaders;
	IBOutlet NSButton	*CshowActivity;
	IBOutlet NSButton	*CcheckIgnHeaders;
	IBOutlet NSButton	*CcountIgnores;
	IBOutlet NSButton	*CshowText;
	IBOutlet NSButton	*CchColorBut;
	IBOutlet NSButton	*CshowTotBut;
	IBOutlet NSButton	*CshowBrackets;
	IBOutlet NSButton	*CshowIcon;
	IBOutlet NSButton	*CdoSoundBut;
	IBOutlet NSButton	*CuseGrowl;
	IBOutlet NSPopUpButton	*CsoundChoicePop;

	IBOutlet NSWindow	*aboutWindow;
	IBOutlet NSTextField	*MacBiffVersion;

	IBOutlet NSTextField	*ICName;
	IBOutlet NSTextField	*ICServer;
	IBOutlet NSTextField	*ICUsername;
	IBOutlet NSTextField	*ICPasswd;
	IBOutlet NSTextField	*ICPrefix;
	IBOutlet NSButton	*ICuseSSL;
	IBOutlet NSButton	*ICKeepPW;
	IBOutlet NSButton	*ICenable;
	IBOutlet NSOutlineView	*ICignorables;
	IBOutlet folderlist	*ICignoreDS;
	IBOutlet NSWindow	*ICconfigWindow;
	IBOutlet NSTextField	*ICPort;
	IBOutlet NSButton	*ICsubscribed;

	IBOutlet NSTextField	*PWtext;
	IBOutlet NSSecureTextField	*PWpasswd;
	IBOutlet NSButton	*PWkeepPW;
	IBOutlet NSWindow	*PWpassWindow;

	IBOutlet NSWindow	*Dwindow;
	IBOutlet detachlist	*Dlist;
}


- (void) awakeFromNib;
- (void) applicationDidFinishLaunching;

/* About Box */
- (IBAction)openAbout:(id)sender;
- (IBAction)canelAbout:(id)sender;
- (IBAction)openURL:(id)sender;

/* General Config */
- (IBAction)openPrefs:(id)sender;
- (IBAction)savePrefs:(id)sender;
- (IBAction)cancelPrefs:(id)sender;
- (IBAction)editServer:(id)sender;
- (IBAction)addServer:(id)sender;
- (IBAction)delServer:(id)sender;
- (IBAction)stepDelay:(id)sender;
- (IBAction)editDelay:(id)sender;
- (IBAction)selectText:(id)sender;
- (IBAction)selectSound:(id)sender;
- (IBAction)soundChange:(id)sender;
- (IBAction)selectFetch:(id)sender;
- (IBAction)chooseApp:(id)sender;
- (IBAction)launchMail:(id)sender;
- (IBAction)openGrowlURL:(id)sender;
- (void) registerDefaultPreferences;
- (void) loadServers;

/* Imap Config */
- (void) Iconfigure;
- (void) IremoveServer: (int) num;
- (IBAction) IcancelConfig: (id) sender;
- (IBAction) IsaveConfig: (id) sender;
- (IBAction) IchangeMode: (id) sender;

/* Ask password */
- (void) askPassForServer: (int) num;
- (IBAction) PWcancel: (id) sender;
- (IBAction) PWOK: (id) sender;

- (void) setupMenuBar;
- (NSMenu*) standardMenu;
- (void) checkMail;
- (void) menuUpdate;

- (IBAction)detachList:(id)sender;

- (IBAction)refresh:(id)sender;
- (void) threadRefresh: (id) data;
- (void) wakeUp: (NSAppleEventDescriptor*) event
	withReplyEvent: (NSAppleEventDescriptor*) replyEvent;

@end

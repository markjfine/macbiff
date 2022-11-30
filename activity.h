/* vim:set ft=objc:
* $Id: activity.h 105 2004-11-27 20:17:13Z bmoore $
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

@interface activity : NSObject {

	double serverpctg;
	int _outOf;
	int _currCount;
	NSString *idleString;
	NSString *nullString;

        IBOutlet NSWindow       *Window;
        IBOutlet NSProgressIndicator *ProgOverall;
        IBOutlet NSProgressIndicator *ProgServer;
        IBOutlet NSTextField    *Server;
        IBOutlet NSTextField    *Activity;
}

- (IBAction) display: (id) sender;
- (void) close;
- (bool) isOpen;
- (IBAction) startChecking: (id) sender;
- (IBAction) startServer: (id) sender;
- (IBAction) doingActivity: (id) sender;
- (IBAction) activityDone: (id) sender;
- (IBAction) finished: (id) sender;

@end

extern activity *actWin;

/*
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

SUMMARY:
===========================================================================
        MacBiff is a Mac OSX 10.5 (and higher) compliant "biff" program.
Its job is to report to the user when they receive new email, and where that
email is.

CONFIGURATION:
===========================================================================
        The MacBiff Setup window is split in to three parts: Servers, Alerts
and Options.
        Servers shows a list of the configured IMAP servers, and gives you
the ability to enable/disable them, or add/remove/edit them.
        The Alerts tab allows you to configure how you would like to be
notified of new mail.  You can have MacBiff display the count of messages in
text, or display a small graphic.  The text can change color to notify you
of new mail, and you can choose to have a system sound be played.  As of
version 1.1.9, there is support for Growl Notification (see http://growl.info)
There is also the option of executing a shell command whenever new mail is 
received.  If you enter a command into this textbox, the following "special" 
codes are replaced accordingly:
    %m = mailbox name
    %p = full mailbox path name
    %t = total number of messages in the mailbox
    %u = number of unread messages in the mailbox
    %n = new unread messages in the mailbox

        The Options tab allows you to set various options that control how
MacBiff works.
  * Check Mail Delay: Select how often you wish MacBiff to check for new mail.
  * Include "Ignored" Folders in count:  Determins if new messages in
        "ignored" folders should be used to calculate new message counts.
  * Fetch Unread Headers:  Choose to download the headers of unread messages.
  * Fetch Unread Headers in "Ignored" Folders:  (self explanitory)
  * Display Activity Window on "Check Now":  (self explanitory)
  * Mail Application:  Command to run when "Launch Mail" is chosen from the
        menu.


The Connection Setup window for each configured server shows a listing of
options on the left, and a folder listing on the right.

  * Server Identifier:  This is the "Title" of the server configuration.
  * Server Name:  This is the IP name of the mail server.
  * User Name:  This is the login name of the user.
  * Password:  Login password.
  * Path Prefix:  Set this only if needed, to specify where your IMAP folders
        are located.
  * Use SSL:  Enabled by default.  You should be using SSL.  This causes
        MacBiff to connect to your IMAP/SSL server on port 993.
  * Save Password:  Enabled by default.  Saves your password in the OSX
        Keychain.
  * Enabled:  Set to enable/disable checking this account.

The Folder listing on the right is empty until you first check mail.  It
shows the folders that it knows about.  If you check the "Ignore" box for
a folder, that folder will not be used to determine if New Mail notification
should be notification should be issued.  If you check the "Disabled" box
for a folder, that folder will not be checked at all.


USAGE:
===========================================================================
        MacBiff will then go out and query the IMAP server for your email.
It will display in the menu-bar the amount of unread email, as well as the
total amount of email you have on the server in the form [#unread / #total].

In the dropdown menu, there are options to:
  * Check Now:            Force MacBiff to update immediately.
  * Configure:            Brings up the configuration dialog.
  * Detatch:              Opens a window showing your mail folders.
  * Show Activity:	  Opens an Activity window.
  * Launch Mail:          Launches configured mail application.
  * About MacBiff:        Opens an About Dialog
  * Quit MacBiff:         Quits MacBiff

Below these options are your mailboxes.  If you have no new email, no
mailboxes will be shown.  Mailboxes with unseen email will show up (along
with their parents) with a checkbox next to them.  If you un-check the
checkbox, that folder will no longer be used to determine if the New Mail
notification should be used, but will still be displayed.  If you have
"Fetch Unread Headers" selected, a listing of the new mail will be shown as
a sub-menu to the folder.

If you have no unread mail (or only unread mail in un-checked folders),
MacBiff will display in black letters in the System Menu Bar.  If you do
have unread email, MacBiff will display in Red.  Also, a system beep will be
sounded to alert you to the new mail.

ABOUT MACBIFF:
===========================================================================
        MacBiff was created in early 2004 to solve the problem of mixing
procmail with pine.  Mail gets delivered to non "Inbox" folders, which pine
would not notice, thus necessitating a search for new mail.  With MacBiff, I
am notified when mail arrives, and what folders it has been delivered to.
This also works well with Mail.app, which tends to not automatically
syncronize folders (even when asked).

AUTHOR:
===========================================================================
        MacBiff was written by Branden J. Moore <bmoore@forkit.org>, with
contributions from Mr. Wheeler, Mr. Pollet, Mr. Babin and Mac-arena the Bored
Zo.  Thanks to Dr. Anderson for his help in debugging.

Luke Hagan <lhagan@joviancore.com> is currently maintaining MacBiff.

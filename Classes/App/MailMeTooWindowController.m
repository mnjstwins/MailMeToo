//
//  MailMeTooWindowComtroller.mm
//
//  Created by Alessandro Volz on 08.06.11.
//  Copyright 2011 Alessandro Volz. All rights reserved.
//

#import "MailMeTooWindowController.h"
#import "SMTPClient.h"
#import "MailApp.h"

@implementation MailMeTooWindowController

-(id)init {
	return [super initWithWindowNibName:@"EmailWindow" owner:self];
}

-(void)awakeFromNib {
	[self setStatus:nil];
}

-(void)setStatus:(NSString*)str {
	[_statusField setStringValue: str? str : @"" ];
}

-(IBAction)sendAction:(id)sender {
	NSMutableArray* ports = [NSMutableArray array];
	for (NSString* portstr in [[_portsField stringValue] componentsSeparatedByString:@","]) {
		portstr = [portstr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSInteger portnumber = [portstr integerValue];
		if (portnumber > 0)
			[ports addObject:[NSNumber numberWithInteger:portnumber]];
	}
	
	NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys: 
							[_addressField stringValue], SMTPServerAddressKey,
							ports, SMTPServerPortsKey,
							[NSNumber numberWithInteger:[_tlsMatrix selectedTag]], SMTPServerTLSModeKey,
							[_fromField stringValue], SMTPFromKey,
							[NSNumber numberWithBool:[_authCheckbox intValue]], SMTPServerAuthFlagKey,
							[_usernameField stringValue], SMTPServerAuthUsernameKey,
							[_passwordField stringValue], SMTPServerAuthPasswordKey,
							[_toField stringValue], SMTPToKey,
							[_subjectField stringValue], SMTPSubjectKey,
							[_messageField stringValue], SMTPMessageKey,
							NULL];
							
	NSLog(@"Go with %@", params);
	@try {
		[self setStatus:@"Sending..."];
		[self performSelectorInBackground:@selector(_sendThread:) withObject:params];
	} @catch (NSException* e) {
		NSLog(@"Send exception: %@", e.reason);
		[self setStatus:e.reason];
	}
}

-(void)_sendThread:(NSDictionary*)params {
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	@try {
		[SMTPClient send:params];
		[self performSelectorOnMainThread:@selector(setStatus:) withObject:@"" waitUntilDone:NO];
	} @catch (NSException* e) {
		[self performSelectorOnMainThread:@selector(setStatus:) withObject:e.reason waitUntilDone:NO];
	} @finally {
		[pool release];
	}
}

#pragma mark NSMenuDelegate

-(void)menuWillOpen:(NSMenu*)menu {
    [menu removeAllItems];
    NSDictionary* accounts = [MailApp SmtpAccounts];
//    NSLog(@"Accounts: %@", accounts);
    for (NSString* name in accounts) {
        NSDictionary* account = [accounts objectForKey:name];
        NSMenuItem* mi = [[NSMenuItem alloc] initWithTitle:name action:@selector(selectMailAppAccount:) keyEquivalent:@""];
        mi.target = self;
        mi.representedObject = account;
        [menu addItem:mi];
    }
}

-(void)selectMailAppAccount:(NSMenuItem*)mi {
    NSDictionary* account = mi.representedObject;
//    NSLog(@"Account: %@", account);

    [NSUserDefaults.standardUserDefaults setObject:[account objectForKey:SMTPServerAddressKey] forKey:SMTPServerAddressKey];
    
    NSArray* ports = [account objectForKey:SMTPServerPortsKey];
    if (ports.count)
        [NSUserDefaults.standardUserDefaults setObject:[ports componentsJoinedByString:@","] forKey:SMTPServerPortsKey];
    else [NSUserDefaults.standardUserDefaults setObject:@"" forKey:SMTPServerPortsKey];
    
    [NSUserDefaults.standardUserDefaults setInteger:[[account objectForKey:SMTPServerTLSModeKey] integerValue] forKey:SMTPServerTLSModeKey];
    
    BOOL authFlag = [[account objectForKey:SMTPServerAuthFlagKey] boolValue];
    [NSUserDefaults.standardUserDefaults setInteger:authFlag forKey:SMTPServerAuthFlagKey];
    if (authFlag) {
        NSString* username = [account objectForKey:SMTPServerAuthUsernameKey];
//        [_usernameField setStringValue:username];
        [NSUserDefaults.standardUserDefaults setObject:username forKey:SMTPServerAuthUsernameKey];
        
        if ([username rangeOfString:@"@"].length) {
            @try {
                NSString* desc;
                [SMTPClient splitAddress:_fromField.stringValue intoEmail:NULL description:&desc];
                desc = desc.length? [NSString stringWithFormat:@"%@ <%@>", desc, username] : username;
//                [_fromField setStringValue:desc];
                [NSUserDefaults.standardUserDefaults setObject:desc forKey:SMTPFromKey];
            } @catch (...) {
//                [_fromField setStringValue:username];
                [NSUserDefaults.standardUserDefaults setObject:username forKey:SMTPFromKey];
          }
        }
        
        NSString* password = [MailApp SmtpPasswordForAccount:account];
//        [_passwordField setStringValue:(password? password : @"")];
        [NSUserDefaults.standardUserDefaults setObject:(password? password : @"") forKey:SMTPServerAuthPasswordKey];
    } else {
//        [_usernameField setStringValue:@""];
//        [_passwordField setStringValue:@""];
        [NSUserDefaults.standardUserDefaults setObject:@"" forKey:SMTPServerAuthUsernameKey];
        [NSUserDefaults.standardUserDefaults setObject:@"" forKey:SMTPServerAuthPasswordKey];
    }
}

@end



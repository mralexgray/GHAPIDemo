//
//  GHDLoginViewController.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface 								  GHDLoginView : NSView
@property (assign) IBOutlet 				NSButton * loginButton;
@property (assign) IBOutlet NSProgressIndicator * loggingInSpinner;
@property (assign) IBOutlet         NSTextField * usernameTextField,
																* passwordTextField,
																* successTextField,
																* couldNotLoginTextField;	@end

@interface   				 GHDLoginViewController : NSViewController
@property (readonly) 	 				 RACCommand * loginCommand;
@property (readonly)     				 RACSubject * didLoginSubject;
@property (nonatomic,copy) 				NSString * username,
																* password;
@property (readonly) 			             BOOL   successHidden,
																  loginFailedHidden,
																  loggingIn;					@end


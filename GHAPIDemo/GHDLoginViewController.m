//
//  GHDLoginViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDLoginViewController.h"
#import "EXTKeyPathCoding.h"
#import "EXTScope.h"
#import "GHGitHubClient.h"
#import "GHGitHubUser.h"
#import "NSView+GHDExtensions.h"

@implementation GHDLoginView @end 		

@interface GHDLoginViewController()

@property     RACCommand * loginCommand;
@property   GHDLoginView * view;
@property   GHGitHubUser * user;
@property GHGitHubClient * client;
@property     RACSubject * didLoginSubject;
@property 			  BOOL 	successHidden,
									loginFailedHidden,
									loggingIn;
@end

@implementation GHDLoginViewController

#pragma mark API
@dynamic view;

- (id)init {	if (self != super.init) return nil;

	self.loginFailedHidden 	= YES;
	self.successHidden 		= YES;
	self.loggingIn 			= NO;
	
	self.didLoginSubject 	= [RACSubject subject];
	
	// Login is only enabled when they've entered both a username and password.
	self.loginCommand = [RACCommand
		commandWithCanExecuteSignal:[RACSignal combineLatest:@[ RACAbleWithStart(self.username), RACAbleWithStart(self.password) ]
		reduce:^(NSString *username, NSString *password) { 	return @(username.length > 0 && password.length > 0);	}]
		block:NULL];
	
	@unsafeify(self);

	[self.loginCommand subscribeNext:^(id _) { @strongify(self);

		self.user 		= [GHGitHubUser userWithUsername:self.username password:self.password];
		self.client 	= [GHGitHubClient  clientForUser:self.user];
		self.loggingIn = YES;
	}];

	// Try logging in, and return the result. -materialize means that we wrap each next value or error in a RACEvent.
	//	This means that even if the API hits an error, the loginResult signal will still be valid.
	// Every time loginCommand is triggered…
	RACSignal *loginResult = [self.loginCommand sequenceMany:^{ @strongify(self);	return self.client.login.materialize; }];

	[loginResult replayLazily];

	[[[loginResult 		// Since we used -materialize above, we'll need to filter out the specific error or success cases.
		       filter:^BOOL(RACEvent *x){ return x.eventType == RACEventTypeError; 															}]
					 map:    ^(RACEvent *x){ return x.error;																								}]
		subscribeNext:		 ^(NSError *e){ @strongify(self); 	self.loginFailedHidden = NO; 	NSLog(@"error logging in: %@", e);	}];

	[[loginResult 
				 filter:^BOOL(RACEvent *x){ return x.eventType == RACEventTypeCompleted; 														}]
		subscribeNext:           ^(id _){ @strongify(self); self.successHidden = NO; [self.didLoginSubject sendNext:self.user];	}];
	
	[[loginResult map:^(RACEvent *x) {	return @(!x.finished); }] toProperty:@keypath(self.loggingIn) onObject:self];

	[[RACSignal   // When either username or password change, hide the success or failure message.
		combineLatest:	@[ RACAble(self.username), RACAble(self.password)]]
		subscribeNext:^(id _) {	@strongify(self);	self.successHidden = self.loginFailedHidden = YES;	}];
	
	return self;
}

#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView ghd_viewFromNib];
	
	[self.view.     usernameTextField rac_bind:NSValueBinding  toObject:self withKeyPath:@keypath(self.username)];
	[self.view.     passwordTextField rac_bind:NSValueBinding  toObject:self withKeyPath:@keypath(self.password)];
	[self.view.      successTextField rac_bind:NSHiddenBinding toObject:self withKeyPath:@keypath(self.successHidden)];
	[self.view.couldNotLoginTextField rac_bind:NSHiddenBinding toObject:self withKeyPath:@keypath(self.loginFailedHidden)];
	[self.view.      loggingInSpinner rac_bind:NSHiddenBinding toObject:self withNegatedKeyPath:@keypath(self.loggingIn)];
	
	[self.view.loggingInSpinner startAnimation:nil];
	self.view.loginButton.rac_command = self.loginCommand;
}

@end

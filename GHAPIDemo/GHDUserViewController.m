//
//  GHDUserViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDUserViewController.h"
#import "EXTScope.h"
#import "GHGitHubClient.h"
#import "GHGitHubUser.h"
#import "NSView+GHDExtensions.h"


@interface 									GHDUserView : NSView
@property (assign) IBOutlet 				  NSView * valuesContainerView;
@property (assign) IBOutlet 			NSImageView * avatarImageView;
@property (assign) IBOutlet NSProgressIndicator * spinner;
@property (assign) IBOutlet 		   NSTextField * usernameTextField,
														  	   * realNameTextField;			@end
@implementation 							GHDUserView										@end

@interface  				  GHDUserViewController( )
@property 											 BOOL   loading;
@property 								       NSImage * avatar;
@property 								   GHDUserView * view;
@property    							  GHGitHubUser * userAccount;
@property 							   GHGitHubClient * client;						@end

@implementation GHDUserViewController

#pragma mark NSViewController

- (void)loadView { [(self.view = [GHDUserView ghd_viewFromNib]).spinner startAnimation:nil];
	
	[self.view.  usernameTextField rac_bind:NSValueBinding  toObject:self withKeyPath:@keypath(self.userAccount.username)];
	[self.view.  realNameTextField rac_bind:NSValueBinding  toObject:self withKeyPath:@keypath(self.userAccount.realName)];
	[self.view.            spinner rac_bind:NSHiddenBinding toObject:self withNegatedKeyPath:@keypath(self.loading)];
	[self.view.valuesContainerView rac_bind:NSHiddenBinding toObject:self withKeyPath:@keypath(self.loading)];
	[self.view.    avatarImageView rac_bind:NSValueBinding  toObject:self withKeyPath:@keypath(self.avatar)];
}


#pragma mark API

@synthesize userAccount, loading, avatar, client;	@dynamic view;

- (id)initWithUserAccount:(GHGitHubUser *)user {	NSParameterAssert(user != nil);
	
	if (self != [super initWithNibName:nil bundle:nil]) return nil;

	self.userAccount 	= user;
	self.     client 	= [GHGitHubClient clientForUser:self.userAccount];
	self.    loading 	= YES;
	
	@unsafeify(self);

	// We're using -merge: so that -fetchUser, -fetchRepos, and -fetchOrgs are all executed independently.
	//We're then told when they've all completed. -finally: lets us share logic both if we get an error or complete successfully.

	[[[RACSignal
				merge:@[self.fetchUser, self.fetchRepos, self.fetchOrgs]		]
	 		 finally:^{	@strongify(self);	self.loading = NO; }					]
	 subscribeNext:		^(id x){ /*nothing*/ }
				error:^(NSError *e){ NSLog(@"error: %@", e); }
		  completed:				^{ NSLog(@"done"); }								];
	
	// We're using -deliverOn: to load the image in a background queue and then 
	// finish with another -deliverOn: so that subscribers get the result on the main queue.
	RACSignal *loadedAvatar = [[[[RACAble(self.userAccount.avatarURL)
			filter:^ BOOL (id x) {	return x != nil; }                                  ]
		deliverOn:[RACScheduler scheduler]															 ]
	  flattenMap:^(NSURL *URL) { @strongify(self); return [self loadImageAtURL:URL];	}]
		deliverOn:RACScheduler.mainThreadScheduler												 ];
	
	// -merge: takes the latest value from the Signals. In this case,  we're using -[RACSignal return:]
	// to make a Signal that immediately sends the default image, and will use the loaded avatar when it loads.
	[[RACSignal merge:@[[RACSignal return:[NSImage imageNamed:NSImageNameUser]], loadedAvatar]]
			 toProperty:@keypath(self.avatar) onObject:self];
	
	return self;
}

- (RACSignal *)fetchUser {	@unsafeify(self);

	return [self.client.fetchUserInfo map:^(NSDictionary *userDict) { @strongify(self);
		[self.userAccount setValuesForKeysWithDictionary:userDict]; return RACUnit.defaultUnit;
	}];
}

- (RACSignal *)fetchRepos {	

	return [self.client.fetchUserRepos map:^(NSArray *repos) { return NSLog(@"repos: %@", repos), RACUnit.defaultUnit; }];
}

- (RACSignal *)fetchOrgs {

	return [self.client.fetchUserOrgs map:^(NSArray *orgs){ return NSLog(@"orgs: %@", orgs), RACUnit.defaultUnit; }];
}

- (RACSignal *)loadImageAtURL:(NSURL *)URL {

	// This -defer, -publish, -autoconnect dance might seem a little odd, so let's talk through it.

	// We're using -defer because -startWithScheduler:block: returns us a hot Signal but we really want a cold one.
	//	Why do we want a cold one? It lets us defer the actual work of loading the image until someone actually cares enough about
	// it to subscribe. But even more than that, cold Signals let us use operations like -retry: or -repeat:.

	// But the downside to cold Signals is that subsequent subscribers will cause the Signal to fire again, which we don't really want.
	// So we use -publish to share the subscriptions to the underlying Signal. -autoconnect means the connectable Signal from
	// -publish will connect automatically when it receives its first subscriber.

	RACSignal *loadImage = [RACSignal defer:^{
		return [RACSignal startWithScheduler:RACScheduler.immediateScheduler block:^id(BOOL *success, NSError **error) {
			NSImage *image;
			return ((image = [NSImage.alloc initWithContentsOfURL:URL])) ? image : ^{ return *success = NO, (id)nil; }();
		}];
	}];
	
	return [[loadImage retry:1] catchTo:[RACSignal return:[NSImage imageNamed:NSImageNameUser]]].publish.autoconnect;
}

@end

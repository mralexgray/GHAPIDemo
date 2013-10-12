//
//  GHDMainWindowController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDMainWindowController.h"
#import "EXTKeyPathCoding.h"
#import "GHDLoginViewController.h"
#import "GHDUserViewController.h"
#import "GHGitHubUser.h"

@interface 		GHDMainWindowController( )
@property (nonatomic) NSViewController * currentViewController;
@end

@implementation GHDMainWindowController

#pragma mark API

- (void)setCurrentViewController:(NSViewController *)vc { if(_currentViewController == vc) return;

	self.window.contentView = (_currentViewController = vc).view;
}

#pragma mark NSWindowController

- (void)windowDidLoad {	[super windowDidLoad];

	[[[((GHDLoginViewController*)(self.currentViewController = GHDLoginViewController.new)).didLoginSubject
		filter:^BOOL(id x){ return x != nil; 	 		 												}]
			map:	  ^(id x){ return [GHDUserViewController.alloc initWithUserAccount:x];  }]
  toProperty:@keypath(self.currentViewController) 				             onObject:self	 ];
}

- (id)init { return self = [super initWithWindowNibName:NSStringFromClass(self.class) owner:self] ?: nil; }

- (void) applicationDidFinishLaunching:(NSNotification*)n { [self.window makeKeyAndOrderFront:self];      }

@end

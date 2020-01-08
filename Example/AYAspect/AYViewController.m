//
//  AYViewController.m
//  AYAspect
//
//  Created by Alan Yeh on 08/01/2016.
//  Copyright (c) 2016 Alan Yeh. All rights reserved.
//

#import "AYViewController.h"
#import <AYAspect/AYAspect.h>

@interface AYViewController ()

@end

@interface Test : NSObject
- (void)btnAction;
@end

@implementation Test

- (void)btnAction{
    NSLog(@"haha");
}

@end

@implementation AYViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [AYAspect showLog:YES];
    
    [AYAspect interceptSelector:@selector(btnAction:) inClass:AYViewController.class withInterceptor:AYInterceptorMake(^(NSInvocation *invocation) {
        NSLog(@"invoke1: %@", invocation.target);
        
        NSInteger idx = 5;
        [invocation setArgument:&idx atIndex:2];
        [invocation invoke];
        NSLog(@"invoke2");
    })];
    
    [self btnAction: 2];
}

- (void)btnAction:(NSInteger)idx {
    NSLog(@"idx= %@", @(idx));
}

@end

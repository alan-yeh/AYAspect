//
//  AYTestAspectClass.h
//  AYAspect
//
//  Created by Alan Yeh on 16/8/2.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AYTestAspectClass : NSObject
- (NSString *)hello:(NSString *)str;
- (CGPoint)pointByAddingPoint:(CGPoint)point;

- (NSString *)orginalString;
- (NSString *)orginalString2;
@end

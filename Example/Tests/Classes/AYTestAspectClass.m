//
//  AYTestAspectClass.m
//  AYAspect
//
//  Created by Alan Yeh on 16/8/2.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import "AYTestAspectClass.h"

@implementation AYTestAspectClass
- (NSString *)hello:(NSString *)str{
    return [@"From instance: Hello " stringByAppendingString:str];
}

- (CGPoint)pointByAddingPoint:(CGPoint)point{
    return CGPointMake(point.x + 1.0f, point.y + 1.0f);
}

- (NSString *)orginalString{
    return @"foo";
}

- (NSString *)orginalString2{
    return @"foo";
}
@end

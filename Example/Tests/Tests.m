//
//  AYAspectTests.m
//  AYAspectTests
//
//  Created by Alan Yeh on 08/01/2016.
//  Copyright (c) 2016 Alan Yeh. All rights reserved.
//

@import XCTest;
#import <AYAspect/AYAspect.h>
#import "AYTestAspectClass.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAspectInstanceMethod{
    AYTestAspectClass *aspectedObject = [AYTestAspectClass new];
    AYTestAspectClass *unaspectedObject = [AYTestAspectClass new];
    
    NSString *originalString = [aspectedObject orginalString];
    XCTAssertEqualObjects(originalString, @"foo");
    
    NSString *originalString2 = [unaspectedObject orginalString];
    XCTAssertEqualObjects(originalString2, @"foo");
    
    [aspectedObject ay_interceptSelector:@selector(orginalString) withInterceptor:AYInterceptorMake(^(NSInvocation *invocation) {
        [invocation invoke];
        __unsafe_unretained NSString *result;
        [invocation getReturnValue:&result];
        XCTAssertEqualObjects(result, @"foo");
        NSString *newResult = [result stringByAppendingString:@"bar"];
        [invocation setReturnValue:&newResult];
        [invocation retainArguments];
    })];
    
    NSString *newString = [aspectedObject orginalString];
    XCTAssertEqualObjects(newString, @"foobar");
    
    //测试只拦截一个实例
    NSString *newString2 = [unaspectedObject orginalString];
    XCTAssertEqualObjects(newString2, @"foo");
}

- (void)testAspectClassMethod{
    AYTestAspectClass *aspectedObject = [AYTestAspectClass new];
    AYTestAspectClass *unaspectedObject = [AYTestAspectClass new];
    
    NSString *originalString = [aspectedObject orginalString2];
    XCTAssertEqualObjects(originalString, @"foo");
    
    NSString *originalString2 = [unaspectedObject orginalString2];
    XCTAssertEqualObjects(originalString2, @"foo");
    
    [AYTestAspectClass ay_interceptSelector:@selector(orginalString2) withInterceptor:AYInterceptorMake(^(NSInvocation *invocation) {
        [invocation invoke];
        __unsafe_unretained NSString *result;
        [invocation getReturnValue:&result];
        XCTAssertEqualObjects(result, @"foo");
        NSString *newResult = [result stringByAppendingString:@"bar"];
        [invocation setReturnValue:&newResult];
        [invocation retainArguments];
    })];
    
    NSString *newString = [aspectedObject orginalString2];
    XCTAssertEqualObjects(newString, @"foobar");
    
    //测试拦截所有实例
    NSString *newString2 = [unaspectedObject orginalString2];
    XCTAssertEqualObjects(newString2, @"foobar");
}

- (void)testStruct{
    AYTestAspectClass *aspectedObject = [AYTestAspectClass new];
    [aspectedObject ay_interceptSelector:@selector(pointByAddingPoint:) withInterceptor:AYInterceptorMake(^(NSInvocation *invocation) {
        CGPoint param;
        [invocation getArgument:&param atIndex:2];
        XCTAssert(CGPointEqualToPoint(param, CGPointMake(1.0, 1.0)));
        
        CGPoint newParam = CGPointMake(2.0, 2.0);
        [invocation setArgument:&newParam atIndex:2];
        
        [invocation invoke];
        
        CGPoint result;
        [invocation getReturnValue:&result];
        XCTAssert(CGPointEqualToPoint(result, CGPointMake(3.0, 3.0)));
        
        CGPoint newResult = CGPointMake(4.0, 4.0);
        [invocation setReturnValue:&newResult];
    })];
    
    CGPoint result = [aspectedObject pointByAddingPoint:CGPointMake(1.0, 1.0)];
    XCTAssert(CGPointEqualToPoint(result, CGPointMake(4.0, 4.0)));
}

@end


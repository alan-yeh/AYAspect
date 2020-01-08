//
//  AYInvocation.h
//  AYAspect
//
//  Created by Alan Yeh on 16/8/1.
//
//

#import <Foundation/Foundation.h>

@class AYInvocationDetails;
@protocol AYInterceptor;

extern BOOL _ay_aspect_is_show_log;/**< whether show logs */

@interface AYInvocationProxy: NSProxy
@property (nonatomic, strong) NSInvocation *invocation;
@property (nonatomic, strong) NSArray<id<AYInterceptor>> *interceptors;
@property (nonatomic, assign) NSInteger index;
- (instancetype)initWithInvocation:(NSInvocation *)inovcation andInterceptors:(NSArray<id<AYInterceptor>> *)interceptors;
- (void)invoke;
@end

@interface NSObject (AY_INVOCATION_TARGET_INTERCEPTORS)
#pragma mark - for interceptor
- (Class)_ay_aspect_target;
- (void)_ay_set_aspect_target:(Class)target;
@end

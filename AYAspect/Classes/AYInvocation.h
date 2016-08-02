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

@interface AYInvocation : NSInvocation
@end

@interface AYInvocationDetails : NSObject
@property (nonatomic, assign) SEL proxy_selector;/**< original selector */
@property (nonatomic, copy) NSArray<id<AYInterceptor>> *interceptors;/**< interceptors to execute */
@property (nonatomic, assign) NSInteger index;/**< index of executing interceptor */

+ (instancetype)detailsWithProxySelector:(SEL)aSelector interceptors:(NSArray<id<AYInterceptor>> *)interceptors;
@end

@interface NSObject (AY_INVOCATION_TARGET_INTERCEPTORS)
- (void)_ay_set_details:(AYInvocationDetails *)details for_invocation:(NSInvocation *)invocation;
- (AYInvocationDetails *)_ay_details_for_invocation:(NSInvocation *)invocation;

#pragma mark - for interceptor
- (Class)_ay_aspect_target;
- (void)_ay_set_aspect_target:(Class)target;
@end
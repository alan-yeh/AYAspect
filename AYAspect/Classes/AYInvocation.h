//
//  AYInvocation.h
//  AYAspect
//
//  Created by Alan Yeh on 16/8/1.
//
//

#import <Foundation/Foundation.h>

@class PSInvocationDetails;
@protocol AYInterceptor;

extern BOOL _ps_aspect_is_show_log;/**< whether show logs */

@interface PSInvocation : NSInvocation
@end

@interface PSInvocationDetails : NSObject
@property (nonatomic, assign) SEL proxy_selector;/**< original selector */
@property (nonatomic, copy) NSArray<id<AYInterceptor>> *interceptors;/**< interceptors to execute */
@property (nonatomic, assign) NSInteger index;/**< index of executing interceptor */

+ (instancetype)detailsWithProxySelector:(SEL)aSelector interceptors:(NSArray<id<AYInterceptor>> *)interceptors;
@end

@interface NSObject (PS_INVOCATION_TARGET_INTERCEPTORS)
- (void)_ps_set_details:(PSInvocationDetails *)details for_invocation:(NSInvocation *)invocation;
- (PSInvocationDetails *)_ps_details_for_invocation:(NSInvocation *)invocation;

#pragma mark - for interceptor
- (Class)_ps_aspect_target;
- (void)_ps_set_aspect_target:(Class)target;
@end
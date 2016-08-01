//
//  AYInvocation.m
//  AYAspect
//
//  Created by Alan Yeh on 16/8/1.
//
//

#import "AYInvocation.h"
#import "AYAspect.h"
#import <objc/runtime.h>
#import <objc/message.h>

#define PSAssociatedKey(key)  static void *key = &key
#define PSAssociatedKeyAndNotes(key, notes) static void *key = &key

BOOL _ps_aspect_is_show_log = NO;

@implementation PSInvocation
- (void)invoke{
    PSInvocationDetails *details = [self.target _ps_details_for_invocation:self];
    
    NSArray<id<AYInterceptor>> *interceptors = details.interceptors;
    NSInteger index = details.index;
    if (index < interceptors.count) {
        id<AYInterceptor> interceptor = interceptors[interceptors.count - index - 1];
        details.index ++;
        
        if (_ps_aspect_is_show_log) {
            NSLog(@"🍁🍁PSAspect:<%@ %p> -[%@ %@] --> %@\n", NSStringFromClass([self.target class]), self.target, NSStringFromClass([(id)interceptor _ps_aspect_target]), NSStringFromSelector(self.selector), [interceptor description]);
        }
        
        [interceptor intercept:self];
    }else{
        self.selector = details.proxy_selector;
        [super invoke];
    }
}
@end

@implementation NSObject (PS_INVOCATION_TARGET_INTERCEPTORS)
- (NSMutableDictionary<NSNumber/*hash*/*, PSInvocationDetails *> *)_ps_details_invocation_map{
    PSAssociatedKeyAndNotes(PS_DETAILS_INVOCATION_MAP, "store the map of details");
    
    NSMutableDictionary *map = objc_getAssociatedObject(self, PS_DETAILS_INVOCATION_MAP);
    if (map == nil) {
        map = [NSMutableDictionary new];
        objc_setAssociatedObject(self, PS_DETAILS_INVOCATION_MAP, map, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return map;
}

- (PSInvocationDetails *)_ps_details_for_invocation:(NSInvocation *)invocation{
    return [[self _ps_details_invocation_map] objectForKey:@(invocation.hash)];
}

- (void)_ps_set_details:(PSInvocationDetails *)details for_invocation:(NSInvocation *)invocation{
    NSUInteger hash = [invocation hash];
    if (details == nil) {
        [[self _ps_details_invocation_map] removeObjectForKey:@(hash)];
    }else{
        [[self _ps_details_invocation_map] setObject:details forKey:@(hash)];
//        [invocation ps_notificateWhenDealloc:^{
//            [[self _ps_details_invocation_map] removeObjectForKey:@(hash)];
//        }];
    }
}

PSAssociatedKeyAndNotes(PS_ASPECT_TARGET_KEY, "store the target class for interceptor");
- (void)_ps_set_aspect_target:(Class)target{
    objc_setAssociatedObject(self, PS_ASPECT_TARGET_KEY, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (Class)_ps_aspect_target{
    return objc_getAssociatedObject(self, PS_ASPECT_TARGET_KEY);
}
@end

@implementation PSInvocationDetails
+ (instancetype)detailsWithProxySelector:(SEL)aSelector interceptors:(NSArray<id<AYInterceptor>> *)interceptors{
    PSInvocationDetails *details = [PSInvocationDetails new];
    details.proxy_selector = aSelector;
    details.interceptors = interceptors;
    details.index = 0;
    return details;
}
@end
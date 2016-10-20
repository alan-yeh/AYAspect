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
#import <AYRuntime/AYRuntime.h>

BOOL _ay_aspect_is_show_log = NO;

@implementation AYInvocation
- (void)invoke{
    AYInvocationDetails *details = [self.target _ay_details_for_invocation:self];
    
    NSArray<id<AYInterceptor>> *interceptors = details.interceptors;
    NSInteger index = details.index;
    if (index < interceptors.count) {
        id<AYInterceptor> interceptor = interceptors[interceptors.count - index - 1];
        details.index ++;
        
        if (_ay_aspect_is_show_log) {
            NSLog(@"🍁🍁AYAspect:<%@ %p> -[%@ %@] --> %@\n", NSStringFromClass([self.target class]), self.target, NSStringFromClass([(id)interceptor _ay_aspect_target]), NSStringFromSelector(self.selector), [interceptor description]);
        }
        
        [interceptor intercept:self];
    }else{
        self.selector = details.proxy_selector;
        [self.target _ay_set_details:nil for_invocation:self];
        [super invoke];
    }
}
@end

@implementation NSObject (AY_INVOCATION_TARGET_INTERCEPTORS)
- (NSMutableDictionary<NSNumber/*hash*/*, AYInvocationDetails *> *)_ay_details_invocation_map{
    objc_AssociationKeyAndNotes(ay_DETAILS_INVOCATION_MAP, "store the map of details");
    
    NSMutableDictionary *map = objc_getAssociatedObject(self, ay_DETAILS_INVOCATION_MAP);
    if (map == nil) {
        map = [NSMutableDictionary new];
        objc_setAssociatedObject(self, ay_DETAILS_INVOCATION_MAP, map, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return map;
}

- (AYInvocationDetails *)_ay_details_for_invocation:(NSInvocation *)invocation{
    return [[self _ay_details_invocation_map] objectForKey:@(invocation.hash)];
}

- (void)_ay_set_details:(AYInvocationDetails *)details for_invocation:(NSInvocation *)invocation{
    NSUInteger hash = [invocation hash];
    if (details == nil) {
        [[self _ay_details_invocation_map] removeObjectForKey:@(hash)];
    }else{
        [[self _ay_details_invocation_map] setObject:details forKey:@(hash)];
    }
}

objc_AssociationKeyAndNotes(ay_ASPECT_TARGET_KEY, "store the target class for interceptor");
- (void)_ay_set_aspect_target:(Class)target{
    objc_setAssociatedObject(self, ay_ASPECT_TARGET_KEY, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (Class)_ay_aspect_target{
    return objc_getAssociatedObject(self, ay_ASPECT_TARGET_KEY);
}
@end

@implementation AYInvocationDetails
+ (instancetype)detailsWithProxySelector:(SEL)aSelector interceptors:(NSArray<id<AYInterceptor>> *)interceptors{
    AYInvocationDetails *details = [AYInvocationDetails new];
    details.proxy_selector = aSelector;
    details.interceptors = interceptors;
    details.index = 0;
    return details;
}
@end

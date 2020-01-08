//
//  AYInvocation.m
//  AYAspect
//
//  Created by Alan Yeh on 16/8/1.
//
//

#import "AYInvocationProxy.h"
#import "AYAspect.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <AYRuntime/AYRuntime.h>

BOOL _ay_aspect_is_show_log = NO;

@implementation AYInvocationProxy
- (instancetype)initWithInvocation:(NSInvocation *)invocation andInterceptors:(NSArray<id<AYInterceptor>> *)interceptors{
    self.invocation = invocation;
    self.interceptors = interceptors;
    self.index = 0;
    return self;
}

- (void)forwardInvocation:(NSInvocation *)invocation{
    [invocation invokeWithTarget:self.invocation];
}

+ (BOOL)respondsToSelector:(SEL)aSelector{
    return [NSInvocation respondsToSelector:aSelector];
}

- (NSString *)description{
    return [self.invocation description];
}

- (NSString *)debugDescription{
    return [self.invocation debugDescription];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel{
    return [self.invocation methodSignatureForSelector:sel];
}

- (void)invoke{
    if (self.index < self.interceptors.count) {
        id<AYInterceptor> interceptor = self.interceptors[self.interceptors.count - self.index - 1];
        self.index ++;
        
        if (_ay_aspect_is_show_log) {
            NSLog(@"🍁🍁AYAspect:<%@ %p> -[%@ %@] --> %@\n", NSStringFromClass([self.invocation.target class]), self.invocation.target, NSStringFromClass([(id)interceptor _ay_aspect_target]), NSStringFromSelector(self.invocation.selector), [interceptor description]);
        }
        
        [interceptor intercept:(NSInvocation *)self];
    }else{
        [self.invocation invoke];
    }
}

- (void)invokeWithTarget:(id)target{
    self.invocation.target = target;
    [self invoke];
}
@end

@implementation NSObject (AY_INVOCATION_TARGET_INTERCEPTORS)

objc_AssociationKeyAndNotes(ay_ASPECT_TARGET_KEY, "store the target class for interceptor");
- (void)_ay_set_aspect_target:(Class)target{
    objc_setAssociatedObject(self, ay_ASPECT_TARGET_KEY, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (Class)_ay_aspect_target{
    return objc_getAssociatedObject(self, ay_ASPECT_TARGET_KEY);
}
@end


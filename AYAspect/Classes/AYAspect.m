//
//  AYAspect.m
//  AYAspect
//
//  Created by Alan Yeh on 16/8/1.
//
//

#import "AYAspect.h"
#import "AYInvocationProxy.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <AYRuntime/AYRuntime.h>

#define ProxySelector(class, selector) NSSelectorFromString([NSString stringWithFormat:@"__ay_proxy_%@_%@", NSStringFromClass(class), NSStringFromSelector(selector)])


@interface NSObject (AYAspect_Associated_Info)
#pragma mark - instance interceptors
- (NSMutableDictionary<NSString *, NSMutableArray<id<AYInterceptor>> *> *)_ay_aspect_map; /**< cache instance selector-interceptor */
- (NSArray<id<AYInterceptor>> *)_ay_interceptors_for_selector:(SEL)aSelector; /**< get interceptors for selector in instance. */

#pragma mark - class interceptors
+ (NSMutableArray<id<AYInterceptor>> *)_ay_interceptors_for_selector:(SEL)aSelector; /**< get interceptors for selector in class*/
+ (void)_ay_clear_all_interceptors; /**< remove all interceptors in class */

#pragma mark - utils
+ (NSMutableSet<NSString *> *)_ay_aspected_selectors;/**< store the method names which were aspected. */
@end

#pragma mark - AYAspect
@implementation AYAspect
+ (void)showLog:(BOOL)isShow{
    _ay_aspect_is_show_log = YES;
}
@end

@implementation AYAspect (Priviate)
+ (NSMutableSet<Class> *)aspected_classes{
    objc_AssociationKeyAndNotes(AY_ASPECTED_CLASSES, "Store the aspected classes");
    return objc_getAssociatedDefaultObject(self, AY_ASPECTED_CLASSES, [NSMutableSet new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSSet<NSString *> *)unaspectable_selectors{
    return [NSSet setWithObjects:@"retain", @"release", @"autorelease", @"dealloc", @"forwardInvocation:", @"forwardingTargetForSelector", nil];
}

+ (void)check_if_aspectable_selector:(SEL)aSelector in_class:(Class)aClass{
    NSAssert(![[self unaspectable_selectors] containsObject:NSStringFromSelector(aSelector)], @"AYAspect can not complete: Selector: %@ is not allowed to aspect.", NSStringFromSelector(aSelector));
    
    for (Class cls in [self aspected_classes]) {
        if ([[cls _ay_aspected_selectors] containsObject:NSStringFromSelector(aSelector)]) {
            NSAssert(!([cls class] != aClass && [cls isSubclassOfClass:aClass]), @"AYAspect can not complete: The subclass<%@> of <%@> has aspect the selector: %@, aspect same selector in inheritance may cause bugs.", NSStringFromClass(cls), NSStringFromClass(aClass), NSStringFromSelector(aSelector));
            
        
            NSAssert(!([aClass class] != cls && [aClass isSubclassOfClass:cls]), @"AYAspect can not complete: The superclass<%@> of <%@> has aspect the selector: %@, aspect same selector in inheritance may cause bugs.", NSStringFromClass(cls), NSStringFromClass(aClass), NSStringFromSelector(aSelector));
        }
    }
}

/** make a proxy selector instead origin selector. */
+ (void)proxy_selector:(SEL)aSelector in_class:(Class)aClass{
    // check if there is any aspected selector in superclass/subclass
    [self check_if_aspectable_selector:aSelector in_class:aClass];
    
    [self aspect_class:aClass];
    
    if ([[aClass _ay_aspected_selectors] containsObject:NSStringFromSelector(aSelector)]) {
        return;
    }
    [[aClass _ay_aspected_selectors] addObject:NSStringFromSelector(aSelector)];
    
    // find method from target class
    Method originalMethod = class_getInstanceMethod(aClass, aSelector);
    
    // copy method into target class if method is implement in superclass
    if (class_getInstanceMethod(aClass, aSelector) == nil) {
        class_addMethod(aClass, aSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        originalMethod = class_getInstanceMethod(aClass, aSelector);
    }
    
    SEL proxySEL = ProxySelector(aClass, aSelector);
    IMP proxyIMP;
    if ([aClass instanceMethodSignatureForSelector:aSelector].methodReturnLength > 2 * sizeof(NSInteger)) {
#ifdef __arm64__
        proxyIMP = (IMP)_objc_msgForward;
#else
        proxyIMP = (IMP)_objc_msgForward_stret;
#endif
    }else{
        proxyIMP = (IMP)_objc_msgForward;
    }
    
    // add implementation into target class
    class_addMethod(aClass, proxySEL, proxyIMP, method_getTypeEncoding(originalMethod));
    Method proxyMethod = class_getInstanceMethod(aClass, proxySEL);
    
    // exchange the proxy method.
    method_exchangeImplementations(originalMethod, proxyMethod);
}

/** add method [-forwardingTargetForSelector:] and [-forwardInvocation:] to the class. */
+ (void)aspect_class:(Class)aClass{
    if ([[self aspected_classes] containsObject:aClass]) {
        return;
    }
    [[self aspected_classes] addObject:aClass];
    
    //add forwardingTargetForSelector: implementation
    IMP forwardingIMP = imp_implementationWithBlock(^id(id target, SEL selector){
        if ([[aClass _ay_aspected_selectors] containsObject:NSStringFromSelector(selector)]) {
            return target;
        }else{
            SEL proxyForwardingSel = ProxySelector(aClass, @selector(forwardingTargetForSelector:));
            if ([aClass instancesRespondToSelector:proxyForwardingSel]){
                return ((id(*)(struct objc_super *, SEL, SEL))objc_msgSendSuper)(&(struct objc_super){target, aClass}, proxyForwardingSel, selector);
            }else{
                return ((id(*)(struct objc_super *, SEL, SEL))objc_msgSendSuper)(&(struct objc_super){target, [aClass superclass]}, @selector(forwardingTargetForSelector:), selector);
            }
        }
    });
    
    IMP originalForwardingIMP = class_replaceMethod(aClass, @selector(forwardingTargetForSelector:), forwardingIMP, "@@::");
    if (originalForwardingIMP) {
        class_addMethod(aClass, ProxySelector(aClass, @selector(forwardingTargetForSelector:)), originalForwardingIMP, "@@::");
    }
    
    //add forwardInvocation: implementation
    IMP forwardIMP = imp_implementationWithBlock(^(id target, NSInvocation *anInvocation){
        if ([[aClass _ay_aspected_selectors] containsObject:NSStringFromSelector(anInvocation.selector)]) {
            NSArray<id<AYInterceptor>> *interceptors = [AYAspect interceptors_for_invocation:anInvocation search_from:aClass];
            AYInvocationProxy *proxy = [[AYInvocationProxy alloc] initWithInvocation:anInvocation andInterceptors:interceptors];
            [anInvocation setSelector:ProxySelector(aClass, anInvocation.selector)];
            [proxy invoke];
        }else{
            SEL proxyForwardingSel = ProxySelector(aClass, @selector(forwardInvocation:));
            if ([aClass instancesRespondToSelector:proxyForwardingSel]) {
                ((void(*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&(struct objc_super){target, aClass}, proxyForwardingSel, anInvocation);
            }else{
                ((void(*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&(struct objc_super){target, [aClass superclass]}, @selector(forwardInvocation:), anInvocation);
            }
        }
    });
    
    IMP originalForwardIMP = class_replaceMethod(aClass, @selector(forwardInvocation:), forwardIMP, "v@:@");
    if (originalForwardIMP) {
        class_addMethod(aClass, ProxySelector(aClass, @selector(forwardInvocation:)), originalForwardIMP, "v@:@");
    }
}

/** get interceptors for invocation. */
+ (NSArray<id<AYInterceptor>> *)interceptors_for_invocation:(NSInvocation *)invocation search_from:(Class)aClass{
    NSArray<id<AYInterceptor>> *classInterceptors = [aClass _ay_interceptors_for_selector:invocation.selector];
    NSArray<id<AYInterceptor>> *instanceInterceptors = [invocation.target _ay_interceptors_for_selector:invocation.selector];
    
    NSMutableArray *result = [NSMutableArray new];
    
    if (classInterceptors.count) {
        [result addObjectsFromArray:classInterceptors];
    }
    if (instanceInterceptors.count) {
        [result addObjectsFromArray:instanceInterceptors];
    }
    
    return result;
}

@end

@implementation AYAspect (Class)
+ (void)interceptSelector:(SEL)aSelector inClass:(Class)aClass withInterceptor:(id<AYInterceptor>)aInterceptor{
    NSParameterAssert(aSelector);
    NSParameterAssert(aClass);
    NSParameterAssert(aInterceptor);
    NSAssert([aClass instancesRespondToSelector:aSelector], @"AYAspect can not complete: Instance of <%@> does not respond to selector:%@", NSStringFromClass(aClass), NSStringFromSelector(aSelector));
    
    [self proxy_selector:aSelector in_class:aClass];
    
    [(id)aInterceptor _ay_set_aspect_target:aClass];
    [[aClass _ay_interceptors_for_selector:aSelector] addObject:aInterceptor];
}

+ (void)clearInterceptorsForClass:(Class)aClass{
    [aClass _ay_clear_all_interceptors];
}

+ (void)clearInterceptsForSelector:(SEL)aSelector inClass:(Class)aClass{
    [[aClass _ay_interceptors_for_selector:aSelector] removeAllObjects];
}
@end


@implementation AYAspect (Instance)
+ (void)interceptSelector:(SEL)aSelector inInstance:(id)aInstance withInterceptor:(id<AYInterceptor>)aInterceptor{
    NSParameterAssert(aSelector != NULL);
    NSParameterAssert(aInterceptor);
    NSParameterAssert(aInterceptor);
    NSAssert([aInstance respondsToSelector:aSelector], @"AYAspect can not complete: Instance:<%@ %p> does not respond to selector:%@",NSStringFromClass(aInterceptor.class), aInstance, NSStringFromSelector(aSelector));
    
    [self proxy_selector:aSelector in_class:[aInstance class]];
    
    [(id)aInterceptor _ay_set_aspect_target:[aInstance class]];
    NSMutableDictionary<NSString *,NSMutableArray<id<AYInterceptor>> *> *dic = [aInstance _ay_aspect_map];
    
    NSMutableArray<id<AYInterceptor>> *interceptors = dic[NSStringFromSelector(aSelector)];
    if (interceptors == nil) {
        interceptors = [NSMutableArray new];
        dic[NSStringFromSelector(aSelector)] = interceptors;
    }
    [interceptors addObject:aInterceptor];
}
@end

#pragma mark - AYAspect Associated Info
@implementation NSObject (AYAspect_Associated_Info)
#pragma mark - instance interceptors
- (NSMutableDictionary<NSString *,NSMutableArray<id<AYInterceptor>> *> *)_ay_aspect_map{
    objc_AssociationKeyAndNotes(OBJECT_ASPECT_MAP_KEY, "Store Selector-Interceptors Map");
    return objc_getAssociatedDefaultObject(self, OBJECT_ASPECT_MAP_KEY, [NSMutableDictionary new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<id<AYInterceptor>> *)_ay_interceptors_for_selector:(SEL)aSelector{
    return [[self _ay_aspect_map] objectForKey:NSStringFromSelector(aSelector)];
}

#pragma mark - class interceptors
objc_AssociationKeyAndNotes(AY_INTERCEPTORS_FOR_SELECTOR_IN_OWN, "Store Interceptors for selector");
+ (NSMutableArray<id<AYInterceptor>> *)_ay_interceptors_for_selector:(SEL)aSelector{
    
    NSMutableDictionary<NSString *, NSMutableArray<id<AYInterceptor>> *> *dic = objc_getAssociatedDefaultObject(self, AY_INTERCEPTORS_FOR_SELECTOR_IN_OWN, [NSMutableDictionary new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    NSMutableArray<id<AYInterceptor>> *array = dic[NSStringFromSelector(aSelector)];
    if (array == nil) {
        array = [NSMutableArray new];
        dic[NSStringFromSelector(aSelector)] = array;
    }
    return array;
}

+ (void)_ay_clear_all_interceptors{
    objc_setAssociatedObject(self, AY_INTERCEPTORS_FOR_SELECTOR_IN_OWN, [NSMutableDictionary new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSMutableSet<NSString *> *)_ay_aspected_selectors{
    objc_AssociationKeyAndNotes(AY_ASPECTED_SELECTOR_KEY, "Store selectors that aspected");
    return objc_getAssociatedDefaultObject(self, AY_ASPECTED_SELECTOR_KEY, [NSMutableSet new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation NSObject (AYAspect)
- (void)ay_interceptSelector:(SEL)aSelector withInterceptor:(id<AYInterceptor>)aInterceptor{
    [AYAspect interceptSelector:aSelector inInstance:self withInterceptor:aInterceptor];
}

+ (void)ay_interceptSelector:(SEL)aSelector withInterceptor:(id<AYInterceptor>)aInterceptor{
    [AYAspect interceptSelector:aSelector inClass:[self class] withInterceptor:aInterceptor];
}
@end

#pragma mark - AYBlockInterceptor
@interface _AYBlockInterceptor : NSObject<AYInterceptor>
@property (nonatomic, copy) void (^interceptor)(NSInvocation *invocation);
+ (instancetype)interceptorWithBlock:(void (^)(NSInvocation *invocation))block;
@end

@implementation _AYBlockInterceptor
+ (instancetype)interceptorWithBlock:(void (^)(NSInvocation *))block{
    _AYBlockInterceptor *instance = [self new];
    instance.interceptor = block;
    return instance;
}
- (void)intercept:(NSInvocation *)invocation{
    if (self.interceptor) {
        self.interceptor(invocation);
    }
}
@end

id<AYInterceptor> AYInterceptorMake(void (^block)(NSInvocation *invocation)){
    return [_AYBlockInterceptor interceptorWithBlock:block];
}

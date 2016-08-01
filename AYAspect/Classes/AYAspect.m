//
//  AYAspect.m
//  AYAspect
//
//  Created by Alan Yeh on 16/8/1.
//
//

#import "AYAspect.h"
#import "AYInvocation.h"
#import <objc/runtime.h>
#import <objc/message.h>

#define ProxySelector(class, selector) NSSelectorFromString([NSString stringWithFormat:@"__ps_proxy_%@_%@", NSStringFromClass(class), NSStringFromSelector(selector)])

#define PSAssociatedKey(key)  static void *key = &key
#define PSAssociatedKeyAndNotes(key, notes) static void *key = &key

Method ps_class_getInstanceMethod(Class cls, SEL sel){
    Method result = nil;
    unsigned int mcount;
    Method *mlist = class_copyMethodList(cls, &mcount);
    for (int i = 0; i < mcount; i ++) {
        if (method_getName(mlist[i]) == sel) {
            result = mlist[i];
        }
    }
    free(mlist);
    return result;
}


Method ps_class_getMethod(Class cls, SEL sel){
    Method result = nil;
    unsigned int mcount;
    Method *mlist = class_copyMethodList(object_getClass((id)cls), &mcount);
    for (int i = 0; i < mcount; i ++) {
        if (method_getName(mlist[i]) == sel) {
            result = mlist[i];
        }
    }
    free(mlist);
    return result;
}

@interface NSObject (PSAspect_Associated_Info)
#pragma mark - instance interceptors
- (NSMutableDictionary<NSString *, NSMutableArray<id<AYInterceptor>> *> *)_ps_aspect_map; /**< cache instance selector-interceptor */
- (NSArray<id<AYInterceptor>> *)_ps_interceptors_for_selector:(SEL)aSelector; /**< get interceptors for selector in instance. */

#pragma mark - class interceptors
+ (NSMutableArray<id<AYInterceptor>> *)_ps_interceptors_for_selector:(SEL)aSelector; /**< get interceptors for selector in class*/
+ (void)_ps_clear_all_interceptors; /**< remove all interceptors in class */

#pragma mark - utils
+ (NSMutableSet<NSString *> *)_ps_aspected_selectors;/**< store the method names which were aspected. */
@end

#pragma mark - PSAspect
@implementation PSAspect
+ (void)showLog:(BOOL)isShow{
    _ps_aspect_is_show_log = YES;
}
@end

@implementation PSAspect (Priviate)
+ (NSMutableSet<Class> *)_aspected_classes{
    PSAssociatedKeyAndNotes(PS_ASPECTED_CLASSES, "Store the aspected classes");
    return objc_getAssociatedObject(self, PS_ASPECTED_CLASSES) ?: ({id value = [NSMutableSet new]; objc_setAssociatedObject(self, PS_ASPECTED_CLASSES, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC); value;});
}

+ (NSSet<NSString *> *)_unaspectable_selectors{
    static NSSet<NSString *> *unaspectableSelectors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        unaspectableSelectors = [NSSet setWithObjects:@"retain", @"release", @"autorelease", @"dealloc", @"forwardInvocation:", @"forwardingTargetForSelector", nil];
    });
    return unaspectableSelectors;
}

+ (void)_check_if_aspectable_selector:(SEL)aSelector in_class:(Class)aClass{
    NSAssert(![[self _unaspectable_selectors] containsObject:NSStringFromSelector(aSelector)], @"PSAspect can not complete: Selector: %@ is not allowed to aspect.", NSStringFromSelector(aSelector));
    
    for (Class cls in [self _aspected_classes]) {
        if ([[cls _ps_aspected_selectors] containsObject:NSStringFromSelector(aSelector)]) {
            NSAssert(!([cls class] != aClass && [cls isSubclassOfClass:aClass]), @"PSAspect can not complete: The subclass<%@> of <%@> has aspect the selector: %@, aspect same selector in inheritance may cause bugs.", NSStringFromClass(cls), NSStringFromClass(aClass), NSStringFromSelector(aSelector));
            
        
            NSAssert(!([aClass class] != cls && [aClass isSubclassOfClass:cls]), @"PSAspect can not complete: The superclass<%@> of <%@> has aspect the selector: %@, aspect same selector in inheritance may cause bugs.", NSStringFromClass(cls), NSStringFromClass(aClass), NSStringFromSelector(aSelector));
        }
    }
}

/** make a proxy selector instead origin selector. */
+ (void)_proxy_selector:(SEL)aSelector in_class:(Class)aClass{
    // check if there is any aspected selector in superclass/subclass
    [self _check_if_aspectable_selector:aSelector in_class:aClass];
    
    [self _aspect_class:aClass];
    
    if ([[aClass _ps_aspected_selectors] containsObject:NSStringFromSelector(aSelector)]) {
        return;
    }
    [[aClass _ps_aspected_selectors] addObject:NSStringFromSelector(aSelector)];
    
    // find method from target class
    Method originalMethod = class_getInstanceMethod(aClass, aSelector);
    
    // copy method into target class if method is implement in superclass
    if (ps_class_getInstanceMethod(aClass, aSelector) == nil) {
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
+ (void)_aspect_class:(Class)aClass{
    if ([[self _aspected_classes] containsObject:aClass]) {
        return;
    }
    [[self _aspected_classes] addObject:aClass];
    
    //add forwardingTargetForSelector: implementation
    IMP forwardingIMP = imp_implementationWithBlock(^id(id target, SEL selector){
        if ([[aClass _ps_aspected_selectors] containsObject:NSStringFromSelector(selector)]) {
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
        if ([[aClass _ps_aspected_selectors] containsObject:NSStringFromSelector(anInvocation.selector)]) {
            NSArray<id<AYInterceptor>> *interceptors = [PSAspect _interceptors_for_invocation:anInvocation search_from:aClass];
            object_setClass(anInvocation, [PSInvocation class]);
            
            SEL proxySelector = ProxySelector(aClass, anInvocation.selector);
            PSInvocationDetails *details = [PSInvocationDetails detailsWithProxySelector:proxySelector interceptors:interceptors];
            [anInvocation.target _ps_set_details:details for_invocation:anInvocation];
            
            [anInvocation invoke];
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
+ (NSArray<id<AYInterceptor>> *)_interceptors_for_invocation:(NSInvocation *)invocation search_from:(Class)aClass{
    NSArray<id<AYInterceptor>> *classInterceptors = [aClass _ps_interceptors_for_selector:invocation.selector];
    NSArray<id<AYInterceptor>> *instanceInterceptors = [invocation.target _ps_interceptors_for_selector:invocation.selector];
    
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

@implementation PSAspect (Class)
+ (void)interceptSelector:(SEL)aSelector inClass:(Class)aClass withInterceptor:(id<AYInterceptor>)aInterceptor{
    NSParameterAssert(aSelector);
    NSParameterAssert(aClass);
    NSParameterAssert(aInterceptor);
    NSAssert([aClass instancesRespondToSelector:aSelector], @"PSAspect can not complete: Instance of <%@> does not respond to selector:%@", NSStringFromClass(aClass), NSStringFromSelector(aSelector));
    
    [self _proxy_selector:aSelector in_class:aClass];
    
    [(id)aInterceptor _ps_set_aspect_target:aClass];
    [[aClass _ps_interceptors_for_selector:aSelector] addObject:aInterceptor];
}

+ (void)clearInterceptorsForClass:(Class)aClass{
    [aClass _ps_clear_all_interceptors];
}

+ (void)clearInterceptsForSelector:(SEL)aSelector inClass:(Class)aClass{
    [[aClass _ps_interceptors_for_selector:aSelector] removeAllObjects];
}
@end


@implementation PSAspect (Instance)
+ (void)interceptSelector:(SEL)aSelector inInstance:(id)aInstance withInterceptor:(id<AYInterceptor>)aInterceptor{
    NSParameterAssert(aSelector);
    NSParameterAssert(aInterceptor);
    NSParameterAssert(aInterceptor);
    NSAssert([aInstance respondsToSelector:aSelector], @"PSAspect can not complete: Instance:<%@ %p> does not respond to selector:%@",NSStringFromClass(aInterceptor.class), aInstance, NSStringFromSelector(aSelector));
    
    [self _proxy_selector:aSelector in_class:[aInstance class]];
    
    [(id)aInterceptor _ps_set_aspect_target:[aInstance class]];
    NSMutableDictionary<NSString *,NSMutableArray<id<AYInterceptor>> *> *dic = [aInstance _ps_aspect_map];
    
    NSMutableArray<id<AYInterceptor>> *interceptors = dic[NSStringFromSelector(aSelector)];
    if (interceptors == nil) {
        interceptors = [NSMutableArray new];
        dic[NSStringFromSelector(aSelector)] = interceptors;
    }
    [interceptors addObject:aInterceptor];
}
@end

#pragma mark - PSAspect Associated Info
@implementation NSObject (PSAspect_Associated_Info)
#pragma mark - instance interceptors
- (NSMutableDictionary<NSString *,NSMutableArray<id<AYInterceptor>> *> *)_ps_aspect_map{
    PSAssociatedKeyAndNotes(OBJECT_ASPECT_MAP_KEY, "Store Selector-Interceptors Map");
    
    return objc_getAssociatedObject(self, OBJECT_ASPECT_MAP_KEY) ?: ({id value = [NSMutableDictionary new]; objc_setAssociatedObject(self, OBJECT_ASPECT_MAP_KEY, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC); value;});
}

- (NSArray<id<AYInterceptor>> *)_ps_interceptors_for_selector:(SEL)aSelector{
    return [[self _ps_aspect_map] objectForKey:NSStringFromSelector(aSelector)];
}

#pragma mark - class interceptors
PSAssociatedKeyAndNotes(PS_INTERCEPTORS_FOR_SELECTOR_IN_OWN, "Store Interceptors for selector");
+ (NSMutableArray<id<AYInterceptor>> *)_ps_interceptors_for_selector:(SEL)aSelector{
    
    NSMutableDictionary<NSString *, NSMutableArray<id<AYInterceptor>> *> *dic = objc_getAssociatedObject(self, PS_INTERCEPTORS_FOR_SELECTOR_IN_OWN) ?: ({id value = [NSMutableDictionary new]; objc_setAssociatedObject(self, PS_INTERCEPTORS_FOR_SELECTOR_IN_OWN, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC); value;});
    
    NSMutableArray<id<AYInterceptor>> *array = dic[NSStringFromSelector(aSelector)];
    if (array == nil) {
        array = [NSMutableArray new];
        dic[NSStringFromSelector(aSelector)] = array;
    }
    return array;
}

+ (void)_ps_clear_all_interceptors{
    objc_setAssociatedObject(self, PS_INTERCEPTORS_FOR_SELECTOR_IN_OWN, [NSMutableDictionary new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - utils implementation
+ (NSMutableSet<NSString *> *)_ps_aspected_selectors{
    PSAssociatedKeyAndNotes(PS_ASPECTED_SELECTOR_KEY, "Store selectors that aspected");
    NSMutableSet *set = objc_getAssociatedObject(self, PS_ASPECTED_SELECTOR_KEY);
    if (set == nil) {
        set = [NSMutableSet new];
        objc_setAssociatedObject(self, PS_ASPECTED_SELECTOR_KEY, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}
@end

@implementation NSObject (PSAspect)
- (void)ps_interceptSelector:(SEL)aSelector withInterceptor:(id<AYInterceptor>)aInterceptor{
    [PSAspect interceptSelector:aSelector inInstance:self withInterceptor:aInterceptor];
}

+ (void)ps_interceptSelector:(SEL)aSelector withInterceptor:(id<AYInterceptor>)aInterceptor{
    [PSAspect interceptSelector:aSelector inClass:[self class] withInterceptor:aInterceptor];
}
@end

#pragma mark - PSBlockInterceptor
@interface PSBlockInterceptor : NSObject<AYInterceptor>
@property (nonatomic, copy) void (^interceptor)(NSInvocation *invocation);
+ (instancetype)interceptorWithBlock:(void (^)(NSInvocation *invocation))block;
@end

@implementation PSBlockInterceptor
+ (instancetype)interceptorWithBlock:(void (^)(NSInvocation *))block{
    PSBlockInterceptor *instance = [self new];
    instance.interceptor = block;
    return instance;
}
- (void)intercept:(NSInvocation *)invocation{
    if (self.interceptor) {
        self.interceptor(invocation);
    }
}
@end

id<AYInterceptor> interceptor(void (^block)(NSInvocation *invocation)){
    return [PSBlockInterceptor interceptorWithBlock:block];
}
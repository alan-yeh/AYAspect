# AYAspect

[![CI Status](http://img.shields.io/travis/alan-yeh/AYAspect.svg?style=flat)](https://travis-ci.org/alan-yeh/AYAspect)
[![Version](https://img.shields.io/cocoapods/v/AYAspect.svg?style=flat)](http://cocoapods.org/pods/AYAspect)
[![License](https://img.shields.io/cocoapods/l/AYAspect.svg?style=flat)](http://cocoapods.org/pods/AYAspect)
[![Platform](https://img.shields.io/cocoapods/p/AYAspect.svg?style=flat)](http://cocoapods.org/pods/AYAspect)

## 引用
　　使用[CocoaPods](http://cocoapods.org)可以很方便地引入AYAspect。Podfile添加AYAspect的依赖。

```ruby
pod "AYAspect"
```

## 简介
　　在iOS开发中，常常需要引入数据统计、主题应用等，如果在每个ViewController中的viewDidLoad或viewWillAppear等方法进行配置，常常会非常烦索，同时也不容易维护。


> 在我编写到快完成时，遇到了一些困难，在查找资料时，发现了神器[Aspects](https://github.com/steipete/Aspects)，但是感觉在易用性上，还是AYAspect更好用一些

　　AYAspect采用极速化的AOP设计，专注于AOP最核心的目标，将概念减少到极致，无需繁杂的XML配置。AYAspect提供两种类型AOP拦截，可以实现极为强大的AOP功能。
## 全局拦截
　　AYAspect提供全局拦截实现。全局拦截实现只需调用一次，即可以对全局所有对象进行拦截。

　　以下是代码示例：

```objective-c
    //全局拦截[Teacher save]方法
    [AYAspect interceptSelector:@(save) inClass:[Teacher class] withInterceptor:self];
    //清除Teacher下所有拦截器
    [AYAspect clearInterceptorsForClass:[Teacher class]];
    //清除Teacher下save方法所有拦截器
    [AYAspect clearInterceptsForSelector:@selector(save) inClass:[Teacher class]];
```

　　注意: [AYAspect interceptSelector:inClass:withInterceptor:]不要调用多次，只需要调用一次，对`全局所有`对象都有效。

## 实例拦截
　　AYAspect可以实现仅对单个实例进行拦截，对其它实例没有影响。

　　以下是代码示例：

```objective-c
   //拦截一个已存在的实例aTeacher下的save方法
   Teacher *aTeacher = [Teacher new];
   [AYAspect interceptSelector:@selector(save) inInstance:aTeacher withInterceptor:self]
```
## AYInterceptor
　　AYInterceptor是拦截器协议。拦截器必须实现此协议下的`- (void)intercept:(NSInvocation *)invocation`方法。

　　NSInvocation封装了被拦截的方法的信息，拦截器可以通过操作此实例以达到修改函数调用的目的。

## NSInvocation的使用
　　NSInvocation是Apple提供的一种`消息调用`的方法，由于很多同学对NSInvocation的使用方法并不是非常了解，在此对这个类的一些常用用法进行一些讲解。
### 获取/设置参数
```objective-c
   /*
   以[Teacher -loginWithUserName:(NSString *)userName password:(NSString *)pwd为例
   第0个参数是target，第1个参数是SEL，第2个参数才是userName，第3个参数是pwd
   */
   __unsafe_unretained NSString *userName = nil;
   __unsafe_unretained NSString *pwd = nil;
   [invocation getArgument:&userName atIndex:2];
   [invocation getArgument:&pwd atIndex:3];
   
   //设置参数的值
   NSString *newUserName = @"newUserName";
   [invocation setArgument:&newUserName];
   [invocation retainArguments];
```
### 目标target
```objective-c
   /*
   以[Teacher -loginWithUserName:(NSString *)userName password:(NSString *)pwd为例
   target即执行-loginWithUserName:password:的对象
   */
   id target = [invocation target];
```
### 获取/修改返回值
```objective-c
   /*
   以[Teacher -loginWithUserName:(NSString *)userName password:(NSString *)pwd为例
   target即执行-loginWithUserName:password:的对象
   */
   BOOL isSuccess;
   [invocation getReturnValue:&isSuccess];

   //修改返回值
   BOOL newReturnValue = YES;
   [invocation setReturnValue:&isSuccess];
```
### 执行被拦截的函数
```objective-c
   [invocation invoke];
```
## Category
   参考神器Aspect的相关实现时，发现其实现了非常方便Category方法，于是我也将其集成至我的方案中，方便使用。
   
```objective-c
   //拦截所有Teacher下面的save方法
   [Teacher ay_interceptSelector:@selector(save) withInterceptor:AYInterceptorMake(^(NSInvocation *invocation) {
        NSLog(@"执行save方法之前做一些事情");
        [invocation invoke];
        NSLog(@"执行save方法之后做一些事情");
    })];
    
    //拦截实例aTeacher下面的save方法
    Teacher *aTeacher = [Teacher new];
    [aTeacher ay_interceptSelector:@selector(save) withInterceptor:AYInterceptorMake(^(NSInvocation *invocation) {
        NSLog(@"执行save方法之前做一些事情");
        [invocation invoke];
        NSLog(@"执行save方法之后做一些事情");
    })];
```

## License

AYAspect is available under the MIT license. See the LICENSE file for more info.

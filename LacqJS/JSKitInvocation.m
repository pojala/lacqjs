//
//  JSKitInvocation.m
//  JSKit
//
//  Created by glenn andreas on 5/29/08.
//    Copyright (C) 2008 gandreas software. 
//    Permission is hereby granted, free of charge, to any person
//    obtaining a copy of this software and associated documentation
//    files (the "Software"), to deal in the Software without
//    restriction, including without limitation the rights to use,
//    copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the
//    Software is furnished to do so, subject to the following
//    conditions:
//
//    The above copyright notice and this permission notice shall be
//    included in all copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//    OTHER DEALINGS IN THE SOFTWARE.
//
#import <JavaScriptCore/JavaScriptCore.h>
#import "JSKitInternal.h"
#import "JSKitInvocation.h"
#import "JSKitInterpreter.h"
#import "JSKitException.h"
#import "JSKitWrappers.h"


extern void LQJSKitWrappers_initStatics();


@interface LQJSKitInvocationNonRetainedTargetAction : LQJSKitInvocation {
    id myTarget;
    SEL mySelector;
}    
- (id) initWithTarget: (id) target selector: (SEL) selector;
@end

@interface LQJSKitInvocationRetainedTargetAction : LQJSKitInvocationNonRetainedTargetAction {
}    
- (id) initWithTarget: (id) target selector: (SEL) selector;
@end


@interface LQJSKitInvocationWithRawTarget : LQJSKitInvocationNonRetainedTargetAction {
    IMP myImp;
}    
- (id) initWithTarget: (id) target selector: (SEL) selector;
@end


@implementation LQJSKitInvocation


+ (LQJSKitInvocation *) invocationWithRetainedTarget: (id) target action: (SEL) action
{
    return [[[LQJSKitInvocationRetainedTargetAction alloc] initWithTarget:target selector:action] autorelease];
}
+ (LQJSKitInvocation *) invocationWithNonRetainedTarget: (id) target action: (SEL) action
{
    return [[[LQJSKitInvocationNonRetainedTargetAction alloc] initWithTarget:target selector:action] autorelease];
}
+ (LQJSKitInvocation *) invocationWithInvocation: (NSInvocation *) invoke
{
    return nil;
}
+ (LQJSKitInvocation *) invocationWithRawTarget: (id) target action: (SEL) action
{
    return [[[LQJSKitInvocationWithRawTarget alloc] initWithTarget:target selector:action] autorelease];
}

- (JSValueRef) invokeWithContext: (JSContextRef) ctx arguments: (const JSValueRef *)arguments count: (size_t) count exception: (JSValueRef*) exception
{
    return JSValueMakeUndefined(ctx);
}
@end

JSValueRef LQJSKitInvocationCallback(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception)
{
    LQJSKitInvocation *invoke = JSObjectGetPrivate(function);
    return [invoke invokeWithContext:ctx arguments:arguments count:argumentCount exception:exception];
}

extern JSClassRef s_invocationClassRef;

JSObjectRef LQJSKitInvocationFunction(JSContextRef ctx, LQJSKitInvocation *invoke)
{
    if ( !s_invocationClassRef) LQJSKitWrappers_initStatics();
    
    JSObjectRef retval = JSObjectMake(ctx, s_invocationClassRef, [invoke retain]);
    return retval;
}


@implementation LQJSKitInvocationNonRetainedTargetAction

- (id)description {
    return [NSString stringWithFormat:@"<%@: %p - target is: %@>", [self class], self, myTarget]; }

- (id) initWithTarget: (id) target selector: (SEL) selector
{
    self = [super init];
    if (self) {
	myTarget = target;
	mySelector = selector;
    }
    return self;
}
- (JSValueRef) invokeWithContext: (JSContextRef) ctx arguments: (const JSValueRef *)arguments count: (size_t) count exception: (JSValueRef*) exception
{
    NSArray *args = [LQJSKitInterpreter convertJSValueRefs:arguments count:count context:ctx];
    NSValue *ctxArg = [NSValue valueWithPointer:ctx];
    
    id retval = nil;
    BOOL failed = NO;
    @try {
        retval = [myTarget performSelector: mySelector withObject:args withObject:ctxArg];
    } @catch(id exc) {
        failed = YES;
        NSLog(@"Exception during bridge invocation: %@", exc);
        if (exception) {
            *exception = [exc convertToJSExceptionInContext: ctx];
        }
    }
    if (failed) {
        return JSValueMakeUndefined(ctx);
    }
    if (retval == nil) {
        return JSValueMakeNull(ctx);
    }
    return [retval convertToJSValueRefWithContext:(JSGlobalContextRef) ctx];
}
@end


@implementation LQJSKitInvocationRetainedTargetAction
- (id) initWithTarget: (id) target selector: (SEL) selector
{
    self = [super initWithTarget:[target retain] selector:selector];
    return self;
}
- (void) dealloc
{
[myTarget release];
[super dealloc];
}
@end


typedef JSValueRef (*LQJSKitInvokeRawTargetImp)(id, SEL, JSContextRef, const JSValueRef *, size_t, JSValueRef *);

@implementation LQJSKitInvocationWithRawTarget
- (id) initWithTarget: (id) target selector: (SEL) selector
{
    self = [super initWithTarget:[target retain] selector:selector];
    if (self) {
	// sanity check the signature
	NSMethodSignature *sig = [target methodSignatureForSelector:selector];
	if (!sig) {
	    [self release];
	    return nil;
	}
	if ([sig numberOfArguments] != 5) {
	    NSLog(@"LQJSKitInvocationWithJSParamsTarget invalid selector: %@", NSStringFromSelector(selector) );
	    [self release];
	    return nil;
	}
	// due to the vargrities of @encode, further parameter checking could have false negatives
	myImp = [target methodForSelector:selector];
    }
    return self;
}
- (JSValueRef) invokeWithContext: (JSContextRef) ctx arguments: (const JSValueRef *)arguments count: (size_t) count exception: (JSValueRef*) exception
{
    // avoid using any of the conversions, and pass the parameters straight through
    if (!myImp)
	return JSValueMakeUndefined(ctx);

    LQJSKitInvokeRawTargetImp imp = (LQJSKitInvokeRawTargetImp)myImp;

    JSValueRef retval = nil;
    BOOL failed = NO;
    @try {
        retval = imp(myTarget, mySelector, ctx, arguments, count, exception);
    } @catch(id exc) {
        failed = YES;
        NSLog(@"Exception during bridge invocation: %@", exc);
        if (exception) {
            *exception = [exc convertToJSExceptionInContext: ctx];
        }
    }
    if (failed) {
        return JSValueMakeUndefined(ctx);
    }
    if (retval == NULL) {
        return JSValueMakeNull(ctx);
    }
    return retval;
}
@end
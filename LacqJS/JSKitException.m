//
//  JSKitException.m
//  JSKit
//
//  Created by glenn andreas on 3/27/08.
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
#import "JSKitException.h"
#import "JSKitObject.h"
#import "JSKitInterpreter.h"
#import "JSKitWrappers.h"
NSString * const LQJSKitException = @"LQJSException";
NSString * const LQJSKitErrorDomain = @"LQJSErrorDomain";
NSString * const LQJSKitErrorObjectKey = @"LQJSErrorObjectKey";


@implementation NSObject(LQJSKitException)
- (JSValueRef) convertToJSExceptionInContext: (JSContextRef) ctx
{
    JSObjectRef retval = JSObjectMake(ctx, NULL, NULL);
    JSStringRef propName = JSStringCreateWithCFString((CFStringRef)@"name");
    JSStringRef propString = JSStringCreateWithCFString((CFStringRef)@"ObjectiveCException");
    JSValueRef propValue = JSValueMakeString(ctx, propString);
    JSObjectSetProperty(ctx, retval, propName, propValue, 0, nil);
    JSStringRelease(propString);
    JSStringRelease(propName);
    propName = JSStringCreateWithCFString((CFStringRef)@"message");
    propString = JSStringCreateWithCFString((CFStringRef)[self description]);
    propValue = JSValueMakeString(ctx, propString);
    JSObjectSetProperty(ctx, retval, propName, propValue, 0, nil);
    JSStringRelease(propString);
    JSStringRelease(propName);
    return retval;
}
@end

@implementation NSException(LQJSKitException)
+ (void) raiseLQJSKitException: (JSValueRef) excobj inContext: (JSContextRef) ctx
{
    if (JSValueGetType(ctx, excobj) == kJSTypeObject) {
	LQJSKitObject *jsko = [[LQJSKitObject alloc] initWithObject:(JSObjectRef)excobj context:ctx];
	[self raise: LQJSKitException format: @"%@:%@",[jsko valueForKey: @"name"], [jsko valueForKey: @"message"]];
    } else {
	[self raise: LQJSKitException format: @"%@",[LQJSKitInterpreter convertJSValueRef:excobj context:ctx]];
    }
}
- (JSValueRef) convertToJSExceptionInContext: (JSContextRef) ctx
{
    JSObjectRef retval = JSObjectMake(ctx, NULL, NULL);
    JSStringRef propName = JSStringCreateWithCFString((CFStringRef)@"name");
    JSStringRef propString = JSStringCreateWithCFString((CFStringRef)[self name]);
    JSValueRef propValue = JSValueMakeString(ctx, propString);
    JSObjectSetProperty(ctx, retval, propName, propValue, 0, nil);
    JSStringRelease(propString);
    JSStringRelease(propName);
    propName = JSStringCreateWithCFString((CFStringRef)@"message");
    propString = JSStringCreateWithCFString((CFStringRef)[self reason]);
    propValue = JSValueMakeString(ctx, propString);
    JSObjectSetProperty(ctx, retval, propName, propValue, 0, nil);
    JSStringRelease(propString);
    JSStringRelease(propName);
    // add in the user info?
    if ([self userInfo]) {
	propName = JSStringCreateWithCFString((CFStringRef)@"userInfo");
	JSObjectSetProperty(ctx, retval, propName, [[self userInfo] convertToJSValueRefWithContext: ctx], 0, nil);
	JSStringRelease(propName);
    }
    return retval;
}

@end

@implementation NSError(LQJSKitException)
+ (id) errorWithLQJSKitException: (JSValueRef) excobj inContext: (JSContextRef) ctx
{
    if (JSValueGetType(ctx, excobj) == kJSTypeObject) {
        LQJSKitObject *jsko = [[LQJSKitObject alloc] initWithObject:(JSObjectRef)excobj context:ctx];
        
        id line = [jsko valueForKey:@"line"];
        NSString *desc = (line) ? [NSString stringWithFormat: @"%@: %@ (on line %@)",[jsko valueForKey: @"name"], [jsko valueForKey: @"message"], [line description]]
                                : [NSString stringWithFormat: @"%@: %@",[jsko valueForKey: @"name"], [jsko valueForKey: @"message"]];
        
        return [self errorWithDomain: LQJSKitErrorDomain code: 0 userInfo:
                    [NSDictionary dictionaryWithObjectsAndKeys:
                        desc, NSLocalizedDescriptionKey,
                        jsko, LQJSKitErrorObjectKey,
                        nil]];
    } else {
        id obj = [LQJSKitInterpreter convertJSValueRef:excobj context:ctx];
        return [self errorWithDomain: LQJSKitErrorDomain code: 0 userInfo:
                    [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSString stringWithFormat: @"%@",obj], NSLocalizedDescriptionKey,
                        obj, LQJSKitErrorObjectKey,
                        nil]];
    }
}
@end



//
//  JSKitInternal.m
//  JSKit
//
//  Created by glenn andreas on 4/7/08.
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

#import "JSKitInternal.h"
#import "JSKitWrappers.h"

@interface NSObject (LQJSKitBridgeObjectOwner)
- (id)objcOwnerOfJSObject;
@end


void LQJSKitNSObjectFinalizeCallback (JSObjectRef object)
{
    id nsobj = JSObjectGetPrivate(object);
    
    if ( !nsobj) return;
    
    ///NSLog(@"%s: obj is %@ -- has objcOwner method: %i -- owner %@", __func__, nsobj, ([nsobj respondsToSelector:@selector(objcOwnerOfJSObject)]),
    ///    (([nsobj respondsToSelector:@selector(objcOwnerOfJSObject)]) ? [nsobj objcOwnerOfJSObject] : nil));
    
    if ([nsobj respondsToSelector:@selector(objcOwnerOfJSObject)] && [nsobj objcOwnerOfJSObject] != nil) {
        // this object is owned by someone on the Obj-C side, so mustn't release it
    } else {
        [nsobj release];
    }
}

JSValueRef LQJSKitNSObjectConvertToTypeCallback(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    //NSLog(@"%s, obj %p, type %ld, nsobj class %@", __func__, object, (long)type, [nsobj class]);
    switch (type) {
	case kJSTypeUndefined:
	    return JSValueMakeUndefined(ctx);
	case kJSTypeNull:
	    return JSValueMakeNull(ctx);
	case kJSTypeBoolean:
            if ([nsobj respondsToSelector:@selector(jskitAsBoolean)]) {
                return JSValueMakeBoolean(ctx, [nsobj jskitAsBoolean]);
            } else {
                return NULL;
            }
	case kJSTypeNumber:
            if ([nsobj respondsToSelector:@selector(jskitAsNumber)]) {
                return JSValueMakeNumber(ctx, [nsobj jskitAsNumber]);
            } else {
                return NULL;
            }
    case kJSTypeSymbol: {
        NSString *str = [nsobj jskitAsString];
        if ( !str) str = [[nsobj class] description];
        JSStringRef string = JSStringCreateWithCFString((CFStringRef)str);
        JSValueRef retval = JSValueMakeSymbol(ctx, string);
        JSStringRelease(string);
        return retval;

    }
	case kJSTypeString: {
        //NSLog(@"convert to js string: %p / %@, strlen %ld", nsobj, [nsobj class], (long)[[nsobj jskitAsString] length]);
        NSString *str = [nsobj jskitAsString];
        if ( !str) str = [[nsobj class] description];
	    JSStringRef string = JSStringCreateWithCFString((CFStringRef)str);
	    JSValueRef retval = JSValueMakeString(ctx, string);
	    JSStringRelease(string);
	    return retval;
	}
    case kJSTypeObject:
        return object;
    }
}


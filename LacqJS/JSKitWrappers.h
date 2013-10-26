//
//  JSKitWrappers.h
//  jsci
//
//  Created by glenn andreas on 3/25/08.
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

#import <Foundation/Foundation.h>
#import "JSKitTypes.h"
@class JSKitInterpreter;

@interface NSObject(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context;
- (NSString *) jskitIntrospect;
- (BOOL) jskitAsBoolean;
- (double) jskitAsNumber;
- (NSString *) jskitAsString;
@end
@interface NSNumber(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context;
@end
@interface NSString(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context;
@end
@interface NSNull(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context;
@end
@interface NSArray(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context;
@end
@interface NSDictionary(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context;
@end


// Convert from JS to NS subclass
@interface LQJSKitStringWrapper : NSString {
    JSStringRef myJSString;
}
- (id) initWithJSString: (JSStringRef) jsString;

@end


@interface LQJSKitArrayWrapper : NSArray {
    JSObjectRef myObject;
    JSContextRef myContext;
    BOOL _isProtected;
}
- (id) initWithObject: (JSObjectRef) jsObject context: (JSContextRef) context;

- (void)addObject:(id)obj;
- (void)addObjectsFromArray:(NSArray *)array;

- (BOOL)isProtected;
- (void)setProtected:(BOOL)f;

@end


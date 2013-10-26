//
//  JSKitException.h
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

#import <Foundation/Foundation.h>
#include "JSKitObject.h"


extern NSString * const LQJSKitException;

@interface NSObject(LQJSKitException)
- (JSValueRef) convertToJSExceptionInContext: (JSContextRef) ctx;
@end

@interface NSException(LQJSKitException)
+ (void) raiseLQJSKitException: (JSValueRef) excobj inContext: (JSContextRef) ctx;
- (JSValueRef) convertToJSExceptionInContext: (JSContextRef) ctx;
@end

extern NSString * const LQJSKitErrorDomain;
extern NSString * const LQJSKitErrorObjectKey; // the JSKObject of the exception
@interface NSError(LQJSKitException)
+ (id) errorWithLQJSKitException: (JSValueRef) excobj inContext: (JSContextRef) ctx;
@end

#define LQJSKitHandleException(exception, error) \
if (exception) { \
  if (error) { \
    *error = [NSError errorWithLQJSKitException:exception inContext:myContext]; \
    return nil; \
  } else { \
    [NSException raiseLQJSKitException:exception inContext:myContext]; \
  } \
}

//
//  JSKitInternal.h
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

// These routines are not intended to be seen by consumer apps
// (At the very least, they will introduce a hard requirement to JavaScriptCore which will prevent 10.4u SDK)

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

/*!
     @function  JSKitNSObjectFinalizeCallback
     @abstract   A standard finalization callback for JSObjectRef's that wrap NSObject's
     @discussion Releases the reference to the wrapped NSObject.  Set in JSClassRef.
     @param      object The JSObjectRef wrapper object
     @result     none
*/
extern void LQJSKitNSObjectFinalizeCallback (JSObjectRef object);

/*!
    @function	JSKitNSObjectConvertToTypeCallback
    @abstract   Converts a wrapped NSObject to a different JSType
    @discussion Used in the JavaScript type conversion
    @param      ctx The current context
		object The JSObjectRef wrapper object
		type What to convert to
		exception Problem that occured (unused)
    @result     A new JSValue ref with the cooerced type
*/

extern JSValueRef LQJSKitNSObjectConvertToTypeCallback(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception);


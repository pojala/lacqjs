/*
 *  JSKitTypes.h
 *  JSKit
 *
 *  Created by glenn andreas on 4/7/08.
 *    Copyright (C) 2008 gandreas software. 
 *    Permission is hereby granted, free of charge, to any person
 *    obtaining a copy of this software and associated documentation
 *    files (the "Software"), to deal in the Software without
 *    restriction, including without limitation the rights to use,
 *    copy, modify, merge, publish, distribute, sublicense, and/or sell
 *    copies of the Software, and to permit persons to whom the
 *    Software is furnished to do so, subject to the following
 *    conditions:
 *
 *    The above copyright notice and this permission notice shall be
 *    included in all copies or substantial portions of the Software.
 *
 *    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 *    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 *    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 *    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 *    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *    OTHER DEALINGS IN THE SOFTWARE.
 *
 */

// property types to match those in JSObjectRef.h (added by Pauli Ojala)
enum { 
    kLQJSKitPropertyAttributeNone         = 0,
    kLQJSKitPropertyAttributeReadOnly     = 1 << 1,
    kLQJSKitPropertyAttributeDontEnum     = 1 << 2,
    kLQJSKitPropertyAttributeDontDelete   = 1 << 3
};
typedef unsigned LQJSKitPropertyAttributes;



#ifdef __APPLE__

#import <JavaScriptCore/JavaScriptCore.h>
/*
#if !defined(JSBase_h)
// Define JS types so the client doesn't have to try to include JavaScriptCore.h (which isn't part of the 10.4u SDK)
typedef const struct OpaqueJSContext* JSContextRef;
typedef struct OpaqueJSContext* JSGlobalContextRef;
typedef struct OpaqueJSString* JSStringRef;
typedef struct OpaqueJSClass* JSClassRef;
typedef struct OpaqueJSPropertyNameArray* JSPropertyNameArrayRef;
typedef struct OpaqueJSPropertyNameAccumulator* JSPropertyNameAccumulatorRef;
typedef const struct OpaqueJSValue* JSValueRef;
typedef struct OpaqueJSValue* JSObjectRef;
#endif
*/


#elif defined(__COCOTRON__)
// --- Cocotron support added by Pauli Ojala ---


// these are not included in MinGW
#define fseeko(_stream_, _offset_, _wh_)  fseek(_stream_, _offset_, _wh_)
#define ftello(_stream_)  ftell(_stream_)

// we don't link against AppKit, so these must be defined
#define NSFontAttributeName  @"NSFontAttributeName"
#define NSForegroundColorAttributeName @"NSForegroundColorAttributeName"

// on Cocotron, there is no CFString type, we can just define it to NSString *
#ifndef COCOTRON_CFSTRING_DEFINED
 #define CFStringRef NSString *
 #define CFRelease(_obj_) [_obj_ release]
 
 #define kCFAllocatorDefault NULL
 
 #define COCOTRON_CFSTRING_DEFINED 1
#endif

#include <JavaScriptCore/JavaScriptCore.h>



#else
#error Platform not supported yet
#endif

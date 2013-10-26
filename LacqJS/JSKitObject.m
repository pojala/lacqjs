//
//  JSKitObject.m
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
#import <JavaScriptCore/JavaScriptCore.h>
#import <Foundation/Foundation.h>

#import "JSKitObject.h"
#import "JSKitInterpreter.h"
#import "JSKitException.h"

@implementation LQJSKitObject
- (id) initWithObject: (JSObjectRef) jsObject context: (JSContextRef) context
{
    if (jsObject == nil) {
	[self release];
	return nil;
    }
    self = [super init];
    if (self) {
	myObject = jsObject;
	myContext = context;
	///JSValueProtect(myContext, myObject);
    
    ///NSLog(@"%s: %p (obj %p, ctx %p); description: %@", __func__, self, myObject, myContext, self);
    }
    return self;
}
- (void) dealloc
{
    ///NSLog(@"%s: %p (obj %p, ctx %p; isProtected %i)", __func__, self, myObject, myContext, _isProtected);
    ///if (myContext && myObject) JSValueUnprotect(myContext, myObject);
    if (_isProtected && myContext && myObject) JSValueUnprotect(myContext, myObject);
    
    [super dealloc];
}

// protected methods added by Pauli Ojala
- (BOOL)isProtected {
    return _isProtected;  }
    
- (void)setProtected:(BOOL)f
{
    if (f && !_isProtected) {
        JSValueProtect(myContext, myObject);
    } else if ( !f && _isProtected) {
        JSValueUnprotect(myContext, myObject);
    }
    _isProtected = f;
}


- (JSObjectRef) jsObjectRef {
    return myObject;
}

- (JSContextRef)jsContextRef {
    return myContext;
}

- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    return myObject;
}
- (NSString *) description
{
    JSStringRef resultStringJS = JSValueToStringCopy(myContext, myObject, NULL);
    CFStringRef resultString = JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
    JSStringRelease(resultStringJS);
    return [(NSString *)resultString autorelease];
}
- (NSString *) debugDescription
{
    return [NSString stringWithFormat: @"LQJSKitObject<%p %@>", myObject, [self description]];
}


- (id) valueForKey: (NSString *) key // returns nil if there is no such property
{
    JSStringRef propertyName = JSStringCreateWithCFString((CFStringRef)key);
    if (JSObjectHasProperty(myContext, myObject, propertyName)) {
	JSValueRef value = JSObjectGetProperty(myContext, myObject, propertyName, NULL);
	JSStringRelease(propertyName);
	return [LQJSKitInterpreter convertJSValueRef:value context: myContext];
    } else {
	JSStringRelease(propertyName);
	return nil;
    }
}

// this alternately named implementation added by Pauli Ojala: this method is available in LQJSBridgeObject,
// so it makes sense to provide it here
- (id)propertyForKey:(NSString *)key // returns nil if there is no such property
{
    JSStringRef propertyName = JSStringCreateWithCFString((CFStringRef)key);
    if (JSObjectHasProperty(myContext, myObject, propertyName)) {
	JSValueRef value = JSObjectGetProperty(myContext, myObject, propertyName, NULL);
	JSStringRelease(propertyName);
	return [LQJSKitInterpreter convertJSValueRef:value context: myContext];
    } else {
	JSStringRelease(propertyName);
	return nil;
    }
}

// added by Pauli Ojala -- throwing exceptions here seems worthless
- (id)valueForUndefinedKey:(NSString *)key
{
    return nil;
}


- (void)setValue:(id)value forKey:(NSString *)key
{
    JSStringRef propertyName = JSStringCreateWithCFString((CFStringRef)key);
    if (value == nil) {
	JSObjectDeleteProperty(myContext, myObject, propertyName, NULL);
    } else {
	JSValueRef valueRef = [LQJSKitInterpreter createJSValueRef:value context: myContext];
	JSObjectSetProperty(myContext, myObject, propertyName, valueRef, kJSPropertyAttributeNone, NULL);
    }
    JSStringRelease(propertyName);
}

// added by Pauli Ojala
- (void)setProperty:(id)value forKey:(NSString *)key options:(LQJSKitPropertyAttributes)propAttrs
{
    JSStringRef propertyName = JSStringCreateWithCFString((CFStringRef)key);
    if (value == nil) {
        JSObjectDeleteProperty(myContext, myObject, propertyName, NULL);
    } else {
        JSValueRef valueRef = [LQJSKitInterpreter createJSValueRef:value context:myContext];
        JSObjectSetProperty(myContext, myObject, propertyName, valueRef, propAttrs, NULL);
    }
    JSStringRelease(propertyName);
}


- (NSArray *) allKeys
{
    JSPropertyNameArrayRef props = JSObjectCopyPropertyNames(myContext, myObject);
    size_t count = JSPropertyNameArrayGetCount(props);
    size_t i;
    NSMutableArray *retval = [NSMutableArray arrayWithCapacity: count];
    for (i = 0;i<count;i++) {
	JSStringRef propName = JSPropertyNameArrayGetNameAtIndex(props, i);
	CFStringRef cfName = JSStringCopyCFString(kCFAllocatorDefault, propName);
	[retval addObject: (NSString *)cfName];
	CFRelease(cfName);
    }
    return retval;
}

// added by Pauli Ojala, 2009.07.15
- (NSEnumerator *) keyEnumerator
{
    return [[self allKeys] objectEnumerator];
}

- (NSInteger)count {
    return [[self allKeys] count];
}

- (NSString *) jskitIntrospect
{
    NSMutableString *retval = [NSMutableString string];
    if (JSObjectIsFunction(myContext, myObject)) {
	[retval appendFormat: @"function "];
    } else if (JSObjectIsConstructor(myContext, myObject)) {
	[retval appendFormat: @"constructor "];
    } else {
	[retval appendFormat: @"object "];
    }
    [retval appendFormat: @"{\n"];
    JSPropertyNameArrayRef props = JSObjectCopyPropertyNames(myContext, myObject);
    size_t count = JSPropertyNameArrayGetCount(props);
    size_t i;
    for (i = 0;i<count;i++) {
	JSStringRef propName = JSPropertyNameArrayGetNameAtIndex(props, i);
	CFStringRef cfName = JSStringCopyCFString(kCFAllocatorDefault, propName);
	[retval appendFormat: @"\t%@ = ", cfName];
	CFRelease(cfName);
	JSValueRef value = JSObjectGetProperty(myContext, myObject, propName, NULL);
	NSString *valueStr = [[LQJSKitInterpreter convertJSValueRef:value context: myContext] jskitIntrospect];
	// indent the thing
	[retval appendFormat: @"%@;\n", [[valueStr componentsSeparatedByString:@"\n"] componentsJoinedByString:@"\n\t"]];
    }
    [retval appendFormat: @"}"];
    return retval;
}

+ (LQJSKitObject *) objectWithObject:(JSObjectRef) jsObject context: (JSContextRef) context
{
    id nsobj = JSObjectGetPrivate(jsObject);
    if (nsobj)
	return nsobj;
    return [[[self alloc] initWithObject: jsObject context: context] autorelease];
}

- (BOOL) isFunction
{
    return JSObjectIsFunction(myContext, myObject);
}
- (BOOL) isConstructor
{
    return JSObjectIsConstructor(myContext, myObject);
}
- (BOOL) isConstructedBy: (LQJSKitObject *) constructor
{
    return JSValueIsInstanceOfConstructor(myContext, myObject, [constructor jsObjectRef], NULL);
}

- (LQJSKitObject *) constructor
{
    return [self valueForKey: @"constructor"];
}


- (id) callWithParameters:  (NSArray*) param error: (NSError **)error
{
    JSValueRef exception = nil;
    size_t argumentCount = [param count];
    JSValueRef arguments[argumentCount];
    int i;
    for (i=0;i<argumentCount;i++) {
        arguments[i] = [[param objectAtIndex: i] convertToJSValueRefWithContext:myContext];
    }
    JSValueRef retval = JSObjectCallAsFunction(myContext, myObject, myObject, argumentCount, (argumentCount > 0) ? arguments : NULL, &exception);
    LQJSKitHandleException(exception,error);    
    return [LQJSKitInterpreter convertJSValueRef:retval context:myContext];
}

- (id) callWithThis: (LQJSKitObject *) thisObject parameters:  (NSArray*) param error: (NSError **)error
{
    JSValueRef exception = nil;
    size_t argumentCount = [param count];
    JSValueRef arguments[argumentCount];
    int i;
    for (i=0;i<argumentCount;i++) {
        arguments[i] = [[param objectAtIndex:i] convertToJSValueRefWithContext:myContext];
    }
    JSValueRef retval = JSObjectCallAsFunction(myContext, myObject, [thisObject jsObjectRef], argumentCount, (argumentCount > 0) ? arguments : NULL, &exception);
    LQJSKitHandleException(exception,error);
    return [LQJSKitInterpreter convertJSValueRef:retval context:myContext];
}

// added by Pauli Ojala, 2009.11.25
- (id) callAndProtectResultWithThis: (LQJSKitObject *) thisObject parameters:  (NSArray*) param error: (NSError **)error
{
    JSValueRef exception = nil;
    size_t argumentCount = [param count];
    JSValueRef arguments[argumentCount];
    int i;
    for (i=0;i<argumentCount;i++) {
        arguments[i] = [[param objectAtIndex:i] convertToJSValueRefWithContext:myContext];
    }
    JSValueRef retval = JSObjectCallAsFunction(myContext, myObject, [thisObject jsObjectRef], argumentCount, (argumentCount > 0) ? arguments : NULL, &exception);
    LQJSKitHandleException(exception,error);
    id retObj = [LQJSKitInterpreter convertJSValueRef:retval context:myContext];
    [retObj setProtected:YES];
    return retObj;
}


- (id) callMethod: (NSString *) name withParameters:  (NSArray*) param error: (NSError **)error
{
    JSStringRef propertyName = JSStringCreateWithCFString((CFStringRef)name);
    if (JSObjectHasProperty(myContext, myObject, propertyName)) {
        JSValueRef method = JSObjectGetProperty(myContext, myObject, propertyName, NULL);
        JSStringRelease(propertyName);
        
        if (method && JSValueGetType(myContext, method) == kJSTypeObject && JSObjectIsFunction(myContext, (JSObjectRef)method)) {
            JSValueRef exception = nil;
            size_t argumentCount = [param count];
            JSValueRef arguments[argumentCount];
            int i;
            for (i=0;i<argumentCount;i++) {
                arguments[i] = [[param objectAtIndex: i] convertToJSValueRefWithContext:myContext];
            }
            JSValueRef retval = JSObjectCallAsFunction(myContext, (JSObjectRef)method, myObject, argumentCount, (argumentCount > 0) ? arguments : NULL, &exception);
            LQJSKitHandleException(exception,error);
            return [LQJSKitInterpreter convertJSValueRef:retval context:myContext];
        }
        return nil;
    } else {
        JSStringRelease(propertyName);
        return nil;
    }    
}

- (id) constructWithParameters:  (NSArray*) param error: (NSError **)error
{
    JSValueRef exception = nil;
    size_t argumentCount = [param count];
    JSValueRef arguments[(argumentCount > 0) ? argumentCount : 1];  // VLA safety
    int i;
    for (i=0;i<argumentCount;i++) {
	arguments[i] = [[param objectAtIndex: i] convertToJSValueRefWithContext:myContext];
    }
    //NSLog(@"... constructing %@, arg count is %ld", self, (long)argumentCount);
    JSValueRef retval = JSObjectCallAsConstructor(myContext, myObject, argumentCount, (argumentCount > 0) ? arguments : NULL, &exception);
    LQJSKitHandleException(exception,error);
    return [LQJSKitInterpreter convertJSValueRef:retval context:myContext];
}
- (LQJSKitObject *) prototype
{
    return [LQJSKitInterpreter convertJSValueRef: JSObjectGetPrototype(myContext, myObject) context: myContext];
}
- (void) setPrototype: (LQJSKitObject *) prototype
{
    JSObjectSetPrototype(myContext, myObject, [prototype jsObjectRef]);
}
@end



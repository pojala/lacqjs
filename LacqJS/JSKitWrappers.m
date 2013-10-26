//
//  JSKitWrappers.m
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
#import "JSKitInternal.h"
#import "JSKitWrappers.h"
////#import "JSKitBridgeObject.h"
#import "LQJSInterpreter.h"


// 2009.12.21 -- optionally detected JSON string method added by Pauli Ojala
@interface NSObject (LQJSONMethods)
- (NSString *)stringWithObject:(id)value error:(NSError **)error;
- (void)setAllowsUnknownObjects:(BOOL)f;
- (void)setHumanReadable:(BOOL)f;
@end


// 2012.08.25 -- static data and callbacks collected in one place

JSStringRef s_lengthStr = NULL;
JSStringRef s_ArrayStr = NULL;
static JSClassRef s_kvobjectClassRef = NULL;
static JSClassRef s_arrayClassRef = NULL;
JSClassRef s_invocationClassRef = nil;


JSValueRef LQJSKitNSArrayGetPropertyCallback(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);

JSValueRef LQJSKitNSObjectGetPropertyCallback(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);

void LQJSKitNSObjectGetPropertyNamesCallback(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames);

extern JSValueRef LQJSKitInvocationCallback(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                            size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);

JSValueRef LQJSKitNSArrayToString(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
JSValueRef LQJSKitNSArrayPush(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
JSValueRef LQJSKitNSArraySlice(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
JSValueRef LQJSKitNSArrayToNativeArray(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);


void LQJSKitWrappers_initStatics()
{
    if ( !s_lengthStr)
        s_lengthStr = JSStringCreateWithCFString((CFStringRef)@"length");
    
    if ( !s_ArrayStr)
        s_ArrayStr = JSStringCreateWithCFString((CFStringRef)@"Array");
    
    if ( !s_kvobjectClassRef)  {
        JSClassDefinition kvobjectBridgeClassDef = kJSClassDefinitionEmpty;
        kvobjectBridgeClassDef.className = "LQJS_NativeObject";
        kvobjectBridgeClassDef.getProperty = LQJSKitNSObjectGetPropertyCallback;
        kvobjectBridgeClassDef.getPropertyNames = LQJSKitNSObjectGetPropertyNamesCallback;
        kvobjectBridgeClassDef.finalize = LQJSKitNSObjectFinalizeCallback;
        kvobjectBridgeClassDef.convertToType = (JSObjectConvertToTypeCallback)LQJSKitNSObjectConvertToTypeCallback;
        s_kvobjectClassRef = JSClassCreate(&kvobjectBridgeClassDef);
        JSClassRetain(s_kvobjectClassRef);
    }
    
    if ( !s_arrayClassRef)  {
        JSClassDefinition arrayBridgeClassDef = kJSClassDefinitionEmpty;
        arrayBridgeClassDef.className = "LQJS_NativeArray";
        //  arrayBridgeClassDef.hasProperty = LQJSKitNSArrayHasPropertyCallback;
        //  arrayBridgeClassDef.setProperty = LQJSKitNSArraySetPropertyCallback;
        arrayBridgeClassDef.getProperty = LQJSKitNSArrayGetPropertyCallback;
        //  arrayBridgeClassDef.getPropertyNames = LQJSKitNSArrayGetPropertyNamesCallback;
        arrayBridgeClassDef.finalize = LQJSKitNSObjectFinalizeCallback;
        arrayBridgeClassDef.convertToType = LQJSKitNSObjectConvertToTypeCallback;
        
        JSStaticFunction funcs[] = { { "toString",  LQJSKitNSArrayToString, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete },
            { "slice",     LQJSKitNSArraySlice,    kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete },
            { "push",     LQJSKitNSArrayPush,    kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete },
            { "toNative",  LQJSKitNSArrayToNativeArray, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete },
            { NULL, NULL, 0 }
        };
        
        arrayBridgeClassDef.staticFunctions = funcs;
        
        /**((char **)&staticFunctionArray->name) = strdup("slice");
         staticFunctionArray->callAsFunction = LQJSKitNSArraySlice;
         staticFunctionArray->attributes = kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete;
         staticFunctionArray++;
         ///NSLog(@"created slice JS func");
         */
        
        s_arrayClassRef = JSClassCreate(&arrayBridgeClassDef);
        JSClassRetain(s_arrayClassRef);
    }
    
    if ( !s_invocationClassRef)  {
        JSClassDefinition invocationBridgeClassDef = kJSClassDefinitionEmpty;
        invocationBridgeClassDef.className = "LQJS_Invocation";
        invocationBridgeClassDef.callAsFunction = LQJSKitInvocationCallback;
        invocationBridgeClassDef.finalize = LQJSKitNSObjectFinalizeCallback;
        s_invocationClassRef = JSClassCreate(&invocationBridgeClassDef);
        JSClassRetain(s_invocationClassRef);
    }
}



@implementation NSObject(LQJSKitWrapper)

JSValueRef LQJSKitNSObjectGetPropertyCallback (JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    CFStringRef cfstring = JSStringCopyCFString(nil, propertyName);
    JSValueRef retval = nil;
    @try
    {
        id value = [nsobj valueForKeyPath:(NSString *)cfstring];
        retval = [value convertToJSValueRefWithContext:ctx];
    }
    @catch(NSException * e)
    {
        retval = JSValueMakeUndefined(ctx);
    }
    CFRelease(cfstring);
    return retval; ///(retval) ? retval : JSValueMakeUndefined(ctx);
}

void LQJSKitNSObjectGetPropertyNamesCallback (JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames)
{
    id nsobj = JSObjectGetPrivate(object);
    
    if ([nsobj respondsToSelector:@selector(keyEnumerator)]) {
        NSEnumerator *keyEnum = [nsobj keyEnumerator];
        id key;
        while (key = [keyEnum nextObject]) {
            JSStringRef str = JSStringCreateWithCFString((CFStringRef)[key description]);
            JSPropertyNameAccumulatorAddName(propertyNames, str);
            JSStringRelease(str);
        }
    }
}

- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    if ( !s_kvobjectClassRef) LQJSKitWrappers_initStatics();
    
    JSObjectRef retval = JSObjectMake(context, s_kvobjectClassRef, [self retain]);
    return retval;
}
- (NSString *) jskitIntrospect
{
    return [self description];
}
- (BOOL) jskitAsBoolean
{
    return YES;
}
- (double) jskitAsNumber
{
    return 0;
}
- (NSString *) jskitAsString
{
    return [self description];
}
@end

@implementation NSNull(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    return JSValueMakeNull(context);
}
- (NSString *) jskitIntrospect
{
    return @"null";
}
- (BOOL) jskitAsBoolean
{
    return NO;
}

@end
@implementation NSNumber(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    const char *ctype = [self objCType];
    
    if (ctype && strcmp(ctype, @encode(BOOL)) == 0) {
        return JSValueMakeBoolean(context, [self boolValue]);
    }
    return JSValueMakeNumber(context, [self doubleValue]);
}

- (NSString *) jskitIntrospect
{
    const char *ctype = [self objCType];
    
    if (ctype && strcmp(ctype, @encode(BOOL)) == 0) {
        return ([self boolValue]) ? @"true" : @"false";
    }
    return [self description];
}
- (BOOL) jskitAsBoolean
{
    return [self intValue] != 0;
}
- (double) jskitAsNumber
{
    return [self doubleValue];
}
@end
@implementation NSString(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)self);
    JSValueRef retval = JSValueMakeString(context, string);
    JSStringRelease(string);
    return retval;
}
- (BOOL) jskitAsBoolean
{
    return [self length] != 0;
}
- (double) jskitAsNumber
{
    return [self doubleValue];
}

@end

@implementation NSArray(LQJSKitWrapper)

- (NSString *)jskitAsString
{
    Class jsonCls = NSClassFromString(@"LQJSON");
    NSString *str = nil;
    if (jsonCls) {
        id gen = [[jsonCls alloc] init];
        [gen setAllowsUnknownObjects:YES];
        //[gen setHumanReadable:YES];
        str = [gen stringWithObject:self error:NULL];
        [gen release];
    }
    return (str) ? str : [self description];
}


static inline int readIndexFromJSString(JSStringRef s)
{
    long len = JSStringGetLength(s);
    if (len < 1 || len > 10) return -1;
    
    const JSChar *unichars = JSStringGetCharactersPtr(s);
    int v = 0;
    long i;
    for (i = 0; i < len; i++) {
        int uc = unichars[i];
        if (uc < '0' || uc > '9')
            return -1;
        
        if (uc > '0') {
            long k = (len - i);
            int e = 1;
            while (--k) {
                e *= 10;
            }            
            v += e * (uc - '0');
        }
    }
    return v;
}


JSValueRef LQJSKitNSArrayGetPropertyCallback (JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    NSString *cfstring = NULL; // (NSString *)JSStringCopyCFString(nil, propertyName);
    int index = 0;
    JSValueRef retval = NULL;  // this is the value expected by JSC if we don't have this property
    
    // If it's a number, try using it as an index
    index = readIndexFromJSString(propertyName);
    
    if (index > -1) {
        if (index < [nsobj count]) {
            id value = [nsobj objectAtIndex:index];
            retval = [value convertToJSValueRefWithContext:ctx];
        }
    }
    // Check for the standard JavaScript 'length' property    
    else if ((cfstring = (NSString *)JSStringCopyCFString(nil, propertyName)) && [cfstring isEqualToString:@"length"]) {    
        id value = [NSNumber numberWithLong:[nsobj count]];
        retval = [value convertToJSValueRefWithContext:ctx];
    }
    /*else if ([cfstring isEqualToString:@"toString"] || [cfstring isEqualToString:@"valueOf"]) {
        CFStringRef as = (CFStringRef)[nsobj jskitAsString];
        JSStringRef string = JSStringCreateWithCFString(as);
        retval = JSValueMakeString(ctx, string);
	    JSStringRelease(string);
    }
    // Resort to KVC    
    else {    
        ///NSLog(@"...%s: %@", __func__, cfstring);
        @try    
        {    
            id value = [nsobj valueForKeyPath:cfstring];    
            retval = [value convertToJSValueRefWithContext:ctx];    
        } @catch(NSException *e) {
            retval = NULL;
        }    
    }
    */
    if (cfstring) CFRelease((CFStringRef)cfstring);
    ///NSLog(@"....returning JSValue %p", retval);
    return retval;
}

// this method by Pauli Ojala, 2009.12.21
JSValueRef LQJSKitNSArrayToString(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    JSValueRef retval = NULL;
    
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)[nsobj jskitAsString]);
    retval = JSValueMakeString(ctx, string);
    JSStringRelease(string);

    return retval;
}

JSValueRef LQJSKitNSArrayPush(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    long i;
    for (i = 0; i < argumentCount; i++) {
        id aobj = [LQJSKitInterpreter convertJSValueRef:arguments[i] context:ctx];
        if ([nsobj respondsToSelector:@selector(addObject:)]) {
            if (aobj) [nsobj addObject:aobj];
        } else {
            nsobj = [[nsobj autorelease] mutableCopy];
            if (aobj) [nsobj addObject:aobj];
            JSObjectSetPrivate(object, nsobj);
        }
    }
    
    return object;
}

// this method by Pauli Ojala, 2009.12.21
JSValueRef LQJSKitNSArraySlice(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    long count = [nsobj count];
    
    NSArray *newArray = nil;
    if (argumentCount > 0) {
        long startIndex = JSValueToNumber(ctx, arguments[0], NULL);
        long endIndex = -1;
        if (argumentCount > 1) {
            endIndex = JSValueToNumber(ctx, arguments[1], NULL);
        }
        if (endIndex < 0 || endIndex > count)
            endIndex = count;
            
        newArray = [nsobj subarrayWithRange:NSMakeRange(startIndex, endIndex-startIndex)];
    }
    return [newArray convertToJSValueRefWithContext:ctx];
}

// this method by Pauli Ojala, 2009.12.21
JSValueRef LQJSKitNSArrayToNativeArray(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception)
{
    JSObjectRef globalObject = JSContextGetGlobalObject(ctx);
    id interpreter = JSObjectGetPrivate(globalObject);
    JSContextRef mainCtx = [interpreter jsContextRef];
    
    // create an Array object through its constructor
    JSStringRef propName = JSStringCreateWithCFString((CFStringRef)@"Array");
    JSValueRef ArrayObj = JSObjectGetProperty(mainCtx, globalObject, propName, NULL);
    JSStringRelease(propName);
    
    JSObjectRef newArray = JSObjectCallAsConstructor(ctx, (JSObjectRef)ArrayObj, 0, NULL, NULL);
    
    // add the objects from the NS array to the native array using its 'push' method
    propName = JSStringCreateWithCFString((CFStringRef)@"push");
    JSValueRef pushFunc = JSObjectGetProperty(ctx, (JSObjectRef)newArray, propName, NULL);
    JSStringRelease(propName);
    
    id nsobj = JSObjectGetPrivate(object);
    NSUInteger n = [nsobj count];
    NSUInteger i;
    for (i = 0; i < n; i++) {
        JSValueRef theObj = [[nsobj objectAtIndex:i] convertToJSValueRefWithContext:ctx];
        JSObjectCallAsFunction(ctx, (JSObjectRef)pushFunc, newArray, 1, &theObj, NULL);
    }
    
    return newArray;
}

- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    if ( !s_arrayClassRef) LQJSKitWrappers_initStatics();
    
    JSObjectRef retval = JSObjectMake(context, s_arrayClassRef, [self retain]);
    return retval;
}
- (BOOL) jskitAsBoolean
{
    return [self count] != 0;
}
@end
@implementation NSDictionary(LQJSKitWrapper)
- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    // use NSObject's KVC support
    return [super convertToJSValueRefWithContext:context];
}

- (NSString *)jskitAsString
{
    Class jsonCls = NSClassFromString(@"LQJSON");
    NSString *str = nil;
    if (jsonCls) {
        id gen = [[jsonCls alloc] init];
        [gen setAllowsUnknownObjects:YES];
        //[gen setHumanReadable:YES];
        str = [gen stringWithObject:self error:NULL];
        [gen release];
    }
    return (str) ? str : [self description];
}

- (BOOL) jskitAsBoolean
{
    return [self count] != 0;
}

@end



@implementation LQJSKitStringWrapper
- (id) initWithJSString: (JSStringRef) jsString
{
    self = [super init];
    if (self) {
	myJSString = jsString;
	JSStringRetain(myJSString);
    }
    return self;
}
- (void) dealloc
{
    if (myJSString)
	JSStringRelease(myJSString);
    [super dealloc];
}
- (NSUInteger)length
{
    return JSStringGetLength(myJSString);
}
- (unichar)characterAtIndex:(NSUInteger)index
{
    return JSStringGetCharactersPtr(myJSString)[index];
}

// implement a few other things for performance
- (void)getCharacters:(unichar *)buffer
{
    memcpy(buffer, JSStringGetCharactersPtr(myJSString), JSStringGetLength(myJSString) * sizeof(JSChar));
}
- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange
{
    if (aRange.length > 0) {
	NSAssert(aRange.location + aRange.length <= JSStringGetLength(myJSString), @"LQJSKitStringWrapper getCharacters:range: out of range");
	memcpy(buffer, JSStringGetCharactersPtr(myJSString) + aRange.location, aRange.length * sizeof(JSChar));    
    }
}
- (const char *)UTF8String	// Convenience to return null-terminated UTF8 representation
{
    NSMutableData *retval = [NSMutableData dataWithLength:JSStringGetMaximumUTF8CStringSize(myJSString)];
    JSStringGetUTF8CString(myJSString, (char *)[retval mutableBytes], [retval length]);
    return (const char *)[retval mutableBytes];
}

- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)lossy
{
    if (encoding == NSUTF8StringEncoding) {
	NSMutableData *retval = [NSMutableData dataWithLength:JSStringGetMaximumUTF8CStringSize(myJSString)];
	JSStringGetUTF8CString(myJSString, (char *)[retval mutableBytes], [retval length]);
	return retval;
    }
    return [super dataUsingEncoding:encoding allowLossyConversion:lossy];
}
- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding
{
    if (encoding == NSUTF8StringEncoding) {
	NSMutableData *retval = [NSMutableData dataWithLength:JSStringGetMaximumUTF8CStringSize(myJSString)];
	size_t actual = JSStringGetUTF8CString(myJSString, (char *)[retval mutableBytes], [retval length]);
	[retval setLength:actual];
	return retval;
    }
    return [super dataUsingEncoding:encoding];
}

@end


@implementation LQJSKitArrayWrapper
- (id) initWithObject: (JSObjectRef) jsObject context: (JSContextRef) context
{
    self = [super init];
    if (self) {
        myObject = jsObject;
        myContext = context;
        //JSValueProtect(myContext, myObject);
    }
    return self;
}
- (void) dealloc
{
    //if (myContext && myObject) JSValueUnprotect(myContext, myObject);
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

- (JSObjectRef)jsObjectRef {
    return myObject; }


- (NSUInteger)count
{
    if ( !s_lengthStr) LQJSKitWrappers_initStatics();

    JSValueRef count = JSObjectGetProperty(myContext, myObject, s_lengthStr, NULL);
    return JSValueToNumber(myContext, count, NULL);
}
- (id)objectAtIndex:(NSUInteger)index
{
    JSStringRef indexStr = JSStringCreateWithCFString((CFStringRef)[NSString stringWithFormat: @"%lu",(unsigned long)index]);
    JSValueRef retval = JSObjectGetProperty(myContext, myObject, indexStr, NULL);
    JSStringRelease(indexStr);
    
    id retobj = [LQJSKitInterpreter convertJSValueRef:retval context:myContext];
    
    if (retobj == nil && index < [self count]) {  // this can happen if the object is a JavaScript 'undefined', but we can't return a nil object from the array
        ///NSLog(@"JS array wrap %p: object at index %lu is 'undefined'", self, (unsigned long)index);
        retobj = [NSNull null];
    }
    return retobj;
}

- (void)addObject:(id)obj
{
    NSUInteger index = [self count];
    
    JSValueRef valueRef = [LQJSKitInterpreter createJSValueRef:obj context:myContext];
    
    if (valueRef) {
        JSStringRef indexStr = JSStringCreateWithCFString((CFStringRef)[NSString stringWithFormat: @"%lu",(unsigned long)index]);
        JSObjectSetProperty(myContext, myObject, indexStr, valueRef, kJSPropertyAttributeNone, NULL);
        JSStringRelease(indexStr);
    }
}

- (void)addObjectsFromArray:(NSArray *)array
{
    NSUInteger prevCount = [self count];
    NSUInteger addCount = [array count];
    
    NSUInteger i;
    for (i = 0; i < addCount; i++) {
        id obj = [array objectAtIndex:i];
        JSValueRef valueRef = [LQJSKitInterpreter createJSValueRef:obj context:myContext];
        
        if (valueRef) {
            JSStringRef indexStr = JSStringCreateWithCFString((CFStringRef)[NSString stringWithFormat: @"%lu",(unsigned long)(prevCount + i)]);
            JSObjectSetProperty(myContext, myObject, indexStr, valueRef, kJSPropertyAttributeNone, NULL);
            JSStringRelease(indexStr);
        }
    }
}

- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    return myObject;
}

@end

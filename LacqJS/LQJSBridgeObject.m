//
//  LQJSBridgeObject.m
//  JSKit
//
//  Created by Pauli Ojala on 8.10.2008.
//  Copyright 2008 Lacquer oy/ltd.
//
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
#import "LQJSBridgeObject.h"
#import "JSKitInternal.h"
#import "JSKitInterpreter.h"
#import "JSKitWrappers.h"
#import "JSKitException.h"
#import "JSKitInvocation.h"


#if 0
static NSString *LQJSKitBridgeCopyFunctionName(JSContextRef ctx, JSObjectRef function)
{
    JSStringRef nameProperty = JSStringCreateWithCFString((CFStringRef)@"name");
    JSValueRef name = JSObjectGetProperty(ctx, function, nameProperty, NULL);
    JSStringRef nameString = JSValueToStringCopy(ctx, name, NULL);
//    JSStringRef ctorname = JSValueToStringCopy(ctx, constructor, nil);
    CFStringRef cfstring = JSStringCopyCFString(nil, nameString);
    JSStringRelease(nameString);
    JSStringRelease(nameProperty);
    return (NSString *)cfstring;
}
#endif


@implementation LQJSBridgeObject

- (id)initInJSContext:(JSContextRef)context withOwner:(id)owner
{
    self = [super init];
    
    if (self) {
        _jsContext = context;
        _owner = owner;
        
        // if this object isn't owned by anybody on the Obj-C side, let the JSObject retain it;
        // else if there is an Obj-C owner, protect the JS object from being deleted by JS garbage collection
        if ( !_owner)
            [self retain];

        _jsObject = JSObjectMake(context, [[self class] jsClassRef], self);
    
        if (_owner)
            JSValueProtect(_jsContext, _jsObject);
    
        //NSLog(@"js bridge init: %@ (obj %p, ctx %p; owner is %@)", self, _jsObject, _jsContext, _owner);
    }
    return self;
}

- (void) awakeFromConstructor: (NSArray *) arguments
{
}

- (void) dealloc
{
    ///NSLog(@"js bridge dealloc: %p / %@; jsobject %p;   owner %p", self, [self class], _jsObject, _owner);

    if (_owner) {
        JSObjectSetPrivate(_jsObject, NULL);
        
        JSContextRef ctx = _jsContext;
        ///if ([_owner respondsToSelector:@selector(jsContextRef)]) ctx = [_owner jsContextRef];
        
        JSValueUnprotect(ctx, _jsObject);
    }
        
    _jsObject = NULL;
    ///_owner = nil;
    
    [super dealloc];
}

- (id)owner {
    return _owner; }

- (id)objcOwnerOfJSObject {
    return _owner; }

- (void)setOwner:(id)newOwner
{
    if (newOwner != _owner) {
        JSContextRef newCtx = _jsContext;
        if ([newOwner respondsToSelector:@selector(jsContextRef)]) newCtx = [newOwner jsContextRef];
        
        JSContextRef oldCtx = _jsContext;
        if ([_owner respondsToSelector:@selector(jsContextRef)]) oldCtx = [_owner jsContextRef];    
    
        if (newOwner && !_owner) {  // an Obj-C object is going to own us, so remove the reference in the JSObject
            JSValueProtect(newCtx, _jsObject);
            [self release];
            ///NSLog(@"%@ has become owned by ObjC object %@ in ctx %p", self, newOwner, newCtx);
        }
        else if ( !newOwner && _owner) {
            [self retain];
            JSValueUnprotect(oldCtx, _jsObject);
            ///NSLog(@"%@ is no longer owned by ObjC object %@ (old ctx %p)", self, _owner, oldCtx);
        }
        else if (newOwner && _owner) {
            if (newCtx != oldCtx) {
                JSValueUnprotect(oldCtx, _jsObject);
                JSValueProtect(newCtx, _jsObject);
            }
        }
        
        _owner = newOwner;
        _jsContext = newCtx;
    }
}

- (BOOL)jskitAsBoolean {
    return YES;
}
- (double)jskitAsNumber {
    return 0;
}
- (NSString *)jskitAsString {
    return [self description];
}

- (JSContextRef)jsContextRef {
    return _jsContext; }

- (JSObjectRef)jsObjectRef {
    return _jsObject; }

- (id)propertyForKey:(NSString *)key // returns nil if there is no such property
{
    JSStringRef propertyName = JSStringCreateWithCFString((CFStringRef)key);
    if (JSObjectHasProperty(_jsContext, _jsObject, propertyName)) {
        JSValueRef value = JSObjectGetProperty(_jsContext, _jsObject, propertyName, NULL);
        JSStringRelease(propertyName);
        
        return [LQJSKitInterpreter convertJSValueRef:value context:_jsContext];
    } else {
        JSStringRelease(propertyName);
        return nil;
    }
}

- (void)setProperty:(id)value forKey:(NSString *)key options:(LQJSKitPropertyAttributes)propAttrs
{
    JSStringRef propertyName = JSStringCreateWithCFString((CFStringRef)key);
    if (value == nil) {
        JSObjectDeleteProperty(_jsContext, _jsObject, propertyName, NULL);
    } else {
        JSValueRef valueRef = [LQJSKitInterpreter createJSValueRef:value context:_jsContext];
        JSObjectSetProperty(_jsContext, _jsObject, propertyName, valueRef, propAttrs, NULL);
    }
    JSStringRelease(propertyName);
}

- (id)callMethod:(NSString *)name withParameters:(NSArray *)param error:(NSError **)error
{
    JSStringRef propertyName = JSStringCreateWithCFString((CFStringRef)name);
    if (JSObjectHasProperty(_jsContext, _jsObject, propertyName)) {
        JSValueRef method = JSObjectGetProperty(_jsContext, _jsObject, propertyName, NULL);
        JSStringRelease(propertyName);
        
        if (method && JSValueGetType(_jsContext, method) == kJSTypeObject && JSObjectIsFunction(_jsContext, (JSObjectRef)method)) {
            JSValueRef exception = nil;
            size_t argumentCount = [param count];
            JSValueRef arguments[(argumentCount > 0) ? argumentCount : 1];  // VLA safety
            int i;
            for (i=0;i<argumentCount;i++) {
                arguments[i] = [[param objectAtIndex: i] convertToJSValueRefWithContext:_jsContext];
            }
            JSValueRef retval = JSObjectCallAsFunction(_jsContext, (JSObjectRef)method, _jsObject, argumentCount, (argumentCount > 0) ? arguments : NULL, &exception);
            #define myContext _jsContext
            LQJSKitHandleException(exception,error);
            #undef myContext
            return [LQJSKitInterpreter convertJSValueRef:retval context:_jsContext];
        }
        return nil;
    } else {
        JSStringRelease(propertyName);
        return nil;
    }
}


+ (NSString *) constructorName
{
    NSAssert(false, @"+[LQJSKitBridgeObject constructorName] must be overridden by subclass");
    return nil;
}
+ (NSArray *) objectPropertyNames // for KVO.  Note that property access goes through KVO
{
    return [NSArray array];
}
+ (NSArray *) objectFunctionNames // if  the function is named "foo" the selector called is "lqjsCallFoo:context:"
{
    return [NSArray array];
}
+ (JSClassRef) parentClass
{
    return NULL;
}
+ (BOOL) canWriteProperty: (NSString *) propertyName // defaults to YES
{
    return YES;
}
+ (BOOL) canDeleteProperty: (NSString *) propertyName // defaults to NO
{
    return NO;
}
+ (BOOL) canEnumProperty: (NSString *) propertyName // defaults to YES
{
    return YES;
}


// -- 2010.09.01 - these methods added by Pauli Ojala
//    to support JS array-style custom index getters and setters
//    (e.g. for Canvas API ImageData objects)

+ (BOOL)hasArrayIndexingGetter
{
    return NO;
}

+ (BOOL)hasArrayIndexingSetter
{
    return NO;
}

- (int)lengthForArrayIndexing
{
    return 0;
}

- (id)valueForArrayIndex:(int)index
{
    return nil;
}

- (void)setValue:(id)value forArrayIndex:(int)index
{
}

- (BOOL)isByteArray
{
    return NO;
}

- (uint8_t)byteValueForArrayIndex:(int)index
{
    return 0;
}

- (void)setByteValue:(uint8_t)b forArrayIndex:(int)index
{
}


static JSValueRef LQJSKitBridgeGetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    CFStringRef cfstring = JSStringCopyCFString(nil, propertyName);
    JSValueRef retval = NULL;
    id value = [nsobj valueForKey: (NSString *)cfstring];
    retval = [value convertToJSValueRefWithContext:ctx];
    CFRelease(cfstring);
    return retval;
}

static bool LQJSKitBridgeSetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef value, JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    CFStringRef cfstring = JSStringCopyCFString(nil, propertyName);
    id nsvalue = [LQJSKitInterpreter convertJSValueRef:value context:ctx];
    [nsobj setValue: nsvalue forKey: (NSString *)cfstring];
    CFRelease(cfstring);
    return YES;
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

static bool LQJSKitBridgeSetIndexedProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef value, JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    bool retval = NO;
    
    int index = 0;
    
    index = readIndexFromJSString(propertyName);
    
    ///CFStringRef cfstring = JSStringCopyCFString(nil, propertyName);
    ///if ([[NSScanner scannerWithString:(NSString *)cfstring] scanInt:&index] && index >= 0 && index < [nsobj lengthForArrayIndexing]) {
    if (index >= 0 && index < [nsobj lengthForArrayIndexing]) {
        if ([nsobj isByteArray]) {
            double num = JSValueToNumber(ctx, value, NULL);
            if (isfinite(num)) {
                uint8_t b = (uint8_t)num;
                [nsobj setByteValue:b forArrayIndex:index];
            }
        } else {
            id nsvalue = [LQJSKitInterpreter convertJSValueRef:value context:ctx];
            [nsobj setValue:nsvalue forArrayIndex:index];
        }
        retval = YES;
    }
    
    ///CFRelease(cfstring);
    return retval;
}

// since we can't get the function name (and thus the method name) out of the static function, we need to do this dynamically
JSValueRef LQJSKitBridgeGetPropertyCallback(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception)
{
    id nsobj = JSObjectGetPrivate(object);
    CFStringRef cfstring = NULL; //JSStringCopyCFString(nil, propertyName);
    JSValueRef retval = NULL;
    
    if ( !nsobj) {
        ///NSLog(@"** JS bridge object (%p, ctx %p) is missing implementation object (probably was dealloced prematurely) - property is '%@'", object, ctx, cfstring);
    }
    ///NSLog(@"%s (%p, ctx %p): property '%@' - nsobj is %@", __func__, object, ctx, cfstring, [nsobj class]);
    
    Class cls = [nsobj class];
    
    if ([cls hasArrayIndexingGetter]) {
        int len = [nsobj lengthForArrayIndexing];
        int index = 0;
        index = readIndexFromJSString(propertyName);
        if (index > -1) {
            if (index < len) {
                if ([nsobj isByteArray]) {
                    uint8_t b = [nsobj byteValueForArrayIndex:index];
                    retval = JSValueMakeNumber(ctx, b);
                } else {
                    id value = [nsobj valueForArrayIndex:index];
                    retval = [value convertToJSValueRefWithContext:ctx];
                }
            } else {
                retval = JSValueMakeUndefined(ctx);
            }
        }
        // check for the standard JavaScript 'length' property
        else if ((cfstring = JSStringCopyCFString(nil, propertyName)) && [(NSString *)cfstring isEqualToString:@"length"]) {
            id value = [NSNumber numberWithInt:len];
            retval = [value convertToJSValueRefWithContext:ctx];
        }
    }
    
    if ( !retval && !cfstring)
        cfstring = JSStringCopyCFString(nil, propertyName);
        
    if ( !retval && nsobj && [[cls objectFunctionNames] containsObject:(NSString *)cfstring]) {
        NSString *selString = [NSString stringWithFormat: @"lqjsCall%@%@:context:",
                                    [[(NSString *)cfstring substringToIndex:1] capitalizedString], [(NSString *)cfstring substringFromIndex:1]];
                                    
        //	return LQJSKitBridgeCallFunctionWithSelector(ctx, nsobj, NSSelectorFromString(selString));
        // in theory, one could do "f = obj.f; del obj;" which could remove the target, so keep it around
        
        SEL sel = NSSelectorFromString(selString);
        BOOL hasOwner = ([nsobj objcOwnerOfJSObject]) ? YES : NO;  // 2009.07.21 -- added by Pauli Ojala
        LQJSKitInvocation *inv = (hasOwner) ? [LQJSKitInvocation invocationWithNonRetainedTarget:nsobj action:sel]
                                            : [LQJSKitInvocation invocationWithRetainedTarget:nsobj action:sel];
        
        ///if (hasOwner) NSLog(@"object %@ has owner -- invocation for property %@ is not retained", nsobj, cfstring);
        
        retval = LQJSKitInvocationFunction(ctx, inv);
    }
    if (cfstring) CFRelease(cfstring);
    return retval;  ///(retval) ? retval : JSValueMakeUndefined(ctx);
}

JSObjectRef LQJSKitBridgeConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception)
{
    JSObjectRef globalObject = JSContextGetGlobalObject(ctx);
    id interpreter = JSObjectGetPrivate(globalObject);
    NSCAssert(interpreter, @"js context must have Obj-C interpreter");
    
#if 1
    Class cls = [interpreter bridgeClassForJSConstructor:constructor];
    if ( !cls) {
        NSLog(@"*** %s: unable to get bridge class for JS constructor (%p; ctx %p; interp %p) -- bridge is probably not loaded in this context",
                                __func__, constructor, ctx, interpreter);
        return nil;
    }
#else
    Class cls = [g_constructorMap objectForKey: [NSValue valueWithPointer:constructor]];
#endif

    ///NSLog(@"%s: context %p / interpreter is %@ -- constructor is %p -> class %@", __func__, ctx, interpreter, constructor, cls);

    // create all objects in the main ctx
    JSContextRef mainCtx = [interpreter jsContextRef];
    ctx = mainCtx;

    NSArray *args = [LQJSKitInterpreter convertJSValueRefs:arguments count:argumentCount context:ctx];
    
    id newInstance = [[[cls alloc] initInJSContext:ctx withOwner:nil] autorelease]; // a reference will be kept in the object
    
    [newInstance awakeFromConstructor:args];
        
    JSObjectRef retval = (JSObjectRef)[newInstance convertToJSValueRefWithContext: ctx];
    return retval;
}


// this global doesn't need to be context-specific,
// but we should protect it with a lock because it may be accessed on worker threads' interpreters
static NSMutableDictionary *g_classRefs = nil;
static NSLock *g_classRefLock = nil;

+ (id)_cachedClassRefValueForKey:(NSString *)name
{
    if ( !g_classRefs) {
        g_classRefs = [[NSMutableDictionary alloc] init];
        g_classRefLock = [[NSLock alloc] init];
    }
    id value = nil;
    [g_classRefLock lock];
    
    value = [g_classRefs objectForKey:name];
    
    [g_classRefLock unlock];
    return value;
}

+ (void)_cacheClassRefValue:(id)value forKey:(NSString *)key
{
    if ( !g_classRefs) {
        g_classRefs = [[NSMutableDictionary alloc] init];
        g_classRefLock = [[NSLock alloc] init];
    }
    [g_classRefLock lock];
    [g_classRefs setObject:value forKey:key];
    [g_classRefLock unlock];
}

+ (JSClassRef)jsClassRef
{
    id value = [self _cachedClassRefValueForKey:[self constructorName]];
    if (value) {
        return [value pointerValue];
        // early exit - found in cache
    }

    JSClassDefinition classDef = kJSClassDefinitionEmpty;
    classDef.className = strdup([[self constructorName] UTF8String]);
    classDef.parentClass = [self parentClass];
    
    // build up the static properties
    NSArray *properties = [self objectPropertyNames];
    NSEnumerator *e;
    NSString *key;
    // NB: JSStaticValue arrays and JSStaticFunction arrays are declared assuming that they will be statically declared, as opposed
    // to dynamically allocated and filled in.  As a result, the name fields are constants that we can't change, thus the fugly type cooercions
    
    // 2009.04.21 / Pauli Ojala -- added this check because JavaScriptCore doesn't seem to understand a 'staticValues' array with only the null terminator...
    // nope, reverted for now: passing NULL will crash JSCore garbage collection
    if (0 && [properties count] < 1) {
        classDef.staticValues = NULL;
    } else {
        JSStaticValue *staticValueArray = (JSStaticValue *)calloc([properties count]+1,sizeof(JSStaticValue));
        classDef.staticValues = staticValueArray;
        e = [properties objectEnumerator];
        while ((key = [e nextObject])) {
            *((char **)&staticValueArray->name) = strdup([key UTF8String]);
            staticValueArray->attributes = kJSPropertyAttributeNone;
            staticValueArray->getProperty = LQJSKitBridgeGetProperty;
            if ([self canWriteProperty: key]) {
                staticValueArray->setProperty = LQJSKitBridgeSetProperty;
            } else {
                staticValueArray->attributes |= kJSPropertyAttributeReadOnly;
            }
            if (![self canDeleteProperty: key]) {
                staticValueArray->attributes |= kJSPropertyAttributeDontDelete;
            }	
            if (![self canEnumProperty: key]) {
                staticValueArray->attributes |= kJSPropertyAttributeDontEnum;
            }	
            staticValueArray++;
        }
        *((char **)&staticValueArray->name) = NULL;
        staticValueArray->getProperty = NULL;
        staticValueArray->setProperty = NULL;
        staticValueArray->attributes = 0;
    }
    
    // build up the static functions
    NSArray *functions = [self objectFunctionNames];
    if (0 && [functions count] < 1) {  // see comment above for properties
        classDef.staticFunctions = NULL;
    } else {
        JSStaticFunction *staticFunctionArray = (JSStaticFunction *)calloc([functions count]+1, sizeof(JSStaticFunction));
        classDef.staticFunctions = staticFunctionArray;
        e = [functions objectEnumerator];
        while ((key = [e nextObject])) {
            *((char **)&staticFunctionArray->name) = strdup([key UTF8String]);
            staticFunctionArray->attributes = kJSPropertyAttributeNone;
            // -- since we can't get the function name (and thus the method name) out of the static function,
            //    we can't pass a function here, but instead need to do the bridging dynamically in the GetPropertyCallback function
            staticFunctionArray->callAsFunction = NULL;//LQJSKitBridgeCallFunction;
            staticFunctionArray->attributes |= kJSPropertyAttributeReadOnly;
            if (![self canDeleteProperty: key]) {
                staticFunctionArray->attributes |= kJSPropertyAttributeDontDelete;
            }	
            if (![self canEnumProperty: key]) {
                staticFunctionArray->attributes |= kJSPropertyAttributeDontEnum;
            }	
            staticFunctionArray++;
        }
        *((char **)&staticFunctionArray->name) = NULL;
        staticFunctionArray->callAsFunction = NULL;
        staticFunctionArray->attributes = 0;
    }
    
    classDef.getProperty = LQJSKitBridgeGetPropertyCallback;
    
    if ([self hasArrayIndexingSetter]) {
        classDef.setProperty = LQJSKitBridgeSetIndexedProperty;
    }
    
    // and the other callbacks
    classDef.convertToType = LQJSKitNSObjectConvertToTypeCallback;
    classDef.finalize = LQJSKitNSObjectFinalizeCallback;
//    classDef.callAsConstructor = LQJSKitBridgeConstructor;
    
    JSClassRef classRef = JSClassCreate(&classDef);
    
    [self _cacheClassRefValue:[NSValue valueWithPointer:classRef] forKey:[self constructorName]];
    
    return classRef;
}

+ (JSObjectRef) makeConstructorInContext: (JSContextRef) context
{
    JSObjectRef constructor = JSObjectMakeConstructor(context, [self jsClassRef], LQJSKitBridgeConstructor);
    
    //NSAssert(JSObjectSetPrivate(constructor, self), @"Obj-C bridge as private data");    
    //NSLog(@"%s (%p): jsobj private data is %p", __func__, self, JSObjectGetPrivate(constructor));

    return constructor;
}

- (JSValueRef) convertToJSValueRefWithContext: (JSContextRef) context
{
    return _jsObject;
}

- (id) bridgeObject: (id) cls withConstructorArguments: (NSArray *) arguments
{
    id retval = [[cls alloc] initInJSContext:_jsContext withOwner:nil];
    [retval awakeFromConstructor: arguments ? arguments : (NSArray *)[NSArray array]];
    return [retval autorelease];
}

- (BOOL) isFunction
{
    return NO;
}
- (BOOL) isConstructor
{
    return YES;
}


#pragma mark --- utilities for bridge subclasses ---

- (BOOL)parseByteFromArg:(id)obj outValue:(uint8_t *)b
{
    if ([obj isKindOfClass:[NSNumber class]]) {
        int n = [obj intValue]; 
        *b = MAX(0, MIN(255, n));
        return YES;
    }
    else if ([obj respondsToSelector:@selector(doubleValue)]) {
        double d = [obj doubleValue];
        *b = round( MAX(0.0, MIN(255.0, d)) );
        return YES;
    }
    return NO;
}

- (BOOL)parseLongFromArg:(id)obj outValue:(long *)l
{
    if ([obj isKindOfClass:[NSNumber class]]) {
        *l = [obj longValue];
        return YES;
    }
    else if ([obj respondsToSelector:@selector(doubleValue)]) {
        *l = (long)[obj doubleValue];
        return YES;
    }
    return NO;
}

- (LQJSKitObject *)emptyProtectedJSObject
{
    JSObjectRef jsobj = JSObjectMake(_jsContext, NULL, NULL);
    id obj = [[[LQJSKitObject alloc] initWithObject:jsobj context:_jsContext] autorelease];
    [obj setProtected:YES];
    return obj;
}

- (JSContextRef)jsContextRefFromJSCallContextObj:(id)contextObj
{
    return (JSContextRef) [contextObj pointerValue];
}

@end




@implementation LQJSKitInterpreter(BridgeObject)

- (void)loadBridgeClass:(Class)bridgeObjectClass
{
    if (!bridgeObjectClass) return;
    
    NSString *name = [bridgeObjectClass constructorName];
    NSAssert1(name, @"bridge class must specify a constructor name (%@)", bridgeObjectClass);
        
    // constructor check and myConstructors insert added by Pauli, 2009.04.23
    if ([myPackages objectForKey:name] || [myConstructors objectForKey:name]) {
        return; // already loaded
    }
    
    JSObjectRef constructor = [bridgeObjectClass makeConstructorInContext:_globalCtx];
    JSStringRef propName = JSStringCreateWithCFString((CFStringRef)name);
    JSObjectSetProperty(_globalCtx, JSContextGetGlobalObject(_globalCtx), propName, constructor, 0, NULL);
    JSStringRelease(propName);

    id constructorLQJSKitObj = [self globalVariableForKey:name];
	if (constructorLQJSKitObj) {
	    [myConstructors setObject:constructorLQJSKitObj forKey:name];
        ///NSLog(@"interpreter %@: created constructor %p for class %@", self, constructor, name);
	} else {
        NSLog(@"** %s: JS-side constructor was not created for bridge class '%@'", __func__, name);
    }
    
    ///NSLog(@"%s (%p): loading bridge class %@ -- jsconstr is %p (wrapper is %p)", __func__, self, bridgeObjectClass, constructor, constructorLQJSKitObj);
    
    if ( !myConstructorsByBridgeClass)
        myConstructorsByBridgeClass = [[NSMutableDictionary alloc] init];
        
    [myConstructorsByBridgeClass setObject:constructorLQJSKitObj forKey:[NSValue valueWithPointer:bridgeObjectClass]];
}

- (id) bridgeObject: (id) cls withConstructorArguments: (NSArray *) arguments
{
    id retval = [[cls alloc] initInJSContext:_globalCtx withOwner:nil];
    [retval awakeFromConstructor: arguments ? arguments : (NSArray *)[NSArray array]];
    return [retval autorelease];
}

- (id)constructorNamed:(NSString *)name
{
    return [myConstructors objectForKey:name];
}


- (Class)bridgeClassForJSConstructor:(JSObjectRef)wanted
{
    NSEnumerator *constrClassEnum = [myConstructorsByBridgeClass keyEnumerator];
    id key;
    while (key = [constrClassEnum nextObject]) {
        id constr = [myConstructorsByBridgeClass objectForKey:key];
        
        JSObjectRef jsObj = [constr jsObjectRef];
        
        ///NSLog(@".... key %@: jsconstr %p / wrapper %p", (id)[key pointerValue], jsObj, constr);

        if (jsObj == wanted) {
            Class cls = (Class)[key pointerValue];
            NSAssert(cls, @"bridge object class key is nil");
            
            ///NSLog(@"%s (%p): found class %@ for constructor %p", __func__, self, cls, wanted);
            return cls;
        }
    }
    NSLog(@"** %s (%p): couldn't find constructor for object %p", __func__, self, wanted);
    return nil;
}

@end
 
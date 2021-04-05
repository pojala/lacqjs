//
//  JSKitInterpreter.mm
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

#import "JSKitInterpreter.h"
#import "JSKitObject.h"
#import "JSKitWrappers.h"
//#import "JSKitPackage.h"
//#import "JSKitBridgeObject.h"
#import "JSKitException.h"
#import "JSKitInternal.h"
#import "JSKitInvocation.h"

NSString * const LQJSKitVersionString = @"71.0";
double LQJSKitVersionNumber = 71.0;


extern JSStringRef s_lengthStr;
extern JSStringRef s_ArrayStr;
extern void LQJSKitWrappers_initStatics();


@interface NSObject(LQJSKitInterpreterDelegate)
- (BOOL) jskitInterpreter: (LQJSKitInterpreter *) interpreter exception: (LQJSKitObject *) exception;
- (void) jskitInterpreter: (LQJSKitInterpreter *) interpreter print: (NSString *) message;
@end

@implementation NSObject(LQJSKitInterpreterDelegate)
- (BOOL) jskitInterpreter: (LQJSKitInterpreter *) interpreter exception: (LQJSKitObject *) exception
{
    NSLog(@"LQ JavaScript exception: %@", [exception jskitIntrospect]);
    return YES;
}
- (void) jskitInterpreter: (LQJSKitInterpreter *) interpreter print: (NSString *) message
{
    NSLog(@"LQJS: %@", message);
}
- (void) jskitInterpreter: (LQJSKitInterpreter *) interpreter log: (NSString *) message
{
    NSLog(@"LQJS: %@", message);
}
@end




@implementation LQJSKitInterpreter
- (id) init
{
    self = [super init];
    
    ///NSLog(@"%s - %p", __func__, self);
    
    if (self) {
        /*_globalCtxGroup = JSContextGroupCreate();
        
        // the created group is not retained by default, probably because it's assumed that a
        // newly created context will retain it.
        JSContextGroupRetain(_globalCtxGroup);
        */

        // from JSObjectRef.h:
        // "Only objects created with a non-NULL JSClass can store private data"
        JSClassDefinition classDefinition = kJSClassDefinitionEmpty;
        _globalClassRef = JSClassCreate(&classDefinition);
        
        //_globalCtx = JSGlobalContextCreateInGroup(_globalCtxGroup, _globalClassRef);
        _globalCtx = JSGlobalContextCreate(_globalClassRef);
        
        JSObjectRef globalObject = JSContextGetGlobalObject(_globalCtx);
        JSObjectSetPrivate(globalObject, self);


        myPackages = [[NSMutableDictionary dictionary] retain];
        myConstructors = [[NSMutableDictionary dictionary] retain];
        
        id constructor = [self globalVariableForKey:@"Array"];
        if (constructor) {
            [myConstructors setObject: constructor forKey: @"Array"];
        }
        constructor = [self globalVariableForKey:@"Boolean"];
        if (constructor) {
            [myConstructors setObject: constructor forKey: @"Boolean"];
        }
        constructor = [self globalVariableForKey:@"Date"];
        if (constructor) {
            [myConstructors setObject: constructor forKey: @"Date"];
        }
        
        ///NSLog(@"-- LQJSKit init --");
        ///NSLog(@"Constructors found %@", myConstructors);
        ///NSLog(@"Created context %p", _globalCtx);

        //[self addFunction: @"print" target: self selector: @selector(interpreterPrint:)];
        //[self addFunction: @"log" target: self selector: @selector(interpreterLog:)];
        //[self addFunction: @"introspect" target: self selector: @selector(interpreterIntrospect:)];
        //[self addFunction: @"include" target: self selector: @selector(interpreterInclude:)];
    }
    return self;
}

- (void) dealloc
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    //NSLog(@"%s", __func__);
    
    [self garbageCollect];
    
    [myPackages release];
    [myIncludePaths release];
    [myConstructors release];
    [myConstructorsByBridgeClass release];

    [pool release];
    
    JSGlobalContextRelease(_globalCtx);
    _globalCtx = NULL;
    
    JSClassRelease(_globalClassRef);
    _globalClassRef = NULL;
    
    if (_globalCtxGroup) JSContextGroupRelease(_globalCtxGroup);
    _globalCtxGroup = NULL;
    
    [super dealloc];
}

- (void) setDelegate: (id) delegate
{
    _delegate = delegate;
}
- (id) delegate
{
    return _delegate;
}

- (void) garbageCollect
{
    JSGarbageCollect(_globalCtx);
}


- (id) evaluateScript: (NSString *) script
{
    return [self evaluateScript: script thisValue: nil error: NULL];
}
- (id) evaluateScript: (NSString *) script error: (NSError **)error
{
    return [self evaluateScript: script thisValue: nil error: error];
}
- (id) evaluateScript: (NSString *) script thisValue: (LQJSKitObject *) thisValue
{
    return [self evaluateScript: script thisValue: thisValue error: NULL];
}

- (id) compileScript: (NSString *) script functionName: (NSString *) name parameterNames: (NSArray *) params error: (NSError **)error
{
    JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)script);
    JSStringRef nameRef = name ? JSStringCreateWithCFString((CFStringRef)name) : NULL;
    unsigned int parameterCount = (unsigned int)[params count];
    JSStringRef parameterNames[parameterCount];
    int i;
    for (i =0;i<parameterCount;i++) {
	parameterNames[i] = JSStringCreateWithCFString((CFStringRef)[params objectAtIndex:i]);
    }
    JSValueRef exception = NULL;
    JSObjectRef result = JSObjectMakeFunction(_globalCtx, nameRef, parameterCount, parameterNames, scriptJS, NULL, 0, &exception);
    
    if (nameRef) JSStringRelease(nameRef);
    JSStringRelease(scriptJS);
    for (i =0;i<parameterCount;i++) {
	JSStringRelease(parameterNames[i]);
    }
    if (exception) {
	if (error) {
	    *error = [NSError errorWithLQJSKitException: exception inContext: _globalCtx];
	}
	if ([self handleException: exception]) {
	    if (myPropagatesExceptions && error == nil) {
		[NSException raiseLQJSKitException:exception inContext: _globalCtx];
	    }
	}
    }
    if (result) {
	return [self convertJSValueRef: result];
    } else {
	return nil;
    }    
}

// added by Pauli Ojala on 2009.07.04
- (id) compileAnonymousFormattedFunction:(NSString *)funcStr error:(NSError **)error
{
    // the function string is of format:
    // function (a, b, c) { ... }
    // We need to separate the body and parse the arguments so we can create a new function.
    id newObj = nil;
    
    NSRange range = [funcStr rangeOfString:@"{"];
    if (range.location != NSNotFound && range.location < [funcStr length] - 1) {
        NSString *funcBody = [funcStr substringFromIndex:range.location + 1];
        NSString *funcDecl = [funcStr substringToIndex:range.location];
        
        range = [funcBody rangeOfString:@"}" options:NSBackwardsSearch];
        if (range.location != NSNotFound) {
            funcBody = [funcBody substringToIndex:range.location];
        }
        
        range = [funcDecl rangeOfString:@"("];
        NSRange range2 = [funcDecl rangeOfString:@")"];
        if (range.location == NSNotFound || range2.location == NSNotFound) {
            NSLog(@"*** copying function failed: its declaration is missing parens for arguments ('%@')", funcDecl);
        } else {
            funcDecl = [funcDecl substringWithRange:NSMakeRange(range.location + 1, range2.location - 1 - range.location)];
            NSArray *funcArgs = [funcDecl componentsSeparatedByString:@","];
            NSMutableArray *cleanedArgs = [NSMutableArray arrayWithCapacity:[funcArgs count]];
            NSEnumerator *argEnum = [funcArgs objectEnumerator];
            NSString *arg;
            while (arg = [argEnum nextObject]) {
                arg = [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([arg length] > 0) {
                    [cleanedArgs addObject:arg];
                }
            }
            ///NSLog(@"..copying function: args are %@", cleanedArgs);
            
            NSError *err = nil;
            newObj = [self compileScript:funcBody functionName:nil parameterNames:cleanedArgs error:&err];
        }            
    }
    return newObj;
}

// added by Pauli Ojala on 2009.10.24.
// see header for discussion.
- (id) recontextualizeObject:(id)obj
{
    if ( !obj) return nil;
    
    [self setGlobalVariable:obj forKey:@"__interpPrivateTemp"];
    
    id nobj = [self globalVariableForKey:@"__interpPrivateTemp"];
    
    [self setGlobalVariable:nil forKey:@"__interpPrivateTemp"];
    
    return nobj;
}


- (BOOL) propagatesExceptions
{
    return myPropagatesExceptions;
}
- (void) setPropagatesExceptions: (BOOL) propagates
{
    myPropagatesExceptions = propagates;
}

- (id) evaluateScript: (NSString *) script thisValue: (LQJSKitObject *) thisValue error: (NSError **)error
{
    if ( !script) return nil;
    
    JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)script);
    JSValueRef exception = nil;
    JSValueRef result = JSEvaluateScript(_globalCtx, scriptJS, [thisValue jsObjectRef], NULL, 0, &exception);
    JSStringRelease(scriptJS);
    if (exception) {
	if (error) {
	    *error = [NSError errorWithLQJSKitException: exception inContext: _globalCtx];
	}
	if ([self handleException: exception]) {
	    if (myPropagatesExceptions && error == nil) {
		[NSException raiseLQJSKitException:exception inContext: _globalCtx];
	    }
	}
    }
    if (result) {
	return [self convertJSValueRef: result];
    } else {
	return nil;
    }    
}

- (BOOL) checkSyntax: (NSString *) script
{
    return [self checkSyntax: script error: NULL];
}
- (BOOL) checkSyntax: (NSString *) script error: (NSError **)error
{
    JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)script);
    JSValueRef exception = nil;
    BOOL result = JSCheckScriptSyntax(_globalCtx, scriptJS, NULL, 0, &exception);
    if (exception) {
	if (error) {
	    *error = [NSError errorWithLQJSKitException: exception inContext: _globalCtx];
	}
    }	
    JSStringRelease(scriptJS);
    return result;
}


#pragma mark -- Bridging --

- (void) addFunction: (NSString *) name target: (id) target selector: (SEL) sel
{
    JSStringRef funcName = JSStringCreateWithCFString((CFStringRef)name);
    
//    JSObjectRef func = LQJSKitBridgeCallFunctionWithSelector(_globalCtx, target, sel);
    JSObjectRef func = LQJSKitInvocationFunction(_globalCtx, [LQJSKitInvocation invocationWithNonRetainedTarget:target action:sel]);
    
    JSObjectSetProperty(_globalCtx, JSContextGetGlobalObject(_globalCtx), funcName, func, 0, NULL);
    
    JSStringRelease(funcName);
}

- (void) addRawFunction: (NSString *) name target: (id) target selector: (SEL) sel;
{
    JSStringRef funcName = JSStringCreateWithCFString((CFStringRef)name);
    
    //    JSObjectRef func = LQJSKitBridgeCallFunctionWithSelector(_globalCtx, target, sel);
    JSObjectRef func = LQJSKitInvocationFunction(_globalCtx, [LQJSKitInvocation invocationWithRawTarget:target action:sel]);
    
    JSObjectSetProperty(_globalCtx, JSContextGetGlobalObject(_globalCtx), funcName, func, 0, NULL);
    
    JSStringRelease(funcName);
}

- (id) globalVariableForKey: (NSString *) key
{
    JSStringRef propName = JSStringCreateWithCFString((CFStringRef)key);
    JSValueRef value =   JSObjectGetProperty(_globalCtx, JSContextGetGlobalObject(_globalCtx), propName, NULL);
    JSStringRelease(propName);
    return [self convertJSValueRef:value];
}


- (void) setGlobalVariable: (id) value forKey: (NSString *) key
{
    [self setGlobalVariable:value forKey:key options:0];
}

- (void) setGlobalVariable: (id) value forKey: (NSString *) key options: (JSPropertyAttributes) propAttrs
{
    JSValueRef jsvalue = [value convertToJSValueRefWithContext: _globalCtx];
    if (jsvalue) {
	JSStringRef propName = JSStringCreateWithCFString((CFStringRef)key);
	JSObjectSetProperty(_globalCtx, JSContextGetGlobalObject(_globalCtx), propName, jsvalue, propAttrs, NULL);
	JSStringRelease(propName);
    } else {
	JSStringRef propName = JSStringCreateWithCFString((CFStringRef)key);
	JSObjectDeleteProperty(_globalCtx, JSContextGetGlobalObject(_globalCtx), propName, NULL);
	JSStringRelease(propName);
    }
}
- (LQJSKitObject *) emptyProtectedJSObject
{
    JSObjectRef jsobj = JSObjectMake(_globalCtx, NULL, NULL);
    id obj = [[[LQJSKitObject alloc] initWithObject: jsobj context: _globalCtx] autorelease];
    [obj setProtected:YES];
    return obj;
}

- (id) emptyProtectedJSArray
{
    id arrayConstr = [myConstructors objectForKey:@"Array"];
    NSAssert(arrayConstr, @"array constructor is missing for this JS context");
    
    id obj = [arrayConstr constructWithParameters:nil error:NULL];
    [obj setProtected:YES];
    return obj;
}


#pragma mark global functions
- (id) interpreterPrint: (NSArray *)args
{
    NSMutableString *message = [NSMutableString string];
    NSEnumerator * e = [args objectEnumerator];
    id element;
    while ((element = [e nextObject]) != nil) {
	[message appendString: [element description]];
    }
    if (_delegate && [_delegate respondsToSelector:@selector(jskitInterpreter:print:)]) {
	[_delegate jskitInterpreter:self print:message];
    } else {
	NSLog(@"LQJSKit: %@", message);
    }
    return nil;
}
- (id) interpreterLog: (NSArray *)args
{
    NSMutableString *message = [NSMutableString string];
    NSEnumerator * e = [args objectEnumerator];
    id element;
    while ((element = [e nextObject]) != nil) {
	[message appendString: [element description]];
    }
    if (_delegate && [_delegate respondsToSelector:@selector(jskitInterpreter:log:)]) {
	[_delegate jskitInterpreter:self log:message];
    } else {
	NSLog(@"LQJSKit: %@", message);
    }
    return nil;
}
- (id) interpreterIntrospect: (NSArray *)args
{
    if ([args count] == 0)
	return nil;
    return [[args objectAtIndex: 0] jskitIntrospect];
}
- (id) interpreterInclude: (NSArray *) args
{
    if ([args count] == 0)
	return nil;
    return [self includeScript:[args objectAtIndex: 0] error: nil];
}


- (void) setIncludePaths: (NSArray *) paths
{
    [myIncludePaths release];
    myIncludePaths = [paths copy];
}
- (id) includeScript: (NSString *) relativePath error: (NSError **)error // looks in the include paths to find the relative string
{
    // we need to go through the include paths, combine it with the relative path, and see if we can be found.
    // We need to make sure that we don't escape outside of a sandbox.  So we try all combinations of relative path with prefix, and make sure
    // that result is still within one of the include paths.
    //
    // As a result, if one of the include paths is "/" then we can access anything anywhere, by an absolute path.
    // If one of the include paths is "." we can do relative paths.  This is all based on the current working directory (so if that changes,
    // these results will chang as well
    if (![myIncludePaths count]) {
	NSLog(@"No include path for %@", relativePath);
	return nil; // not allowed
    }
    if ([[relativePath pathExtension] length] == 0) {
	relativePath = [relativePath stringByAppendingPathExtension:@"js"];
    }
    NSEnumerator *e = [myIncludePaths objectEnumerator];
    NSMutableArray *standardizedIncludePaths = [NSMutableArray array];
    NSString *path;
    while ((path = [e nextObject]) != nil) {
	if ([path isEqualToString: @"."] || [path hasPrefix: @"./"]) { // convert from relative to absolute
	    path = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:path];
	}
	if (![path hasSuffix:@"/"]) // make sure our candidates end with a slash
	    path = [path stringByAppendingString:@"/"];
	[standardizedIncludePaths addObject: [path stringByStandardizingPath]];
    }
    NSString *fullPath = nil;
    e = [standardizedIncludePaths objectEnumerator];
    while ((path = [e nextObject]) != nil) {
	if ([relativePath hasPrefix:@"/"]) {
	    fullPath = relativePath; // it is actually absolute
	} else {
	    fullPath = [[path stringByAppendingPathComponent: relativePath] stringByStandardizingPath];
	}
	// see if the result  has a safe prefix - try the first one first
	if ([fullPath hasPrefix: path]) {
	    break; // valid
	}
	// look through the rest
	NSEnumerator *e2 = [standardizedIncludePaths objectEnumerator];
	NSString *anchor;
	while ((anchor = [e2 nextObject]) != nil) {
	    if ([fullPath hasPrefix: anchor])
		break; // got it
	}
	if (anchor) { // it is anchored
	    break;
	}
	fullPath = nil;
    }
    if (fullPath) {
        return [self evaluateScript: [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:NULL] error: error];
    } else {
	NSLog(@"No include path for %@ in %@", relativePath, standardizedIncludePaths);
    }
    return nil;
}
@end

@implementation LQJSKitInterpreter(Internal)
+ (NSArray *) convertJSValueRefs: (const JSValueRef *) jsValues count:(NSUInteger)argumentCount context:(JSContextRef) ctx
{
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:argumentCount];
    int i;
    for (i =0;i<argumentCount;i++) {
	id arg = [LQJSKitInterpreter convertJSValueRef:jsValues[i] context: ctx];
	if (!arg) arg = @"<invalid>";
	[args addObject: arg];
    }
    return args;
}

+ (id) convertJSValueRef: (JSValueRef) jsValue context:(JSContextRef) ctx
{
    if ( !s_lengthStr) LQJSKitWrappers_initStatics();

    if ( !jsValue || !ctx) return nil;
    
    //NSLog(@"converting JS value %p, ctx %p, type %d", jsValue, ctx, (int)JSValueGetType(ctx, jsValue));
    
    switch (JSValueGetType(ctx,jsValue)) {
	case kJSTypeUndefined:
	    return nil;
	case kJSTypeNull:
	    return [NSNull null];
	case kJSTypeBoolean:
	    if (JSValueToBoolean(ctx, jsValue)) {
            return [NSNumber numberWithBool:YES];
	    } else {
            return [NSNumber numberWithBool:NO];
	    }
    case kJSTypeNumber:
        return [NSNumber numberWithDouble:JSValueToNumber(ctx,jsValue, NULL)];
    case kJSTypeString: {
        JSStringRef resultStringJS = JSValueToStringCopy(ctx, jsValue, NULL);
        NSString *retval = [[LQJSKitStringWrapper alloc] initWithJSString: resultStringJS];
        JSStringRelease(resultStringJS);
        return [retval autorelease];
    }
    case kJSTypeObject: {
        if (!JSObjectIsFunction(ctx, (JSObjectRef)jsValue) &&
            !JSObjectIsConstructor(ctx, (JSObjectRef)jsValue)) {
            if (JSObjectHasProperty(ctx, (JSObjectRef)jsValue, s_lengthStr)) {
                
                // get the context's Array constructor - make sure it is a constructor!
                JSValueRef arrayConstructor = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), s_ArrayStr, NULL);
                
                //NSLog(@" ... object %p has length, array constr is %p", jsValue, arrayConstructor);

                if (JSValueIsObject(ctx, arrayConstructor) &&
                    JSObjectIsConstructor(ctx, (JSObjectRef)arrayConstructor)) {
                    //NSLog(@"  .. is instance: %d", JSValueIsInstanceOfConstructor(ctx, (JSObjectRef)jsValue, (JSObjectRef)arrayConstructor, NULL));
                    if (JSValueIsInstanceOfConstructor(ctx, (JSObjectRef)jsValue, (JSObjectRef)arrayConstructor, NULL)) {
                        // finally!  We know that it is an array!
                        return [[[LQJSKitArrayWrapper alloc] initWithObject: (JSObjectRef) jsValue context: ctx] autorelease];
                    }
                }
            }
        }
        return [LQJSKitObject objectWithObject: (JSObjectRef)jsValue context: ctx];
    }
    }
    return nil;
}
- (id) convertJSValueRef: (JSValueRef) jsValue
{
    return [[self class] convertJSValueRef: jsValue context: _globalCtx];
}
- (JSValueRef) createJSValueRef: (id) value
{
    if (value == nil) {
	return JSValueMakeNull(_globalCtx);
    }
    return [value convertToJSValueRefWithContext:_globalCtx];
}
+ (JSValueRef) createJSValueRef: (id) value context: (JSContextRef) ctx
{
    if (value == nil) {
	return JSValueMakeNull(ctx);
    }
    return [value convertToJSValueRefWithContext:ctx];
}

- (JSGlobalContextRef) context
{
    return _globalCtx;
}

+ (LQJSKitInterpreter *)interpreterForContext:(JSGlobalContextRef)ctx
{
    JSObjectRef globalObject = JSContextGetGlobalObject(ctx);
    return JSObjectGetPrivate(globalObject);
}

- (BOOL) handleException: (JSValueRef) exception
{
    if (!exception) return NO;
    //    NSLog(@"Exception %@", [self formatException: exception]);
    
    if (_delegate && [_delegate respondsToSelector:@selector(jskitInterpreter:exception:)]) {
	return [_delegate jskitInterpreter:self exception:[self convertJSValueRef: exception]];
    } else {
	return [self jskitInterpreter:self exception:[self convertJSValueRef: exception]];
	//	JSStringRef resultStringJS = JSValueToStringCopy(_globalCtx, exception, NULL);
	//	CFStringRef resultString = JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
	//	JSStringRelease(resultStringJS);
	//	NSLog(@"LQJSKitException: %@", resultString);
	//	CFRelease(resultString);
    }
}

@end

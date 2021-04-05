//
//  LQJSContainer.m
//  LacqJSKit
//
//  Created by Pauli Ojala on 13.10.2008.
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
#import <Foundation/Foundation.h>
#import "LQJSContainer.h"
#import "LQJSInterpreter.h"
#import "JSKitObject.h"
#import "JSKitException.h"
#import "LQJSBridgeObject.h"


extern void LQJSKitWrappers_initStatics();


// 2009.07.01 -- added this lock to avoid crashes in JSCore on Leopard
// when dealloc and construct were simultaneously running in separate threads.
// this needs to be revisited in future versions of JavaScriptCore.
NSLock *g_jsLock = nil;

#ifdef __APPLE__

 #define ENTERCONTEXTLOCK  [g_jsLock lock];
 #define EXITCONTEXTLOCK   [g_jsLock unlock];
 //#define ENTERCONTEXTLOCK  //NSLog(@"%s (%@) -- should lock", __func__, self);  //[g_jsLock lock];
 //#define EXITCONTEXTLOCK   //NSLog(@"%s (%@) -- unlock", __func__, self);  //[g_jsLock unlock];

 #define ENTERCONTEXTLOCK_EXEC  [g_jsLock lock];
 #define EXITCONTEXTLOCK_EXEC   [g_jsLock unlock];

#else

 #define ENTERCONTEXTLOCK  [g_jsLock lock];
 #define EXITCONTEXTLOCK   [g_jsLock unlock];

 #define ENTERCONTEXTLOCK_EXEC  [g_jsLock lock];
 #define EXITCONTEXTLOCK_EXEC   [g_jsLock unlock];

#endif



#define ENTERARPOOL       NSAutoreleasePool *arPool = [[NSAutoreleasePool alloc] init];
#define EXITARPOOL        [arPool release];  arPool = nil;



@implementation LQJSContainer

- (id)init
{
    return [self initWithName:nil];
}

- (id)initWithName:(NSString *)name
{
    self = [super init];
    
    LQJSKitWrappers_initStatics();
    
    if ( !g_jsLock) {
        g_jsLock = (NSLock *)[[NSRecursiveLock alloc] init];
        if ([g_jsLock respondsToSelector:@selector(setName:)]) {
            [g_jsLock setName:@"LQJSContainerSharedLock"];
        }
    }
    
    ENTERCONTEXTLOCK
    _jsInterp = [[LQJSInterpreter alloc] init];
    EXITCONTEXTLOCK
    
    if ( ![_jsInterp context]) {
        NSLog(@"** %s: unable to create JS interpreter", __func__);
        [_jsInterp release];
        _jsInterp = nil;
        
        [self autorelease];
        return nil;
    }

    _name = ([name length] > 0) ? name : (NSString *)@"UntitledLQJSContainer";
    [_name retain];
    
    _scripts = [[NSMutableDictionary alloc] init];
    _compiledFuncs = [[NSMutableDictionary alloc] init];
    _scriptParamNames = [[NSMutableDictionary alloc] init];
        
    return self;
}

- (id)initWithScriptsInJSContainer:(LQJSContainer *)jsContainer
{
    self = [self initWithName:[jsContainer name]];
    if (self) {
        NSEnumerator *keyEnum = [[jsContainer scriptKeys] objectEnumerator];
        NSString *key;
        while (key = [keyEnum nextObject]) {
            [self setScript:[jsContainer scriptForKey:key]
                    forKey:key
                    parameterNames:[jsContainer parameterNamesForKey:key]
                ];
        }
    }
    return self;
}

- (void)cleanupAfterRenderIteration
{
    ENTERCONTEXTLOCK
    [_jsInterp garbageCollect];
    EXITCONTEXTLOCK
}

- (void)clearAllState
{
    ENTERCONTEXTLOCK
    ENTERARPOOL
    [self removeAllScripts];

    [_constructedObj setProtected:NO];
    [_constructedObj release];
    _constructedObj = nil;

    [_compiledConstrJSFunc setProtected:NO];
    [_compiledConstrJSFunc release];
    _compiledConstrJSFunc = nil;
    
    [_constrScript release];
    _constrScript = nil;

    [_jsInterp garbageCollect];
    EXITARPOOL
    [_jsInterp garbageCollect];
    EXITCONTEXTLOCK
}

- (void)dealloc
{
    //NSLog(@"%s: %@", __func__, self);
    [self clearAllState];
    
    ENTERCONTEXTLOCK
    [_jsInterp release];
    EXITCONTEXTLOCK
    
    [_name release];
    [_lastError release];
    [super dealloc];
}

- (id)delegate {
    return _delegate; }
    
- (void)setDelegate:(id)del {
    _delegate = del; }


- (NSString *)name {
    return _name; }

- (id)description {
    return [NSString stringWithFormat:@"<%@: %p (%@)>", [self class], self, [self name]]; }


- (LQJSInterpreter *)interpreter {
    return _jsInterp; }

- (JSContextRef)jsContextRef {
    return [_jsInterp context]; }
    

- (void)_setError:(NSError *)error {
    [_lastError release];
    _lastError = [error retain];
}

- (NSString *)constructorScript {
    return _constrScript; }


+ (NSString *)constructorNameFromString:(NSString *)str
{
    NSCharacterSet *set = [NSCharacterSet alphanumericCharacterSet];
    
    NSScanner *scanner = [NSScanner scannerWithString:str];
    [scanner setCharactersToBeSkipped:nil];
    
    NSString *s = nil;
    NSMutableString *m = [NSMutableString string];
    while ( ![scanner isAtEnd] && [scanner scanCharactersFromSet:set intoString:&s]) {
        [m appendString:s];
        [scanner scanUpToCharactersFromSet:set intoString:NULL];
    }
    return m;
}

- (BOOL)setConstructorScript:(NSString *)script
{
    ENTERCONTEXTLOCK
    
    [_compiledConstrJSFunc setProtected:NO];
    [_compiledConstrJSFunc release];
    _compiledConstrJSFunc = nil;

    [_constrScript release];
    _constrScript = nil;

    if ( !script || [script length] < 1) {
        script = @"";
    }

    NSString *funcName = [[self class] constructorNameFromString:[self name]];
    if ([funcName length] < 1) funcName = @"UnknownLQJSContainer";
    //NSLog(@"%@: constructor funcName: %@", self, funcName);

    ENTERARPOOL
    NSError *error = nil;
    id compiledFunc = [_jsInterp compileScript:script functionName:funcName
                                                  parameterNames:[NSArray array]
                                                  error:&error];

    BOOL retVal = NO;
    if ( !compiledFunc || error) {
        [self _setError:error];
    } else {
        _compiledConstrJSFunc = [compiledFunc retain];
        [_compiledConstrJSFunc setProtected:YES];
        _constrScript = [script retain];
        retVal = YES;
    }
    EXITARPOOL
    EXITCONTEXTLOCK    
    return retVal;
}

- (BOOL)construct
{
    [_constructedObj setProtected:NO];
    [_constructedObj release];
    _constructedObj = nil;

    if ( !_constrScript)
        return NO;        
    if ( !_compiledConstrJSFunc)
        return NO;
    
    ENTERCONTEXTLOCK    
    ENTERARPOOL
    NSError *error = nil;
    id constructed = nil;
    if ([_delegate respondsToSelector:@selector(createJSThisObjectForContainer:)]) {
        constructed = [_delegate createJSThisObjectForContainer:self];  //[[_constrBridgeClass alloc] initInJSContext:[self jsContextRef] withOwner:self];
    }
    if ( !constructed) {
        constructed = [[_jsInterp emptyProtectedJSObject] retain];
    }
    
    //constructed = [[_compiledConstrJSFunc constructWithParameters:nil error:&error] retain];
    
    id result = nil;
    
    @try {
        result = [_compiledConstrJSFunc callWithThis:constructed parameters:nil error:&error];
    }
    @catch(NSException *exc) {
        NSMutableDictionary *userInfo = ([exc userInfo]) ? [NSMutableDictionary dictionaryWithDictionary:[exc userInfo]] : [NSMutableDictionary dictionary];
        
        [userInfo setObject:[NSString stringWithFormat:@"An exception occurred during JS construction: %@: reason %@", [exc name], [exc reason]]
                     forKey:NSLocalizedDescriptionKey];
    
        error = [NSError errorWithDomain:LQJSKitErrorDomain code:113 userInfo:userInfo];
    }

    #pragma unused (result)
    
    //NSLog(@"%s: bridge obj %@; constrfunc is %@ (result from its eval: '%@')", __func__,
    //                constructed, [_compiledConstrJSFunc class], result);
        
    BOOL retVal = NO;
    if ( !constructed || error) {
        [self _setError:error];
    } else {
        _constructedObj = constructed;  // was retained above
        retVal = YES;
    }
    EXITARPOOL
    EXITCONTEXTLOCK
    return retVal;
}

- (id)jsConstructedThis {
    return _constructedObj; }


- (BOOL)setScript:(NSString *)scr forKey:(NSString *)key parameterNames:(NSArray *)params
{
    if ( !scr) scr = @"";

    if ( !key) {
        [self _setError:[NSError errorWithDomain:LQJSKitErrorDomain code:103 userInfo:nil]];
        return NO;
    }
    
    if ( !params) params = [NSArray array];

    ///NSLog(@"%s: key %@; paramnames %@", __func__, key, params);

    ENTERCONTEXTLOCK
    ENTERARPOOL
    
    NSError *error = nil;
    id compiled = [_jsInterp compileScript:scr functionName:key
                                                  parameterNames:params
                                                  error:&error];

    BOOL retVal = NO;
    if ( !compiled || error) {
        //NSLog(@"  ... FAILED to set script (key %@): error %@\n", key, error);
        [self _setError:error];
    } else {
        [compiled setProtected:YES];
        [_scripts setObject:scr forKey:key];
        [_compiledFuncs setObject:compiled forKey:key];
        [_scriptParamNames setObject:params forKey:key];
        ///NSLog(@"  ... success!\n  did compile (%@), %@", [compiled class], [_compiledFuncs objectForKey:key]);
        retVal = YES;
    }    
    EXITARPOOL
    EXITCONTEXTLOCK
    return retVal;
}

- (void)removeScriptForKey:(NSString *)key
{
    if ( !key) return;
    
    id compiled = [_compiledFuncs objectForKey:key];
    [compiled setProtected:NO];

    [_scripts removeObjectForKey:key];
    [_compiledFuncs removeObjectForKey:key];
    [_scriptParamNames removeObjectForKey:key];
}

- (void)removeAllScripts
{
    ENTERARPOOL
    NSEnumerator *keyEnum = [[[[_scripts allKeys] copy] autorelease] objectEnumerator];
    NSString *key;
    while (key = [keyEnum nextObject]) {
        [self removeScriptForKey:key];
    }
    EXITARPOOL
    NSAssert2([_scripts count] == 0 && [_compiledFuncs count] == 0, @"script count mismatch (%i, funcs %i)", (int)[_scripts count], (int)[_compiledFuncs count]);
}

- (NSArray *)scriptKeys {
    return [_scripts allKeys]; }
    
- (NSArray *)parameterNamesForKey:(NSString *)key {
    return [_scriptParamNames objectForKey:key]; }

- (NSString *)scriptForKey:(NSString *)key {
    return [_scripts objectForKey:key]; }



- (NSError *)lastError {
    return _lastError; }
    
- (NSError *)popLastError {
    NSError *err = [[_lastError retain] autorelease];
    [self _setError:nil];
    return err;
}

- (BOOL)executeScriptForKey:(NSString *)key withParameters:(NSArray *)params resultPtr:(id *)outResult
{
    id jsfunc = [_compiledFuncs objectForKey:key];
    if ( !jsfunc) {
        [self _setError:[NSError errorWithDomain:LQJSKitErrorDomain code:110 userInfo:[NSDictionary dictionaryWithObject:@"Function has not been set for key in JS container"
                                                                                                 forKey:NSLocalizedDescriptionKey]
                            ]];
        return NO;
    }
    
    if ( !params) params = [NSArray array];
    
    NSError *error = nil;
    BOOL retVal = NO;
    id result = nil;
    
    ENTERCONTEXTLOCK_EXEC
    ENTERARPOOL
    
    @try {
        if (_constructedObj) {
            result = [jsfunc callWithThis:_constructedObj parameters:params error:&error];
        } else {
            result = [jsfunc callWithParameters:params error:&error];
        }
    }
    @catch(NSException *exc) {
        NSMutableDictionary *userInfo = ([exc userInfo]) ? [NSMutableDictionary dictionaryWithDictionary:[exc userInfo]] : [NSMutableDictionary dictionary];
        
        [userInfo setObject:[NSString stringWithFormat:@"An exception occurred during JS call (key %@): %@: reason %@", key, [exc name], [exc reason]]
                     forKey:NSLocalizedDescriptionKey];
    
        error = [NSError errorWithDomain:LQJSKitErrorDomain code:114 userInfo:userInfo];
    }

    if (error) {
        NSLog(@"** execution failed for key %@; error:\n%@", key, error);        
        [self _setError:error];
        result = nil;
        retVal = NO;
    } else {
        retVal = YES;
    }
    if (outResult) [result retain];
    
    EXITARPOOL
    EXITCONTEXTLOCK_EXEC
    
    if (outResult) *outResult = [result autorelease];
    return retVal;
}

- (BOOL)callFunctionOnJSThis:(id)functionObj withParameters:(NSArray *)params resultPtr:(id *)outResult
{
    if ( ![functionObj isFunction])
        return NO;
    
    if ( !params) params = [NSArray array];
    
    NSError *error = nil;
    BOOL retVal = NO;
    id result = nil;
    
    ENTERCONTEXTLOCK_EXEC
    ENTERARPOOL
    
    @try {
        if (_constructedObj) {
            result = [functionObj callWithThis:_constructedObj parameters:params error:&error];    
        } else {
            result = [functionObj callWithParameters:params error:&error];
        }
    }
    @catch(NSException *exc) {
        NSMutableDictionary *userInfo = ([exc userInfo]) ? [NSMutableDictionary dictionaryWithDictionary:[exc userInfo]] : [NSMutableDictionary dictionary];
        
        [userInfo setObject:[NSString stringWithFormat:@"An exception occurred during JS function call: %@: reason %@", [exc name], [exc reason]]
                     forKey:NSLocalizedDescriptionKey];
    
        error = [NSError errorWithDomain:LQJSKitErrorDomain code:115 userInfo:userInfo];
    }
    
    if (error) {
        NSLog(@"** execution failed for function call on JS container's this object; error:\n%@", error);
        [self _setError:error];
        result = nil;
        retVal = NO;
    } else {
        retVal = YES;
    }
    if (outResult) [result retain];
    
    EXITARPOOL
    EXITCONTEXTLOCK_EXEC
    
    if (outResult) *outResult = [result autorelease];
    return retVal;
}

- (BOOL)constructGlobalVariable:(NSString *)var withParameters:(NSArray *)params resultPtr:(id *)outResult
{
    if ([var length] < 1) return NO;
    
    NSError *error = nil;
    BOOL retVal = NO;
    id result = nil;
    
    ENTERCONTEXTLOCK_EXEC
    ENTERARPOOL
    
    id constructor = [_jsInterp globalVariableForKey:var];
    if (constructor) {
        @try {
            result = [constructor constructWithParameters:params error:&error];
        }
        @catch (NSException *exc) {
            NSMutableDictionary *userInfo = ([exc userInfo]) ? [NSMutableDictionary dictionaryWithDictionary:[exc userInfo]] : [NSMutableDictionary dictionary];
            
            [userInfo setObject:[NSString stringWithFormat:@"An exception occurred during JS constructor call: %@: reason %@", [exc name], [exc reason]]
                         forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:LQJSKitErrorDomain code:116 userInfo:userInfo];
        }
    }
    
    if (error) {
        NSLog(@"** execution failed for constructor call on JS container global var '%@'; error:\n%@", var, error);
        [self _setError:error];
        result = nil;
        retVal = NO;
    } else {
        retVal = YES;
    }
    if (outResult) [result retain];
    
    EXITARPOOL
    EXITCONTEXTLOCK_EXEC
    
    if (outResult) *outResult = [result autorelease];
    return retVal;
}

@end


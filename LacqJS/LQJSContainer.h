//
//  LQJSContainer.h
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


#import "LQJSInterpreter.h"

/*
  An LQJSContainer is a "sandbox" that contains an interpreter and a bundle of named scripts.
*/

@interface LQJSContainer : NSObject {

    LQJSInterpreter *_jsInterp;
    
    NSString *_name;
    
    id _delegate;
    
    NSString *_constrScript;
    id _compiledConstrJSFunc;
    
    id _constructedObj;
    
    NSMutableDictionary *_scripts;
    NSMutableDictionary *_compiledFuncs;
    NSMutableDictionary *_scriptParamNames;
    
    NSError *_lastError;
}

- (id)initWithName:(NSString *)name;

- (id)initWithScriptsInJSContainer:(LQJSContainer *)jsContainer;

- (LQJSInterpreter *)interpreter;
- (JSContextRef)jsContextRef;

- (id)delegate;
- (void)setDelegate:(id)del;

- (NSString *)name;

// for convenience, the container can include a "this" object
// that is constructed with the given script and an optional bridge class.
- (BOOL)setConstructorScript:(NSString *)scr;
- (NSString *)constructorScript;

- (BOOL)construct;
- (id)jsConstructedThis;

- (BOOL)setScript:(NSString *)scr forKey:(NSString *)key parameterNames:(NSArray *)params;
- (void)removeScriptForKey:(NSString *)key;

- (void)removeAllScripts;

- (NSArray *)scriptKeys;
- (NSArray *)parameterNamesForKey:(NSString *)key;
- (NSString *)scriptForKey:(NSString *)key;

- (BOOL)executeScriptForKey:(NSString *)key withParameters:(NSArray *)params resultPtr:(id *)outResult;

- (BOOL)callFunctionOnJSThis:(id)functionObj withParameters:(NSArray *)params resultPtr:(id *)outResult;
- (BOOL)constructGlobalVariable:(NSString *)var withParameters:(NSArray *)params resultPtr:(id *)outResult;

- (NSError *)lastError;
- (NSError *)popLastError;

- (void)cleanupAfterRenderIteration;

- (void)clearAllState;

@end


@interface NSObject (LQJSContainerDelegate)

// the constructor script will be called for the returned object
- (id)createJSThisObjectForContainer:(id)jsContainer;

@end

//
//  JSKitInterpreter.h
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
#import "LacqJSExport.h"


LACQJS_EXPORT_VAR NSString * const LQJSKitVersionString;
LACQJS_EXPORT_VAR double LQJSKitVersionNumber;


#import "JSKitTypes.h"

@class LQJSKitObject;
@class LQJSKitInterpreter;
/*!
    @protocol	LQJSKitInterpreterDelegate
    @abstract    The callback routines that the interpreter makes to its delegate.
    @discussion  A LQJSKitInterpreter has various needs to let its delegate know when to do some common
	actions, such as print to a console or report an exception.
*/

@protocol LQJSKitInterpreterDelegate
/*!
    @method     jskitInterpreter:exception:
    @abstract   Display a runtime exception
    @discussion If an exception occurs during runtime, the interpreter will tell its delegate to
 display this information.
    @result Return true if the delegate has displayed the information.  If not, it will be reformatted
 and sent to the "log".
    @param  interperter The interpreter currently running
    @param  exception The exception, wrapped in an LQJSKitObject
*/

- (BOOL) jskitInterpreter: (LQJSKitInterpreter *) interpreter exception: (LQJSKitObject *) exception;
/*!
    @method     jskitInterpreter:print:
    @abstract   Print a message to the "console"
    @discussion The interpreter adds a "print" command to the context automatically.  This is called when
    something is printed via that command (this can be a simple informative or status message)
    @param  interperter The interpreter currently running
    @param  message The message to print
*/

- (void) jskitInterpreter: (LQJSKitInterpreter *) interpreter print: (NSString *) message;

/*!
 @method     jskitInterpreter:log:
 @abstract   Log a message to the "console"
 @discussion The interpreter adds a "log" command to the context automatically.  This is called when
 something is printed via that command (this is usually a debugging or error message)
 @param  interperter The interpreter currently running
 @param  message The message to print
 */
- (void) jskitInterpreter: (LQJSKitInterpreter *) interpreter log: (NSString *) message;
@end

/*!
    @class  LQJSKitInterpreter
    @abstract    Wrapper around JavaScriptCore interpreter context
    @discussion  LQJSKitInterpereter represents an interpreter (including its global variable state).  Multiple interpreters can coexist
    in a given application, with different globals states (and thus different capabilities).  This class evaluates scripts, returning results.
    This object also provides ways to modify the global state (such as adding in new bridge objects and packages), as well as adding in
    a few simple commands to print and import other scripts (NB, by default there is no search path, and thus it will not be able to include
    other scripts).
*/

@interface LQJSKitInterpreter : NSObject {
    JSContextGroupRef _globalCtxGroup;
    JSGlobalContextRef _globalCtx;
    JSClassRef _globalClassRef;
    id _delegate;
    
    NSMutableDictionary *myPackages;
    NSMutableDictionary *myConstructors;
    NSMutableDictionary *myConstructorsByBridgeClass;
    NSArray *myIncludePaths;
    BOOL myPropagatesExceptions;
}

/*!
    @method      init
    @abstract   Designated initializer
    @discussion Creates a new JavaScriptCore context to interpret code, and adds the routines "print()", "log()", and "import()".
    @result     The newly initialized interpreter
*/
- (id) init;

/*!
    @method     setDelegate:
    @abstract   Set the interpreter delegate
    @param	delegate An interpreter delegate (should conform to the protocol LQJSKitInterpreterDelegate)
    @discussion The interpreter delegate is called to handle printing information.
*/
- (void) setDelegate: (id) delegate;
/*!
    @method      delegate
    @abstract   Returns the current delegate
    @result     The current interpreter delegate, if any
*/
- (id) delegate;
/*!
    @method      garbageCollect
    @abstract   Call the JavaScript garbabe collection
    @discussion Garbage collection normally happens automatically as needed, making explicit garbage collection rare.
*/
- (void) garbageCollect;

// various eval routines.  If there is no error
/*!
    @method     evaluateScript:
    @abstract   Evaluate the given script
    @discussion Evaluates the script, ignoring any errors.  This just calles evaluateScript:thisValue:error:
 @param	script The JavaScript script to run
    @result	The value of the script (usually the last expression)
*/
- (id) evaluateScript: (NSString *) script;
/*!
 @method     evaluateScript:error:
 @abstract   Evaluate the given script
 @discussion Evaluates the script, ignoring any errors.  This just calles evaluateScript:thisValue:error:
 @param	script The JavaScript script to run
 @param error A pointer to an NSError that will be set to the error, if any, that occurs.
 @result	The value of the script (usually the last expression)
 */
- (id) evaluateScript: (NSString *) script error: (NSError **)error;
/*!
 @method     evaluateScript:thisValue:
 @abstract   Evaluate the given script
 @discussion Evaluates the script, ignoring any errors.  This just calles evaluateScript:thisValue:error:
 @param	script The JavaScript script to run
 @param thisValue The 'this' value for the context of the script
 @result	The value of the script (usually the last expression)
 */
- (id) evaluateScript: (NSString *) script thisValue: (LQJSKitObject *) thisValue;
/*!
 @method     evaluateScript:thisValue:error:
 @abstract   Evaluate the given script
 @discussion Evaluates the script, ignoring any errors.  This is the routine that ultimately compiles and runs the script.
 @param	script The JavaScript script to run
 @param thisValue The 'this' value for the context of the script
 @param error A pointer to an NSError that will be set to the error, if any, that occurs.
 @result	The value of the script (usually the last expression)
 */
- (id) evaluateScript: (NSString *) script thisValue: (LQJSKitObject *) thisValue error: (NSError **)error;
/*!
    @method     compileScript:functionName:parameterNames:error:
    @abstract   Compiles a given script as a function, with an array of parameters
    @discussion Compiles the script into a new function.  The function name, and the name of the parameters, are provided.
 @param	script The JavaScript script to run
 @param name The name of the compiled function to create
 @param params The names of the parameters of the function, as an array of NSStrings
 @param error A pointer to an NSError that will be set to the error, if any, that occurs.
 @result The compiled function
*/
- (id) compileScript: (NSString *) script functionName: (NSString *) name parameterNames: (NSArray *) params error: (NSError **)error;


// 2009.07.04 -- this method added by Pauli Ojala.
//
// the given function script is expected to be in the format returned JavaScriptCore for function objects:
// e.g.  function foo(a, b, c, d) { ... }
// 
// this method is a convenience that parses the arguments and calls -compileScript:functionName:.. with a nil function name.
// (the name given for the function in the script is ignored.)
//
- (id) compileAnonymousFormattedFunction:(NSString *)functionScript error:(NSError **)error;


// 2009.10.21 -- this method added by Pauli Ojala.
// this solves a thorny problem when an anonymous function needs to be stored,
// e.g. in LQStreamPatch's setInterval() implementation.
// the function is created in a private context and will be picked by the GC unless it's "recontextualized"
// into the main context.
//
- (id) recontextualizeObject:(id)obj;


/*!
    @method     includeScript:error:
    @abstract   Finds a script within the current search path, and compiles and runs it
 @param relativePath The partial path to search
 @param error A pointer to an NSError that will be set to the error, if any, that occurs.
    @discussion This routine searches the current search path (as set by setIncludePaths:) to find a script whose path ends with the relative path.  If found,
 it is compiled and run (using evaluateScript:error:).
 @result	The value of the script (usually the last expression)
*/
- (id) includeScript: (NSString *) relativePath error: (NSError **)error; // looks in the include paths to find the relative string

// By defualt, include paths is empty (so include won't do anything)

/*!
    @method     setIncludePaths:
    @abstract   Specify where to search for included files (via the script level 'include("path")' as well as includeScript:error:)
    @discussion <#(comprehensive description)#>
 @param paths An array of strings, specifying relative and absolute paths.  Relative paths begin with "./" (or are just "."), and are
 relative to the current working directory.  Absolute paths have begin with a "/" (indicating that they start from the root volume).
*/
- (void) setIncludePaths: (NSArray *) paths;

/*!
 @method      propagatesExceptions
 @abstract   Determines if exceptions are propagated outside of the various compileScript: methods
 @discussion By default, an error is set when compileScript: comes across a JavaScript exception.  Instead, an NSException can be thrown to be handled as the client desires.
 @result     If the interpreter will raise an exception when it hits a JavaScript exception.
 */
- (BOOL) propagatesExceptions;
/*!
    @method     setPropagatesExceptions:
    @abstract   Turn on or off the propegation of JavaScript exceptions
 @param propagates Determins if the exception should be propagated as an NSException
*/
- (void) setPropagatesExceptions: (BOOL) propagates;

// globals
/*!
    @method     globalVariableForKey:
    @abstract   Get the value of a global variable from the interpreter
 @param key The name of the global variable to look up
    @discussion Gets the value of the global variable, translating it to an Objective-C object (such as NSNumber or LQJSKitObject).
    @result     The value of the global
*/
- (id) globalVariableForKey: (NSString *) key;
/*!
    @method     setGlobalVariable:forKey:
    @abstract   Set the value of a global variable for the interpreter
 @param value  The value of the global
 @param key The name of the global
    @discussion Sets a global variable (creating it if needed) to a given value.  This value will be bridged to an appropriate JavaScript value.
*/
//
- (void) setGlobalVariable: (id) value forKey: (NSString *) key;


// 2009.04.21 -- this method added by Pauli Ojala to allow for creation of read-only globals
- (void) setGlobalVariable: (id) value forKey: (NSString *) key options: (LQJSKitPropertyAttributes) propAttrs;


/*!
 @method      emptyObject
 @abstract   Creates a new "empty" subclass of Object
 @discussion Does the equivalent of evaluating the script "new Object();"
 @result     The created object
 */
 
// 2009.04.22 -- renamed by Pauli Ojala (was -emptyObject)
- (LQJSKitObject *) emptyProtectedJSObject;

// 2009.07.15 -- added by Pauli Ojala
- (id) emptyProtectedJSArray;

/*!
    @method     addFunction:target:selector:
    @abstract   Registers a simple "target/action" callback for a global JavaScript function
 @param name The name of the global routine
 @param target The target that will get invoked when the JavaScript function is called
 @param sel The selector of the method that will get invoked when the JavaScript funciton is called
    @discussion This will add a simple "static" global function.  The parameters of the function will be passed as an NSArray (of appropriate
 Objective-C objects).  This method should return a value that will be the return value of the function (nil is a perfectly acceptable result).  For example,
 if you're class Foo had a method bar: that is to be called by the function "bar(parameters...)", then it would be registered as:
    [myInterpeter addFunction: @"bar" target: self selector: @selector(bar:)];
 
The bar method would be implemented as:
 
    - (id) bar: (NSArray *) arguments
    {
	return [NSNumber numberWithInt: [arguments count]]; // return a count of how many parameters were passed to the function
    }
 
    The function can also be a "fast path" (i.e., no conversion between JS values and ObjC values - you get and return raw JSValueRefs).
 This provides performance enhancement for those places where you really need them, or need special handling of the parameters.  Of course it also requires
 you to write code that directly uses the JavaScriptCore API.  NB - the routine IMP is cached, so there might be some edge cases where loading a category later
 on results in the "pre-category" version code being called.
*/
- (void) addFunction: (NSString *) name target: (id) target selector: (SEL) sel;

/*!
 @method     addRawFunction:target:selector:
 @abstract   Registers a "raw" callback for a global JavaScript function
 @param name The name of the global routine
 @param target The target that will get invoked when the JavaScript function is called
 @param sel The selector of the method that will get invoked when the JavaScript funciton is called
 @discussion This will add a simple "static" global function.  The method needs to be in the form:
 
 - (JSValueRef) invokeWithContext: (JSContextRef) ctx arguments: (const JSValueRef *)arguments count: (size_t) count exception: (JSValueRef*) exception

 This provides performance enhancement for those places where you really need them, or need special handling of the parameters.  Of course it also requires
 you to write code that directly uses the JavaScriptCore API.  NB - the routine IMP is cached, so there might be some edge cases where loading a category later
 on results in the "pre-category" version code being called.
 */
- (void) addRawFunction: (NSString *) name target: (id) target selector: (SEL) sel;


/*!
    @method     checkSyntax:
    @abstract   Check to see if a string is syntactically valid JavaScript
    @discussion Calls checkSyntax:error: (and ignores the error)
 @param script The script code to check
    @result     Returns true if the string is free of syntax errors.
*/
- (BOOL) checkSyntax: (NSString *) script;
/*!
 @method     checkSyntax:error:
 @abstract   Check to see if a string is syntactically valid JavaScript
 @discussion Checks the syntactic validity of the script, but does not run the result.
 @param script The script code to check
 @param error The syntax error, if any, that occurs (this encapsulates the line number, amongst other things)
 @result     Returns true if the string is free of syntax errors.
 */
- (BOOL) checkSyntax: (NSString *) script error: (NSError **)error;

@end

@interface LQJSKitInterpreter(Internal)
- (BOOL) handleException: (JSValueRef) exception;
- (id) convertJSValueRef: (JSValueRef) jsValue;
+ (id) convertJSValueRef: (JSValueRef) jsValue context:(JSContextRef) ctx;
+ (NSArray *) convertJSValueRefs: (const JSValueRef *) jsValues count: (NSUInteger)count context:(JSContextRef) ctx;
- (JSValueRef) createJSValueRef: (id) value;
+ (JSValueRef) createJSValueRef: (id) value context: (JSContextRef) ctx;
- (JSGlobalContextRef) context;
+ (LQJSKitInterpreter *) interpreterForContext: (JSGlobalContextRef) ctx;
@end



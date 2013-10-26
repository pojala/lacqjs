//
//  LQJSBridgeObject.h
//  LacqJS
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


#import <Foundation/Foundation.h>
#import "JSKitTypes.h"
#import "JSKitInterpreter.h"
#import "LQScriptBridging.h"


@interface LQJSBridgeObject : NSObject  <LQScriptBridging> {

    JSObjectRef _jsObject;
    JSContextRef _jsContext;
    
    id _owner;
}

- (id)initInJSContext:(JSContextRef)context withOwner:(id)owner;

- (void)setOwner:(id)newOwner;
- (id)owner;
- (id)objcOwnerOfJSObject;

+ (JSClassRef)jsClassRef;

- (JSContextRef)jsContextRef;

- (JSObjectRef)jsObjectRef;

- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)value forKey:(NSString *)key options:(LQJSKitPropertyAttributes)propAttrs;

// method call interface to match JSKitObject
- (id)callMethod:(NSString *)name withParameters:(NSArray *)param error:(NSError **)error;

// utilities for bridge implementations
- (BOOL)parseByteFromArg:(id)arg outValue:(uint8_t *)b;
- (BOOL)parseLongFromArg:(id)arg outValue:(long *)l;

// creates an empty Object in the same JS context as this bridge;
// useful for returning dictionaries
- (LQJSKitObject *)emptyProtectedJSObject;

// the "contextObj" passed to js function implementations is an opaque Obj-C object;
// this should be called to get the context from it.
- (JSContextRef)jsContextRefFromJSCallContextObj:(id)contextObj;

@end


@interface LQJSKitInterpreter(BridgeObjects)
/*!
 @method     loadBridge:
 @abstract   Adds a bridge class to the interpreter context
 @param bridgeClassObject A class object that represents the bridge class (a subclass of LQJSKitBridgeObject)
 @discussion Adds a constructor to the curernt context that will create a new instance of the bridgeObjectClass when called.
 */
//- (void) loadBridge: (id) bridgeObjectClass;
// ^^^ 2009.04.24 / Pauli -- method renamed to:
- (void)loadBridgeClass:(Class)bridgeObjectClass;

/*!
 @method     bridgeObject:withConstructorArguments:
 @abstract   Creates (from Objective-C) a new bridge object of a given class, with specified arguments
 @discussion Creating a new bridge object involves some lower level manipulation to be able to expose the
 result properly to the appropriate JavaScript interpreter context.  This routine will make an object of a given
 class in the same context as the receiver, and then awaken the object, and finally return the bridge object.
 @param      cls The class to create.  Should be a subclass of LQJSKitBridgeObject
 @param      arguments The parameter list to pass to awakeFromConstructor
 @result     The newly created, auto-released object.
 */
- (id)bridgeObject:(id)cls withConstructorArguments:(NSArray *)arguments;

// these constructor access methods added 2009.06.29 by Pauli
- (id)constructorNamed:(NSString *)name;
- (Class)bridgeClassForJSConstructor:(JSObjectRef)constr;

@end

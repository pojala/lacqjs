/*
 *  LQScriptBridging.h
 *  JSKit
 *
 *  Created by Pauli Ojala on 24.4.2008.
 *  Copyright 2008 Lacquer oy/ltd.
 *
 */
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


/*
  all the methods of JSKitBridgeObject as a protocol.

  needs to be implemented by an object that presents a JavaScript interface
  (typically to an Objective-C object behind the scenes)
*/
@protocol LQScriptBridging

- (void)awakeFromConstructor:(NSArray *) arguments; // called with the parameters in the constructor

+ (NSString *)constructorName;
+ (NSArray *)objectPropertyNames;
+ (NSArray *)objectFunctionNames; // if  the function is named "foo" the selector called is "jskitCallFoo:"
+ (BOOL)canWriteProperty:(NSString *)propertyName;
+ (BOOL)canDeleteProperty:(NSString *)propertyName;
+ (BOOL)canEnumProperty:(NSString *)propertyName; // defaults to YES

- (id)bridgeObject:(id)cls withConstructorArguments:(NSArray *)arguments;

+ (BOOL)hasArrayIndexingGetter;
+ (BOOL)hasArrayIndexingSetter;
- (int)lengthForArrayIndexing;
- (id)valueForArrayIndex:(int)index;
- (void)setValue:(id)value forArrayIndex:(int)index;

- (BOOL)isByteArray;
- (uint8_t)byteValueForArrayIndex:(int)index;
- (void)setByteValue:(uint8_t)b forArrayIndex:(int)index;

@end


/*
  a protocol that should be implemented by JS bridge objects that can be copied
  from one JS context to another.
  
  Conduit makes use of this functionality by giving each node its own JS sandbox
  and copying contents of the sandbox when the node is copied.
*/
@protocol LQJSCopying

// constructs the object in the given context (as if constructed from within the context, i.e. owner == nil)
// and returns the new object autoreleased
- (id)copyIntoJSContext:(JSContextRef)dstContext;

@end


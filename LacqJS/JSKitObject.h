//
//  JSKitObject.h
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
#import "JSKitTypes.h"


@protocol LQJSKitConversion
- (BOOL) jskitAsBoolean;
- (double) jskitAsNumber;
- (NSString *) jskitAsString;
@end

/*!
    @class       LQJSKitObject 
    @superclass  NSObject
    @abstract    An Objective-C object that "wraps" around a JavaScript object reference
    @discussion  LQJSKitObject provides the basic mechanism for accessing JavaScript object references
 from Objective-C.
*/
@interface LQJSKitObject : NSObject {
    JSContextRef myContext;
    JSObjectRef myObject;
    
    BOOL _isProtected;  // added by Pauli Ojala, 2009.07.22
}
/*!
    @method     valueForKey:
    @abstract   For KVO support, gets a given value from the JavaScript object
    @discussion Calls the JavaScriptCore routines to fetch the JavaScript object's value for the key, if any.
    @param      key The name of the property
    @result     The value of, if any.  Accessing non-existent properties of JavaScript is valid, so we just return nil.
 If the value is a simple type (such as number or string) a corresponding NSObject is created, otherwise the value is
 wrapped using a new LQJSKitObject
*/
- (id) valueForKey: (NSString *) key;
/*!
    @method     setValue:forKey:
    @abstract   Sets the value of a JavaScript object's property
    @discussion Takes the value and converts it to a JavaScript value (either by translating simple values such as NSString
 and NSNumber, unwraps the JavaScript object from a LQJSKitObject, or makes a bridge object), and sets the JavaScript object's
 property
    @param      value What to set the property to.  If nil, then the property is deleted
    @param      key The name of the property
*/
- (void)setValue:(id)value forKey:(NSString *)key;

// added by Pauli Ojala
- (void)setProperty:(id)value forKey:(NSString *)key options:(LQJSKitPropertyAttributes)propAttrs;


/*!
    @method      allKeys
    @abstract   All the properties of the JavaScript object
    @discussion Retrieves all the named properties of a given JavaScript object
    @result     An array of property names
*/
- (NSArray *) allKeys;
/*!
    @method      isFunction
    @abstract   Tests to see if the JavaScript object is a function
    @discussion Calls the JavaScriptCore routines to determine if an object can be called as a function
    @result     YES if the object is a function
*/
- (BOOL) isFunction;
/*!
    @method      isConstructor
    @abstract   Tests to see if the JavaScript object is a constructor
    @discussion Calls the JavaScriptCore routines to determine if an object can be called as a constructor
    @result     YES if the object is a constructor
*/
- (BOOL) isConstructor;
/*!
    @method     isConstructedBy:
    @abstract   Checks to see if the object is constructed by a given constructor
    @discussion Calls the JavaScriptCore routines to check constructors, as compared by the JavaScript 'instanceof' operator
    @param      constructor The constructor to test.
    @result     YES if the object is constructed by the constructor
*/
- (BOOL) isConstructedBy: (LQJSKitObject *) constructor;
/*!
    @method      constructor
    @abstract   Get the object's constructor
    @result     The object's constructor
*/
- (LQJSKitObject *) constructor;

/*!
    @method     callWithParameters:error:
    @abstract   Call the object as a function with a list of parameters
    @param      params A list of parameters to provide to the function.  Can be nil
    @param      error A pointer to an error that will be set if an error occurs while executing the function.
 If nil, an exception will be thrown instead
    @result     The result of the function
*/
- (id) callWithParameters:  (NSArray*) params error: (NSError **)error;
/*!
    @method     callWithThis:parameters:error:
    @abstract   Call a function with an explicit value for JavaScript's 'this'
    @discussion Similar to callWithParameters:error: but provides for an explicit 'this' object
    @param      thisObject the value of JavaScript's 'this' object
 @param      params A list of parameters to provide to the function.  Can be nil
 @param      error A pointer to an error that will be set if an error occurs while executing the function.
 If nil, an exception will be thrown instead
 @result     The result of the function
 */
- (id) callWithThis: (LQJSKitObject *) thisObject parameters:  (NSArray*) param error: (NSError **)error;


// added by Pauli Ojala, 2009.11.25
- (id) callAndProtectResultWithThis: (LQJSKitObject *) thisObject parameters:  (NSArray*) param error: (NSError **)error;


/*!
    @method     callMethod:withParameters:error:
    @abstract   Calls a method of the object
    @discussion Gets a property of the object and then calls it with the current object as 'this'
    @param      name The name of the method to be called
 @param      params A list of parameters to provide to the method.  Can be nil
 @param      error A pointer to an error that will be set if an error occurs while executing the method.
 If nil, an exception will be thrown instead
 @result     The result of the method
 */
- (id) callMethod: (NSString *) name withParameters:  (NSArray*) param error: (NSError **)error;

/*!
    @method     constructWithParameters:error:
    @abstract   Constructs a new object using the object as a constructor
    @discussion Similar to JavaScript's "new Thing(params)"
    @param      param A list of parameters to pass to the constructor.  Can be nil
 @param      error A pointer to an error that will be set if an error occurs while executing the constructor.
 If nil, an exception will be thrown instead
    @result     The newly constructed object
*/
- (id) constructWithParameters:  (NSArray*) param error: (NSError **)error;
/*!
    @method      prototype
    @abstract   Gets the object's prototype
    @result     The prototype of the object
*/
- (LQJSKitObject *) prototype;
/*!
    @method     setPrototype:
    @abstract   Sets the object's prototype
    @param      prototype The new prototype of the object
*/
- (void) setPrototype: (LQJSKitObject *) prototype;

// added by Pauli Ojala
- (BOOL)isProtected;
- (void)setProtected:(BOOL)f;

@end

@interface LQJSKitObject(Internal)
+ (LQJSKitObject *) objectWithObject:(JSObjectRef) jsObject context: (JSContextRef) context;
- (id) initWithObject: (JSObjectRef) jsObject context: (JSContextRef) context;
- (JSObjectRef)jsObjectRef;
- (JSContextRef)jsContextRef;
@end

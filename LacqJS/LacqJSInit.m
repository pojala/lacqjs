//
//  LacqJSInit.m
//  JSKit
//
//  Created by Pauli Ojala on 9.9.2008.
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


#import "LacqJSInit.h"
#import "LQJSInterpreter.h"


extern void LQJSKitWrappers_initStatics();


int LacqJSInitialize()
{
    LQJSKitWrappers_initStatics();
    
#ifdef __APPLE__
    // no need to run the test on Mac
    return 0;
#endif
    
    // on Windows, run a small test to ensure that the JavaScriptCore dll has been
    // properly loaded and is functional.
    
    int retVal = 0;
    id testJs = [[LQJSInterpreter alloc] init];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSString *testScr = @"aFunc = function(a) { return a * 3 };"
                         "a = aFunc(7);"
                        ; 
                        
    NSError *error = nil;
    id result = [testJs evaluateScript:testScr thisValue:nil error:&error];

    ///NSLog(@"  -- created interpreter object: %@ -- ran test, result is %@ (expected 21)", testJs, result);

    retVal = ([result intValue] == 21) ? 0 : 1;
    
    if (retVal != 0) {
        NSLog(@"*** %s failed, JS error was: %@", __func__, error);
    }
    
    [pool release];
    [testJs release];
    
    return retVal;
}

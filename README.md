LacqJS
======

LacqJS is a framework that provides an Objective-C API for JavaScriptCore bindings.

It has been deployed on two platforms:

  * Mac OS X 10.4+  
  * Windows using the Cocotron framework and its cross-compiler for XCode
  
For Windows, you need the JavaScriptCore library as a DLL. I've compiled one from the WebKit sources, but it's a few years behind the latest WebKit. If you'd like to get it anyway, please send me an email at pauli <at> lacquer <dot> fi
  

License and acknowledgements
============================  

LacqJS is based on _JSKit_ created by Glenn Andreas. The code was forked in 2008.

Both Glenn Andreas' original JSKit and the derived LacqJS framework are licensed under an MIT-style license.
The license follows:

----
Copyright (C) 2008-13 Lacquer oy/ltd.
Copyright (C) 2008 gandreas software. 

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
----

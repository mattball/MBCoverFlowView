/*
 
 The MIT License
 
 Copyright (c) 2009 Matthew Ball
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

#import "NSImage+MBCoverFlowAdditions.h"


@implementation NSImage (MBCoverFlowAdditions)

- (CGImageRef)imageRefCopy
{
	CGContextRef context = CGBitmapContextCreate(NULL/*data - pass NULL to let CG allocate the memory*/, 
												   [self size].width,  
												   [self size].height, 
												   8,
												   0, 
												   [[NSColorSpace genericRGBColorSpace] CGColorSpace], 
												   kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
	
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO]];
	[self drawInRect:NSMakeRect(0,0, [self size].width, [self size].height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	[NSGraphicsContext restoreGraphicsState];
	
	CGImageRef cgImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	
	return cgImage;
}

@end

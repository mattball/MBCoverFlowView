//
//  NSImage+MBCoverFlowAdditions.m
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/23/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import "NSImage+MBCoverFlowAdditions.h"


@implementation NSImage (MBCoverFlowAdditions)

- (CGImageRef)imageRef
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

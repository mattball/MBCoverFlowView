//
//  MBCoverFlowImageLoadOperation.m
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/28/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import "MBCoverFlowImageLoadOperation.h"

#import "NSImage+MBCoverFlowAdditions.h"

@implementation MBCoverFlowImageLoadOperation

@synthesize layer=_layer, imageKeyPath=_imageKeyPath;

- (id)initWithLayer:(CALayer *)layer imageKeyPath:(NSString *)imageKeyPath;
{
	if (self = [super init]) {
		_layer = [layer retain];
		_imageKeyPath = [imageKeyPath copy];
	}
	return self;
}

- (void)dealloc
{
	self.layer = nil;
	self.imageKeyPath = nil;
	[super dealloc];
}

- (BOOL)isConcurrent
{
	return NO;
}

- (void)main
{
	@try {
		NSImage *image;
		NSObject *object = [self.layer valueForKey:@"representedObject"];
		
		if (self.imageKeyPath != nil) {
			image = [object valueForKeyPath:self.imageKeyPath];
		} else if ([object isKindOfClass:[NSImage class]]) {
			image = (NSImage *)object;
		}
		
		CGImageRef imageRef = [image imageRef];
		
		CALayer *imageLayer = [[self.layer sublayers] objectAtIndex:0];
		CALayer *reflectionLayer = [[imageLayer sublayers] objectAtIndex:0];
		
		imageLayer.contents = (id)imageRef;
		reflectionLayer.contents = (id)imageRef;
		imageLayer.backgroundColor = NULL;
		reflectionLayer.backgroundColor = NULL;
	} @catch (NSException *e) {
		// If the key path isn't valid, do nothing
	}
}

@end

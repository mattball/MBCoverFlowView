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

@synthesize layer=_layer, imageKeyPath=_imageKeyPath, placeholder=_placeholder;

- (id)initWithLayer:(CALayer *)layer imageKeyPath:(NSString *)imageKeyPath placeholder:(NSImage *)placeholder
{
	if (self = [super init]) {
		_layer = [layer retain];
		_imageKeyPath = [imageKeyPath copy];
		_placeholder = [placeholder retain];
	}
	return self;
}

- (void)dealloc
{
	self.layer = nil;
	self.imageKeyPath = nil;
	self.placeholder = nil;
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
		
		if (!image) {
			image = self.placeholder;
			[self.layer setValue:[NSNumber numberWithBool:NO] forKey:@"hasImage"];
		} else {
			[self.layer setValue:[NSNumber numberWithBool:YES] forKey:@"hasImage"];
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

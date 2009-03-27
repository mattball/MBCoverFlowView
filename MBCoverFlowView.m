//
//  MBCoverFlowView.m
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/13/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import "MBCoverFlowView.h"

#import "MBCoverFlowScroller.h"
#import "NSImage+MBCoverFlowAdditions.h"

#import <QuartzCore/QuartzCore.h>

// Constants
const float MBCoverFlowViewHorizontalMargin = 12.0;

// Layer Dimensions
const float MBCoverFlowViewCellSpacing = 14.0;

const float MBCoverFlowViewDefaultItemWidth = 140.0;
const float MBCoverFlowViewDefaultItemHeight = 100.0;

const float MBCoverFlowViewTopMargin = 30.0;
const float MBCoverFlowViewBottomMargin = 20.0;

const float MBCoverFlowScrollerHorizontalMargin = 80.0;
const float MBCoverFlowScrollerVerticalSpacing = 16.0;

#define MBCoverFlowViewContainerMinY (NSMaxY([self.accessoryController.view frame]) - 3*[self itemSize].height/4)

// Perspective parameters
const float MBCoverFlowViewPerspectiveCenterPosition = 100.0;
const float MBCoverFlowViewPerspectiveSidePosition = 0.0;
const float MBCoverFlowViewPerspectiveSideSpacingFactor = 0.75;
const float MBCoverFlowViewPerspectiveRowScaleFactor = 0.85;
const float MBCoverFlowViewPerspectiveAngle = 0.79;

// Key Codes
#define MBLeftArrowKeyCode 123
#define MBRightArrowKeyCode 124

@interface MBCoverFlowView ()
- (float)_positionOfSelectedItem;
- (CALayer *)_newLayer;
@end


@implementation MBCoverFlowView

@synthesize accessoryController=_accessoryController, selectionIndex=_selectionIndex, 
            itemSize=_itemSize, content=_content;

#pragma mark -
#pragma mark Life Cycle

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		[self setAutoresizesSubviews:YES];
		
		// Create the scroller
		_scroller = [[MBCoverFlowScroller alloc] initWithFrame:NSMakeRect(10, 10, 400, 16)];
		[_scroller setKnobProportion:1.0];
		[_scroller setEnabled:YES];
		[_scroller setTarget:self];
		[_scroller setAction:@selector(scrollerWasClicked:)];
		[self addSubview:_scroller];
		
		_leftTransform = CATransform3DMakeRotation(-0.79, 0, -1, 0);
		_rightTransform = CATransform3DMakeRotation(MBCoverFlowViewPerspectiveAngle, 0, -1, 0);
	
		_itemSize = NSMakeSize(MBCoverFlowViewDefaultItemWidth, MBCoverFlowViewDefaultItemHeight);
	
		
		CALayer *rootLayer = [CALayer layer];
		rootLayer.layoutManager = [CAConstraintLayoutManager layoutManager];
		rootLayer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
		[self setLayer:rootLayer];
		
		_containerLayer = [CALayer layer];
		_containerLayer.name = @"body";
		[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidX relativeTo:@"superlayer" attribute:kCAConstraintMidX]];
		[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintWidth relativeTo:@"superlayer" attribute:kCAConstraintWidth offset:-20]];
		[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY offset:MBCoverFlowViewContainerMinY]];
		[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY offset:-10]];
		[rootLayer addSublayer:_containerLayer];
		
		_scrollLayer = [CAScrollLayer layer];
		_scrollLayer.scrollMode = kCAScrollHorizontally;
		_scrollLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
		_scrollLayer.layoutManager = self;
		[_containerLayer addSublayer:_scrollLayer];
		
		// Create a gradient image to use for image shadows
		CGRect gradientRect;
		gradientRect.origin = CGPointZero;
		gradientRect.size = NSSizeToCGSize([self itemSize]);
		size_t bytesPerRow = 4*gradientRect.size.width;
		void* bitmapData = malloc(bytesPerRow * gradientRect.size.height);
		CGContextRef context = CGBitmapContextCreate(bitmapData, gradientRect.size.width,
													 gradientRect.size.height, 8,  bytesPerRow, 
													 CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB), kCGImageAlphaPremultipliedFirst);
		NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithDeviceWhite:0 alpha:0.6] endingColor:[NSColor colorWithDeviceWhite:0 alpha:1.0]];
		NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:nsContext];
		[gradient drawInRect:NSMakeRect(0, 0, gradientRect.size.width, gradientRect.size.height) angle:90];
		[NSGraphicsContext restoreGraphicsState];
		_shadowImage = CGBitmapContextCreateImage(context);
		CGContextRelease(context);
		free(bitmapData);
		[gradient release];
		
		
		/* create a pleasant gradient mask around our central layer.
		 We don't have to worry about re-creating these when the window
		 size changes because the images will be automatically interpolated
		 to their new sizes; and as gradients, they are very well suited to
		 interpolation. */
		CALayer *maskLayer = [CALayer layer];
		_leftGradientLayer = [CALayer layer];
		_rightGradientLayer = [CALayer layer];
		_bottomGradientLayer = [CALayer layer];
		
		// left
		gradientRect.origin = CGPointZero;
		gradientRect.size.width = [self frame].size.width;
		gradientRect.size.height = [self frame].size.height;
		bytesPerRow = 4*gradientRect.size.width;
		bitmapData = malloc(bytesPerRow * gradientRect.size.height);
		context = CGBitmapContextCreate(bitmapData, gradientRect.size.width,
										gradientRect.size.height, 8,  bytesPerRow, 
										CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB), kCGImageAlphaPremultipliedFirst);
		gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithDeviceWhite:0. alpha:1.] endingColor:[NSColor colorWithDeviceWhite:0. alpha:0]];
		nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:nsContext];
		[gradient drawInRect:NSMakeRect(0, 0, gradientRect.size.width, gradientRect.size.height) angle:0];
		[NSGraphicsContext restoreGraphicsState];
		CGImageRef gradientImage = CGBitmapContextCreateImage(context);
		_leftGradientLayer.contents = (id)gradientImage;
		CGContextRelease(context);
		CGImageRelease(gradientImage);
		free(bitmapData);
		
		// right
		bitmapData = malloc(bytesPerRow * gradientRect.size.height);
		context = CGBitmapContextCreate(bitmapData, gradientRect.size.width,
										gradientRect.size.height, 8,  bytesPerRow, 
										CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB), kCGImageAlphaPremultipliedFirst);
		nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:nsContext];
		[gradient drawInRect:NSMakeRect(0, 0, gradientRect.size.width, gradientRect.size.height) angle:180];
		[NSGraphicsContext restoreGraphicsState];
		gradientImage = CGBitmapContextCreateImage(context);
		_rightGradientLayer.contents = (id)gradientImage;
		CGContextRelease(context);
		CGImageRelease(gradientImage);
		free(bitmapData);
		
		// bottom
		gradientRect.size.width = [self frame].size.width;
		gradientRect.size.height = 32;
		bytesPerRow = 4*gradientRect.size.width;
		bitmapData = malloc(bytesPerRow * gradientRect.size.height);
		context = CGBitmapContextCreate(bitmapData, gradientRect.size.width,
										gradientRect.size.height, 8,  bytesPerRow, 
										CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB), kCGImageAlphaPremultipliedFirst);
		nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:nsContext];
		[gradient drawInRect:NSMakeRect(0, 0, gradientRect.size.width, gradientRect.size.height) angle:90];
		[NSGraphicsContext restoreGraphicsState];
		gradientImage = CGBitmapContextCreateImage(context);
		_bottomGradientLayer.contents = (id)gradientImage;
		CGContextRelease(context);
		CGImageRelease(gradientImage);
		free(bitmapData);
		[gradient release];
		
		// the autoresizing mask allows it to change shape with the parent layer
		maskLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
		maskLayer.layoutManager = [CAConstraintLayoutManager layoutManager];
		[_leftGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:@"superlayer" attribute:kCAConstraintMinX]];
		[_leftGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY]];
		[_leftGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY]];
		[_leftGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxX relativeTo:@"superlayer" attribute:kCAConstraintMaxX scale:.5 offset:-[self itemSize].width / 2]];
		[_rightGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxX relativeTo:@"superlayer" attribute:kCAConstraintMaxX]];
		[_rightGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY]];
		[_rightGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY]];
		[_rightGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:@"superlayer" attribute:kCAConstraintMaxX scale:.5 offset:[self itemSize].width / 2]];
		[_bottomGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxX relativeTo:@"superlayer" attribute:kCAConstraintMaxX]];
		[_bottomGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY]];
		[_bottomGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:@"superlayer" attribute:kCAConstraintMinX]];
		[_bottomGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMinY offset:32]];
		
		_bottomGradientLayer.masksToBounds = YES;
		
		[maskLayer addSublayer:_rightGradientLayer];
		[maskLayer addSublayer:_leftGradientLayer];
		[maskLayer addSublayer:_bottomGradientLayer];
		// we make it a sublayer rather than a mask so that the overlapping alpha will work correctly
		// without the use of a compositing filter
		[_containerLayer addSublayer:maskLayer];
	}
	return self;
}

- (void)dealloc
{
	[_scroller release];
	[_scrollLayer release];
	[_containerLayer release];
	self.accessoryController = nil;
	CGImageRelease(_shadowImage);
	[super dealloc];
}

- (void)awakeFromNib
{
	[self setWantsLayer:YES];
}

#pragma mark -
#pragma mark Superclass Overrides

#pragma mark NSResponder

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{	
	switch ([theEvent keyCode]) {
		case MBLeftArrowKeyCode:
			self.selectionIndex -= 1;
			break;
		case MBRightArrowKeyCode:
			self.selectionIndex += 1;
			break;
		default:
			[self setItemSize:NSMakeSize(self.itemSize.width+14, self.itemSize.height+10)];
			[super keyDown:theEvent];
			break;
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSInteger clickedIndex = [self indexOfItemAtPoint:mouseLocation];
	if (clickedIndex != NSNotFound) {
		self.selectionIndex = clickedIndex;
	}
}

#pragma mark NSView

- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
	[self resizeSubviewsWithOldSize:[self frame].size];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
	// Reposition the scroller
	NSRect scrollerFrame = [_scroller frame];
	scrollerFrame.size.width = [self frame].size.width - 2*MBCoverFlowScrollerHorizontalMargin;
	scrollerFrame.origin.x = ([self frame].size.width - scrollerFrame.size.width)/2;
	scrollerFrame.origin.y = MBCoverFlowViewBottomMargin;
	[_scroller setFrame:scrollerFrame];
	if ([[self content] count]) {
		[_scroller setKnobProportion:(1.0/[[self content] count])];
	} else {
		[_scroller setKnobProportion:1.0];
	}
	
	if (self.accessoryController.view) {
		NSRect accessoryFrame = [self.accessoryController.view frame];
		accessoryFrame.origin.x = floor(([self frame].size.width - accessoryFrame.size.width)/2);
		accessoryFrame.origin.y = NSMaxY([_scroller frame]) + MBCoverFlowScrollerVerticalSpacing;
		[self.accessoryController.view setFrame:accessoryFrame];
	}
	
	_containerLayer.constraints = nil;
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidX relativeTo:@"superlayer" attribute:kCAConstraintMidX]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintWidth relativeTo:@"superlayer" attribute:kCAConstraintWidth offset:-20]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY offset:MBCoverFlowViewContainerMinY]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY offset:-10]];
}

#pragma mark -
#pragma mark Subclass Methods

#pragma mark Loading Data

- (void)setContent:(NSArray *)newContents
{
	if (_content) {
		[_content release];
		_content = nil;
	}
	
	if (newContents != nil) {
		_content = [newContents copy];
		for (NSImage *image in self.content) {
			CALayer *layer = [self _newLayer];
			CALayer *imageLayer = [[layer sublayers] objectAtIndex:0];
			CALayer *reflectionLayer = [[imageLayer sublayers] objectAtIndex:0];
			
			CGImageRef imageRef = [image imageRef];
			
			imageLayer.contents = (id)imageRef;
			reflectionLayer.contents = (id)imageRef;
			imageLayer.backgroundColor = NULL;
			reflectionLayer.backgroundColor = NULL;
		}
	}
	
	[_scroller setNumberOfIncrements:([self.content count]-1)];
	self.selectionIndex = self.selectionIndex;
}

#pragma mark Setting Display Attributes

- (void)setItemSize:(NSSize)newSize
{
	if (newSize.width <= 0) {
		newSize.width = MBCoverFlowViewDefaultItemWidth;
	}
	
	if (newSize.height <= 0) {
		newSize.height = MBCoverFlowViewDefaultItemHeight;
	}
	
	_itemSize = newSize;
	
	// Update all the various constraints which depend on the item size
	_containerLayer.constraints = nil;
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidX relativeTo:@"superlayer" attribute:kCAConstraintMidX]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintWidth relativeTo:@"superlayer" attribute:kCAConstraintWidth offset:-20]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY offset:MBCoverFlowViewContainerMinY]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY offset:-10]];
	
	_leftGradientLayer.constraints = nil;
	[_leftGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:@"superlayer" attribute:kCAConstraintMinX]];
	[_leftGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY]];
	[_leftGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY]];
	[_leftGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxX relativeTo:@"superlayer" attribute:kCAConstraintMaxX scale:.5 offset:-[self itemSize].width / 2]];
	_rightGradientLayer.constraints = nil;
	[_rightGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxX relativeTo:@"superlayer" attribute:kCAConstraintMaxX]];
	[_rightGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY]];
	[_rightGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY]];
	[_rightGradientLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinX relativeTo:@"superlayer" attribute:kCAConstraintMaxX scale:.5 offset:[self itemSize].width / 2]];
	
	// Update the view
	[self.layer setNeedsLayout];
	
	CALayer *layer = [[_scrollLayer sublayers] objectAtIndex:self.selectionIndex];
	CGRect layerFrame = [layer frame];
	
	// Scroll so the selected item is centered
	[_scrollLayer scrollToPoint:CGPointMake([self _positionOfSelectedItem], layerFrame.origin.y)];
	
}

#pragma mark Managing the Selection

- (void)setSelectionIndex:(NSInteger)newIndex
{
	if (newIndex >= [[_scrollLayer sublayers] count] || newIndex < 0) {
		return;
	}
	
	if ([[NSApp currentEvent] modifierFlags] & (NSAlphaShiftKeyMask|NSShiftKeyMask))
		[CATransaction setValue:[NSNumber numberWithFloat:2.0f] forKey:@"animationDuration"];
	else
		[CATransaction setValue:[NSNumber numberWithFloat:1.1f] forKey:@"animationDuration"];
	
	_selectionIndex = newIndex;
	[_scrollLayer layoutIfNeeded];
	
	CALayer *layer = [[_scrollLayer sublayers] objectAtIndex:_selectionIndex];
	CGRect layerFrame = [layer frame];
	
	// Scroll so the selected item is centered
	[_scrollLayer scrollToPoint:CGPointMake([self _positionOfSelectedItem], layerFrame.origin.y)];
	[_scroller setIntegerValue:self.selectionIndex];
}

- (void)setAccessoryController:(NSViewController *)aController
{
	if (aController == self.accessoryController)
		return;
	
	if (self.accessoryController != nil) {
		[self.accessoryController.view removeFromSuperview];
		[_accessoryController release];
		_accessoryController = nil;
		[self setNextResponder:nil];
	}
	
	if (aController != nil) {
		_accessoryController = [aController retain];
		[self addSubview:self.accessoryController.view];
		[self setNextResponder:self.accessoryController];
	}
	
	[self resizeSubviewsWithOldSize:[self frame].size];
}

#pragma mark Layout Support

- (NSInteger)indexOfItemAtPoint:(NSPoint)aPoint
{
	// Check the selected item first
	if (NSPointInRect(aPoint, [self rectForItemAtIndex:self.selectionIndex])) {
		return self.selectionIndex;
	}
	
	// Check the items to the left, in descending order
	NSInteger index = self.selectionIndex-1;
	while (index >= 0) {
		NSRect layerRect = [self rectForItemAtIndex:index];
		if (NSPointInRect(aPoint, layerRect)) {
			return index;
		}
		index--;
	}
	
	// Check the items to the right, in ascending order
	index = self.selectionIndex+1;
	while (index < [[_scrollLayer sublayers] count]) {
		NSRect layerRect = [self rectForItemAtIndex:index];
		if (NSPointInRect(aPoint, layerRect)) {
			return index;
		}
		index++;
	}
	
	return NSNotFound;
}

// FIXME: The frame returned is not quite wide enough. Don't know why -- probably due to the transforms
- (NSRect)rectForItemAtIndex:(NSInteger)index
{
	if (index < 0 || index >= [[_scrollLayer sublayers] count]) {
		return NSZeroRect;
	}
	
	CALayer *layer = [[_scrollLayer sublayers] objectAtIndex:index];
	CALayer *imageLayer = [[layer sublayers] objectAtIndex:0];
	
	CGRect frame = [imageLayer convertRect:[imageLayer frame] toLayer:self.layer];
	return NSRectFromCGRect(frame);
}

#pragma mark -
#pragma mark Private Methods

- (CALayer *)_newLayer
{
	/* this enables a perspective transform.  The value of zDistance
	 affects the sharpness of the transform */
	float zDistance = 420.;
	CATransform3D sublayerTransform = CATransform3DIdentity; 
	sublayerTransform.m34 = 1. / -zDistance;
	
	CALayer *layer = [CALayer layer];
	CALayer *imageLayer = [CALayer layer];
	
	CGRect frame;
	frame.origin = CGPointZero;
	frame.size = NSSizeToCGSize([self itemSize]);
	
	[imageLayer setBounds:frame];
	[imageLayer setBackgroundColor:CGColorGetConstantColor(kCGColorWhite)];
	imageLayer.name = @"image";
	
	[layer setBounds:frame];
	[layer setBackgroundColor:CGColorGetConstantColor(kCGColorClear)];
	[layer setValue:[NSNumber numberWithInteger:[[_scrollLayer sublayers] count]] forKey:@"index"];
	[layer setSublayers:[NSArray arrayWithObject:imageLayer]];
	[layer setSublayerTransform:sublayerTransform];
	
	CALayer *reflectionLayer = [CALayer layer];
	frame.origin.y = -frame.size.height;
	[reflectionLayer setFrame:frame];
	reflectionLayer.name = @"reflection";
	reflectionLayer.transform = CATransform3DMakeScale(1, -1, 1);
	[reflectionLayer setBackgroundColor:CGColorGetConstantColor(kCGColorWhite)];
	[imageLayer addSublayer:reflectionLayer];
	
	CALayer *gradientLayer = [CALayer layer];
	frame.origin.y += frame.size.height;
	frame.origin.x -= 1.0;
	frame.size.height += 2.0;
	frame.size.width += 2.0;
	[gradientLayer setFrame:frame];
	[gradientLayer setContents:(id)_shadowImage];
	gradientLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
	[reflectionLayer addSublayer:gradientLayer];
	
	[_scrollLayer addSublayer:layer];
	
	return layer;
}

- (float)_positionOfSelectedItem
{
	// this is the same math used in layoutSublayersOfLayer:, before tweaking
	return floor(MBCoverFlowViewHorizontalMargin + .5*([_scrollLayer bounds].size.width - [self itemSize].width * [[_scrollLayer sublayers] count] - MBCoverFlowViewCellSpacing * ([[_scrollLayer sublayers] count] - 1))) + self.selectionIndex * ([self itemSize].width + MBCoverFlowViewCellSpacing) - .5 * [_scrollLayer bounds].size.width + .5 * [self itemSize].width;
}

- (void)scrollerWasClicked:(NSScroller *)sender
{
	NSScrollerPart clickedPart = [sender hitPart];
	if (clickedPart == NSScrollerIncrementLine) {
		self.selectionIndex += 1;
	} else if (clickedPart == NSScrollerDecrementLine) {
		self.selectionIndex -= 1;
	} else if (clickedPart == NSScrollerKnob) {
		self.selectionIndex = [sender integerValue];
	}
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark CALayoutManager

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
	float margin = floor(MBCoverFlowViewHorizontalMargin + ([layer bounds].size.width - [self itemSize].width * [[layer sublayers] count] - MBCoverFlowViewCellSpacing * ([[layer sublayers] count]-1)) * 0.5);
	
	for (CALayer *sublayer in [layer sublayers]) {
		CALayer *imageLayer = [[sublayer sublayers] objectAtIndex:0];
		CALayer *reflectionLayer = [[imageLayer sublayers] objectAtIndex:0];
		
		NSUInteger index = [[sublayer valueForKey:@"index"] integerValue];
		CGRect frame;
		frame.size = NSSizeToCGSize([self itemSize]);
		frame.origin.x = margin + index * ([self itemSize].width + MBCoverFlowViewCellSpacing);
		frame.origin.y = frame.size.height;
		
		CGRect imageFrame = frame;
		imageFrame.origin = CGPointZero;
		
		CGRect reflectionFrame = imageFrame;
		reflectionFrame.origin.y = -frame.size.height;
		
		CGRect gradientFrame = reflectionFrame;
		gradientFrame.origin.y = 0;
		
		// Create the perspective effect
		if (index < self.selectionIndex) {
			// Left
			frame.origin.x += [self itemSize].width * MBCoverFlowViewPerspectiveSideSpacingFactor * (float)(self.selectionIndex - index - MBCoverFlowViewPerspectiveRowScaleFactor);
			imageLayer.transform = _leftTransform;
			imageLayer.zPosition = MBCoverFlowViewPerspectiveSidePosition;
			sublayer.zPosition = MBCoverFlowViewPerspectiveSidePosition - 0.1 * (self.selectionIndex - index);
		} else if (index > self.selectionIndex) {
			// Right
			frame.origin.x -= [self itemSize].width * MBCoverFlowViewPerspectiveSideSpacingFactor * (float)(index - self.selectionIndex - MBCoverFlowViewPerspectiveRowScaleFactor);
			imageLayer.transform = _rightTransform;
			imageLayer.zPosition = MBCoverFlowViewPerspectiveSidePosition;
			sublayer.zPosition = MBCoverFlowViewPerspectiveSidePosition - 0.1 * (index - self.selectionIndex);
		} else {
			// Center
			imageLayer.transform = CATransform3DIdentity;
			imageLayer.zPosition = MBCoverFlowViewPerspectiveCenterPosition;
			sublayer.zPosition = MBCoverFlowViewPerspectiveSidePosition;
		}
		
		[sublayer setFrame:frame];
		[imageLayer setFrame:imageFrame];
		[reflectionLayer setFrame:reflectionFrame];
		[reflectionLayer setBounds:CGRectMake(0, 0, [reflectionLayer bounds].size.width, [reflectionLayer bounds].size.height)];
	}
}

@end

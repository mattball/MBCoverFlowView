//
//  MBCoverFlowView.m
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/13/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import "MBCoverFlowView.h"

#import <QuartzCore/QuartzCore.h>

// Constants
const float MBCoverFlowViewHorizontalMargin = 12.0;

// Layer Dimensions
const float MBCoverFlowViewCellSpacing = 14.0;
const float MBCoverFlowViewCellWidth = 100.0;
const float MBCoverFlowViewCellHeight = 100.0;

// Perspective parameters
const float MBCoverFlowViewPerspectiveCenterPosition = 100.0;
const float MBCoverFlowViewPerspectiveSidePosition = 0.0;
const float MBCoverFlowViewPerspectiveSideSpacingFactor = 0.75;
const float MBCoverFlowViewPerspectiveRowScaleFactor = 0.85;
const float MBCoverFlowViewPerspectiveAngle = 0.79;

// Layer Keys
static NSString *MBCoverFlowViewCellSpacingKey = @"spacing";
static NSString *MBCoverFlowViewCellSizeKey = @"cellSize";

// Key Codes
#define MBLeftArrowKeyCode 123
#define MBRightArrowKeyCode 124

@interface MBCoverFlowView ()
- (float)_positionOfSelectedItem;
- (CALayer *)_newLayer;
@end


@implementation MBCoverFlowView

@synthesize infoCell=_infoCell;
@synthesize selectedIndex=_selectedIndex;

#pragma mark -
#pragma mark Life Cycle

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		_infoCell = [[NSTextFieldCell alloc] initTextCell:@"Test"];
		[_infoCell setBordered:NO];
		[_infoCell setBezeled:NO];
		[(NSTextFieldCell *)_infoCell setTextColor:[NSColor whiteColor]];
		[_infoCell setFont:[NSFont boldSystemFontOfSize:12.0]];
		
		// We need something to host the cell, since we can't draw it ourselves
		_infoControl = [[NSControl alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];
		[_infoControl setCell:_infoCell];
		[_infoControl sizeToFit];
		[self addSubview:_infoControl];
		
		_leftTransform = CATransform3DMakeRotation(-0.79, 0, -1, 0);
		_rightTransform = CATransform3DMakeRotation(MBCoverFlowViewPerspectiveAngle, 0, -1, 0);
	}
	return self;
}

- (void)dealloc
{
	self.infoCell = nil;
	[_infoControl release];
	CGImageRelease(_shadowImage);
	[super dealloc];
}

- (void)awakeFromNib
{
	CALayer *rootLayer = [CALayer layer];
	rootLayer.layoutManager = [CAConstraintLayoutManager layoutManager];
	rootLayer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
	
	_scrollLayer = [CAScrollLayer layer];
	_scrollLayer.scrollMode = kCAScrollHorizontally;
	_scrollLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
	_scrollLayer.layoutManager = self;
	[_scrollLayer setValue:[NSValue valueWithSize:NSMakeSize(MBCoverFlowViewCellSpacing, MBCoverFlowViewCellSpacing)] forKey:MBCoverFlowViewCellSpacingKey];
	[_scrollLayer setValue:[NSValue valueWithSize:NSMakeSize(MBCoverFlowViewCellWidth, MBCoverFlowViewCellHeight)] forKey:MBCoverFlowViewCellSizeKey];
	[rootLayer addSublayer:_scrollLayer];
	
	// Create a gradient image to use for image shadows
	CGRect gradientRect;
	gradientRect.origin = CGPointZero;
	gradientRect.size = CGSizeMake(MBCoverFlowViewCellWidth, MBCoverFlowViewCellHeight);
	size_t bytesPerRow = 4*gradientRect.size.width;
	void* bitmapData = malloc(bytesPerRow * gradientRect.size.height);
	CGContextRef context = CGBitmapContextCreate(bitmapData, gradientRect.size.width,
												 gradientRect.size.height, 8,  bytesPerRow, 
												 CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB), kCGImageAlphaPremultipliedFirst);
	NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithDeviceWhite:0 alpha:.5] endingColor:[NSColor colorWithDeviceWhite:0 alpha:1.0]];
	NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:nsContext];
	[gradient drawInRect:NSMakeRect(0, 0, gradientRect.size.width, gradientRect.size.height) angle:90];
	[NSGraphicsContext restoreGraphicsState];
	_shadowImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	free(bitmapData);
	[gradient release];
	
	// Create a couple of test layers
	[self _newLayer];
	[self _newLayer];
	[self _newLayer];
	[self _newLayer];
	[self _newLayer];
	[self _newLayer];
	
	[self setLayer:rootLayer];
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
	// Slow motion if the shift key is held down
	if ([theEvent modifierFlags] & (NSAlphaShiftKeyMask|NSShiftKeyMask))
		[CATransaction setValue:[NSNumber numberWithFloat:2.0f] forKey:@"animationDuration"];
	
	switch ([theEvent keyCode]) {
		case MBLeftArrowKeyCode:
			self.selectedIndex -= 1;
			break;
		case MBRightArrowKeyCode:
			self.selectedIndex += 1;
			break;
		default:
			[super keyDown:theEvent];
			break;
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSLog(@"Item: %i", [self indexOfItemAtPoint:mouseLocation]);
}

#pragma mark NSView

- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
	[self resizeSubviewsWithOldSize:[self frame].size];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
	// Place the info control
	[_infoControl sizeToFit];
	NSRect infoFrame = [_infoControl frame];
	// Make sure to constrain the info to fit within the view
	if (infoFrame.size.width > [self frame].size.width - 2*MBCoverFlowViewHorizontalMargin) {
		infoFrame.size.width = [self frame].size.width - 2*MBCoverFlowViewHorizontalMargin;
	}
	infoFrame.origin.x = floor(([self frame].size.width - [_infoControl frame].size.width)/2);
	infoFrame.origin.y = 40.0;
	[_infoControl setFrame:infoFrame];
	
}

#pragma mark -
#pragma mark Subclass Methods

- (void)setSelectedIndex:(NSInteger)newIndex
{
	if (newIndex >= [[_scrollLayer sublayers] count] || newIndex < 0) {
		NSBeep();
		return;
	}
	
	_selectedIndex = newIndex;
	[_scrollLayer layoutIfNeeded];
	
	CALayer *layer = [[_scrollLayer sublayers] objectAtIndex:_selectedIndex];
	CGRect layerFrame = [layer frame];
	
	// Scroll so the selected item is centered
	[_scrollLayer scrollToPoint:CGPointMake([self _positionOfSelectedItem], layerFrame.origin.y)];
}

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
	frame.size = CGSizeMake(MBCoverFlowViewCellWidth, MBCoverFlowViewCellHeight);
	
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
	CATransform3D reflectionTransform = CATransform3DMakeScale(1, -1, 1);
	reflectionLayer.transform = reflectionTransform;
	[reflectionLayer setBackgroundColor:CGColorGetConstantColor(kCGColorWhite)];
	[imageLayer addSublayer:reflectionLayer];
	
	CALayer *gradientLayer = [CALayer layer];
	frame.origin.y += frame.size.height;
	frame.origin.x -= 1.0;
	frame.size.height += 1;
	frame.size.width += 2.0;
	[gradientLayer setFrame:frame];
	[gradientLayer setContents:(id)_shadowImage];
	[gradientLayer setOpaque:NO];
	[reflectionLayer addSublayer:gradientLayer];
	
	[_scrollLayer addSublayer:layer];
	
	return layer;
}

#pragma mark Layout

- (float)_positionOfSelectedItem
{
	// this is the same math used in layoutSublayersOfLayer:, before tweaking
	return floor(MBCoverFlowViewHorizontalMargin + .5*([_scrollLayer bounds].size.width - MBCoverFlowViewCellWidth * [[_scrollLayer sublayers] count] - MBCoverFlowViewCellSpacing * ([[_scrollLayer sublayers] count] - 1))) + self.selectedIndex * (MBCoverFlowViewCellWidth + MBCoverFlowViewCellSpacing) - .5 * [_scrollLayer bounds].size.width + .5 * MBCoverFlowViewCellWidth;
}

- (NSInteger)indexOfItemAtPoint:(NSPoint)aPoint
{
	// Check the selected item first
	if (NSPointInRect(aPoint, [self frameOfItemAtIndex:self.selectedIndex])) {
		return self.selectedIndex;
	}
	
	// Check the items to the left, in descending order
	NSInteger index = self.selectedIndex-1;
	while (index >= 0) {
		NSRect layerRect = [self frameOfItemAtIndex:index];
		if (NSPointInRect(aPoint, layerRect)) {
			return index;
		}
		index--;
	}
	
	// Check the items to the right, in ascending order
	index = self.selectedIndex+1;
	while (index < [[_scrollLayer sublayers] count]) {
		NSRect layerRect = [self frameOfItemAtIndex:index];
		if (NSPointInRect(aPoint, layerRect)) {
			return index;
		}
		index++;
	}
	
	return NSNotFound;
}

// FIXME: The frame returned is not quite wide enough. Don't know why -- probably due to the transforms
- (NSRect)frameOfItemAtIndex:(NSUInteger)index
{
	CALayer *layer = [[_scrollLayer sublayers] objectAtIndex:index];
	CALayer *imageLayer = [[layer sublayers] objectAtIndex:0];
	
	CGRect frame = [imageLayer convertRect:[imageLayer frame] toLayer:self.layer];
	return NSRectFromCGRect(frame);
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark CALayoutManager

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
	float margin = floor(MBCoverFlowViewHorizontalMargin + ([layer bounds].size.width - MBCoverFlowViewCellWidth * [[layer sublayers] count] - MBCoverFlowViewCellSpacing * ([[layer sublayers] count]-1)) * 0.5);
	
	for (CALayer *sublayer in [layer sublayers]) {
		CALayer *imageLayer = [[sublayer sublayers] objectAtIndex:0];
		
		NSUInteger index = [[sublayer valueForKey:@"index"] integerValue];
		CGRect frame;
		frame.size = CGSizeMake(MBCoverFlowViewCellWidth, MBCoverFlowViewCellHeight);
		frame.origin = CGPointZero;
		CGRect imageFrame = frame;
		
		// Base position, before the perspective is applied
		frame.origin.y = [self frame].size.height / 2 - frame.size.height / 2;
		frame.origin.x = margin + index * (MBCoverFlowViewCellWidth + MBCoverFlowViewCellSpacing);
		
		// Create the perspective effect
		if (index < self.selectedIndex) {
			// Left
			frame.origin.x += MBCoverFlowViewCellWidth * MBCoverFlowViewPerspectiveSideSpacingFactor * (float)(self.selectedIndex - index - MBCoverFlowViewPerspectiveRowScaleFactor);
			imageLayer.transform = _leftTransform;
			imageLayer.zPosition = MBCoverFlowViewPerspectiveSidePosition;
			sublayer.zPosition = MBCoverFlowViewPerspectiveSidePosition - 0.1 * (self.selectedIndex - index);
		} else if (index > self.selectedIndex) {
			// Right
			frame.origin.x -= MBCoverFlowViewCellWidth * MBCoverFlowViewPerspectiveSideSpacingFactor * (float)(index - self.selectedIndex - MBCoverFlowViewPerspectiveRowScaleFactor);
			imageLayer.transform = _rightTransform;
			imageLayer.zPosition = MBCoverFlowViewPerspectiveSidePosition;
			sublayer.zPosition = MBCoverFlowViewPerspectiveSidePosition - 0.1 * (index - self.selectedIndex);
		} else {
			// Center
			imageLayer.transform = CATransform3DIdentity;
			imageLayer.zPosition = MBCoverFlowViewPerspectiveCenterPosition;
			sublayer.zPosition = MBCoverFlowViewPerspectiveSidePosition;
		}
		
		[sublayer setFrame:frame];
		[imageLayer setFrame:imageFrame];
	}
}

@end

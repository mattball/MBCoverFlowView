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

#import "MBCoverFlowView.h"

#import "MBCoverFlowScroller.h"
#import "NSImage+MBCoverFlowAdditions.h"

#import <QuartzCore/QuartzCore.h>

// Constants
#define MBCoverFlowViewCellSpacing ([self itemSize].width/10)

const float MBCoverFlowViewPlaceholderHeight = 600;

const float MBCoverFlowViewTopMargin = 30.0;
const float MBCoverFlowViewBottomMargin = 20.0;
const float MBCoverFlowViewHorizontalMargin = 12.0;
#define MBCoverFlowViewContainerMinY (NSMaxY([self.accessoryController.view frame]) - 3*[self itemSize].height/4)

const float MBCoverFlowScrollerHorizontalMargin = 80.0;
const float MBCoverFlowScrollerVerticalSpacing = 16.0;

const float MBCoverFlowViewDefaultItemWidth = 140.0;
const float MBCoverFlowViewDefaultItemHeight = 100.0;

const float MBCoverFlowScrollMinimumDeltaThreshold = 0.4;

// Perspective parameters
const float MBCoverFlowViewPerspectiveCenterPosition = 100.0;
const float MBCoverFlowViewPerspectiveSidePosition = 0.0;
const float MBCoverFlowViewPerspectiveSideSpacingFactor = 0.75;
const float MBCoverFlowViewPerspectiveRowScaleFactor = 0.85;
const float MBCoverFlowViewPerspectiveAngle = 0.79;

// Bindings
static NSString *MBCoverFlowViewContentBindingContext;
static NSString *MBCoverFlowViewImagePathContext;
static NSString *MBCoverFlowViewSelectionIndexContext;

// Key Codes
#define MBLeftArrowKeyCode 123
#define MBRightArrowKeyCode 124
#define MBReturnKeyCode 36

@interface MBCoverFlowView ()
- (float)_positionOfSelectedItem;
- (CALayer *)_newLayer;
- (void)_scrollerChange:(MBCoverFlowScroller *)scroller;
- (void)_refreshLayer:(CALayer *)layer;
- (void)_loadImageForLayer:(CALayer *)layer;
- (CALayer *)_layerForObject:(id)object;
- (void)_recachePlaceholder;
- (void)_setSelectionIndex:(NSInteger)index; // For two-way bindings
@end


@implementation MBCoverFlowView

@synthesize accessoryController=_accessoryController, selectedIndex=_selectedIndex, 
            itemSize=_itemSize, content=_content, showsScrollbar=_showsScrollbar,
            autoresizesItems=_autoresizesItems, imageKeyPath=_imageKeyPath,
            placeholderIcon=_placeholderIcon, target=_target, action=_action;

@dynamic selectedObject;

#pragma mark -
#pragma mark Life Cycle

+ (void)initialize
{
	[self exposeBinding:@"content"];
	[self exposeBinding:@"selectionIndex"];
}

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		_bindingInfo = [[NSMutableDictionary alloc] init];
		
		_imageLoadQueue = [[NSOperationQueue alloc] init];
		[_imageLoadQueue setMaxConcurrentOperationCount:1];
		
		_placeholderIcon = [[NSImage imageNamed:NSImageNameQuickLookTemplate] retain];
		
		_autoresizesItems = YES;
		
		[self setAutoresizesSubviews:YES];
		
		// Create the scroller
		_scroller = [[MBCoverFlowScroller alloc] initWithFrame:NSMakeRect(10, 10, 400, 16)];
		[_scroller setEnabled:YES];
		[_scroller setTarget:self];
		[_scroller setHidden:YES];
		[_scroller setKnobProportion:1.0];
		[_scroller setAction:@selector(_scrollerChange:)];
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
	[_bindingInfo release];
	[_scroller release];
	[_scrollLayer release];
	[_containerLayer release];
	self.accessoryController = nil;
	self.content = nil;
	self.imageKeyPath = nil;
	self.placeholderIcon = nil;
	CGImageRelease(_placeholderRef);
	CGImageRelease(_shadowImage);
	[_imageLoadQueue release];
	_imageLoadQueue = nil;
	[super dealloc];
}

- (void)awakeFromNib
{
	[self setWantsLayer:YES];
	[self _recachePlaceholder];
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
			[self _setSelectionIndex:(self.selectedIndex - 1)];
			break;
		case MBRightArrowKeyCode:
			[self _setSelectionIndex:(self.selectedIndex + 1)];
			break;
		case MBReturnKeyCode:
			if (self.target && self.action) {
				[self.target performSelector:self.action withObject:self];
			}
			break;
		default:
			[super keyDown:theEvent];
			break;
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if ([theEvent clickCount] == 2 && self.target && self.action) {
		[self.target performSelector:self.action withObject:self];
	}
	
	NSPoint mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSInteger clickedIndex = [self indexOfItemAtPoint:mouseLocation];
	if (clickedIndex != NSNotFound) {
		[self _setSelectionIndex:clickedIndex];
	}
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	if (fabs([theEvent deltaY]) > MBCoverFlowScrollMinimumDeltaThreshold) {
		if ([theEvent deltaY] > 0) {
			[self _setSelectionIndex:(self.selectedIndex - 1)];
		} else {
			[self _setSelectionIndex:(self.selectedIndex + 1)];
		}
	} else if (fabs([theEvent deltaX]) > MBCoverFlowScrollMinimumDeltaThreshold) {
		if ([theEvent deltaX] > 0) {
			[self _setSelectionIndex:(self.selectedIndex - 1)];
		} else {
			[self _setSelectionIndex:(self.selectedIndex + 1)];
		}
	}
}

#pragma mark NSView

- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
	[self resizeSubviewsWithOldSize:[self frame].size];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
	float accessoryY = MBCoverFlowScrollerVerticalSpacing;
	
	// Reposition the scroller
	if (self.showsScrollbar) {
		NSRect scrollerFrame = [_scroller frame];
		scrollerFrame.size.width = [self frame].size.width - 2*MBCoverFlowScrollerHorizontalMargin;
		scrollerFrame.origin.x = ([self frame].size.width - scrollerFrame.size.width)/2;
		scrollerFrame.origin.y = MBCoverFlowViewBottomMargin;
		[_scroller setFrame:scrollerFrame];
		accessoryY += NSMaxY([_scroller frame]);
	}
	
	if (self.accessoryController.view) {
		NSRect accessoryFrame = [self.accessoryController.view frame];
		accessoryFrame.origin.x = floor(([self frame].size.width - accessoryFrame.size.width)/2);
		accessoryFrame.origin.y = accessoryY;
		[self.accessoryController.view setFrame:accessoryFrame];
	}
	
	_containerLayer.constraints = nil;
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidX relativeTo:@"superlayer" attribute:kCAConstraintMidX]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintWidth relativeTo:@"superlayer" attribute:kCAConstraintWidth offset:-20]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMinY relativeTo:@"superlayer" attribute:kCAConstraintMinY offset:MBCoverFlowViewContainerMinY]];
	[_containerLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMaxY relativeTo:@"superlayer" attribute:kCAConstraintMaxY offset:-10]];

	self.selectedIndex = self.selectedIndex;
}

- (BOOL)mouseDownCanMoveWindow
{
	return NO;
}

#pragma mark -
#pragma mark Subclass Methods

#pragma mark Loading Data

- (void)setContent:(NSArray *)newContents
{	
	if ([newContents isEqualToArray:self.content]) {
		return;
	}
	
	NSArray *oldContent = [self.content retain];

	if (_content) {
		[_content release];
		_content = nil;
	}
	
	if (newContents != nil) {
		_content = [newContents copy];
	}
	
	// Add any new items
	NSMutableArray *itemsToAdd = [self.content mutableCopy];
	[itemsToAdd removeObjectsInArray:oldContent];
	
	for (NSObject *object in itemsToAdd) {
		CALayer *layer = [self _newLayer];
		[layer setValue:object forKey:@"representedObject"];
		if (self.imageKeyPath) {
			[object addObserver:self forKeyPath:self.imageKeyPath options:0 context:&MBCoverFlowViewImagePathContext];
		}
		[self _refreshLayer:layer];
	}
	
	// Remove any items which are no longer present
	NSMutableArray *itemsToRemove = [oldContent mutableCopy];
	[itemsToRemove removeObjectsInArray:self.content];
	for (NSObject *object in itemsToRemove) {
		CALayer *layer = [self _layerForObject:object];
		if (self.imageKeyPath) {
			[[layer valueForKey:@"representedObject"] removeObserver:self forKeyPath:self.imageKeyPath];
		}
		[layer removeFromSuperlayer];
	}
	
	[oldContent release];
	
	// Update the layer indices
	for (CALayer *layer in [_scrollLayer sublayers]) {
		[layer setValue:[NSNumber numberWithInteger:[self.content indexOfObject:[layer valueForKey:@"representedObject"]]] forKey:@"index"];
	}
	
	[_scroller setNumberOfIncrements:fmax([self.content count]-1, 0)];
	self.selectedIndex = self.selectedIndex;
}

- (void)setImageKeyPath:(NSString *)keyPath
{	
	if (_imageKeyPath) {
		// Remove any observations for the existing key path
		for (NSObject *object in self.content) {
			[object removeObserver:self forKeyPath:self.imageKeyPath];
		}
		
		[_imageKeyPath release];
		_imageKeyPath = nil;
	}
	
	if (keyPath) {
		_imageKeyPath = [keyPath copy];
	}
	
	// Refresh all the layers with images at the new key path
	for (CALayer *layer in [_scrollLayer sublayers]) {
		if (self.imageKeyPath) {
			[[layer valueForKey:@"representedObject"] addObserver:self forKeyPath:self.imageKeyPath options:0 context:&MBCoverFlowViewImagePathContext];
		}
		[self _refreshLayer:layer];
	}
}

#pragma mark Setting Display Attributes

- (void)setAutoresizesItems:(BOOL)flag
{
	_autoresizesItems = flag;
	[self resizeSubviewsWithOldSize:[self frame].size];
}

- (NSSize)itemSize
{
	if (!self.autoresizesItems) {
		return _itemSize;
	}
	
	float origin = MBCoverFlowViewBottomMargin;
	
	if (self.showsScrollbar) {
		origin += [_scroller frame].size.height + MBCoverFlowScrollerVerticalSpacing;
	}
	
	if (self.accessoryController.view) {
		NSRect accessoryFrame = [self.accessoryController.view frame];
		origin += accessoryFrame.size.height;
	}
	
	NSSize size;
	size.height = ([self frame].size.height - origin) - [self frame].size.height/3;
	size.width = size.height * _itemSize.width / _itemSize.height;
	
	// Make sure it's integral
	size.height = floor(size.height);
	size.width = floor(size.width);
	
	return size;
}

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
	[self _recachePlaceholder];
	[self.layer setNeedsLayout];
	
	CALayer *layer = [[_scrollLayer sublayers] objectAtIndex:self.selectedIndex];
	CGRect layerFrame = [layer frame];
	
	// Scroll so the selected item is centered
	[_scrollLayer scrollToPoint:CGPointMake([self _positionOfSelectedItem], layerFrame.origin.y)];
	
}

- (void)setShowsScrollbar:(BOOL)flag
{
	_showsScrollbar = flag;
	[_scroller setHidden:!flag];
	[self resizeSubviewsWithOldSize:[self frame].size];
}

- (void)setAccessoryController:(NSViewController *)aController
{
	if (aController == self.accessoryController)
		return;
	
	if (self.accessoryController != nil) {
		[self.accessoryController.view removeFromSuperview];
		[self.accessoryController unbind:@"representedObject"];
		[_accessoryController release];
		_accessoryController = nil;
		[self setNextResponder:nil];
	}
	
	if (aController != nil) {
		_accessoryController = [aController retain];
		[self addSubview:self.accessoryController.view];
		[self setNextResponder:self.accessoryController];
		[self.accessoryController bind:@"representedObject" toObject:self withKeyPath:@"selectedObject" options:nil];
	}
	
	[self resizeSubviewsWithOldSize:[self frame].size];
}

#pragma mark Managing the Selection

- (void)setSelectedIndex:(NSInteger)newIndex
{
	if (newIndex >= [[_scrollLayer sublayers] count] || newIndex < 0) {
		return;
	}
	
	if ([[NSApp currentEvent] modifierFlags] & (NSAlphaShiftKeyMask|NSShiftKeyMask))
		[CATransaction setValue:[NSNumber numberWithFloat:2.1f] forKey:@"animationDuration"];
	else
		[CATransaction setValue:[NSNumber numberWithFloat:0.7f] forKey:@"animationDuration"];
	
	_selectedIndex = newIndex;
	[_scrollLayer layoutIfNeeded];
	
	CALayer *layer = [[_scrollLayer sublayers] objectAtIndex:_selectedIndex];
	CGRect layerFrame = [layer frame];
	
	// Scroll so the selected item is centered
	[_scrollLayer scrollToPoint:CGPointMake([self _positionOfSelectedItem], layerFrame.origin.y)];
	[_scroller setIntegerValue:self.selectedIndex];
}

- (id)selectedObject
{
	if ([self.content count] == 0) {
		return nil;
	}
	
	return [self.content objectAtIndex:self.selectedIndex];
}

- (void)setSelectedObject:(id)anObject
{
	if (![self.content containsObject:anObject]) {
		NSLog(@"[MBCoverFlowView setSelectedObject:] -- The view does not contain the specified object.");
		return;
	}
	
	[self _setSelectionIndex:[self.content indexOfObject:anObject]];
}

#pragma mark Layout Support

- (NSInteger)indexOfItemAtPoint:(NSPoint)aPoint
{
	// Check the selected item first
	if (NSPointInRect(aPoint, [self rectForItemAtIndex:self.selectedIndex])) {
		return self.selectedIndex;
	}
	
	// Check the items to the left, in descending order
	NSInteger index = self.selectedIndex-1;
	while (index >= 0) {
		NSRect layerRect = [self rectForItemAtIndex:index];
		if (NSPointInRect(aPoint, layerRect)) {
			return index;
		}
		index--;
	}
	
	// Check the items to the right, in ascending order
	index = self.selectedIndex+1;
	while (index < [self.content count]) {
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
	if (index < 0 || index >= [self.content count]) {
		return NSZeroRect;
	}
	
	CALayer *layer = [self _layerForObject:[self.content objectAtIndex:index]];
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
	imageLayer.contents = (id)_placeholderRef;
	imageLayer.name = @"image";
	
	[layer setBounds:frame];
	[layer setValue:[NSNumber numberWithInteger:[[_scrollLayer sublayers] count]] forKey:@"index"];
	[layer setSublayers:[NSArray arrayWithObject:imageLayer]];
	[layer setSublayerTransform:sublayerTransform];
	[layer setValue:[NSNumber numberWithBool:NO] forKey:@"hasImage"];
	
	CALayer *reflectionLayer = [CALayer layer];
	frame.origin.y = -frame.size.height;
	[reflectionLayer setFrame:frame];
	reflectionLayer.name = @"reflection";
	reflectionLayer.transform = CATransform3DMakeScale(1, -1, 1);
	reflectionLayer.contents = (id)_placeholderRef;
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
	return floor(MBCoverFlowViewHorizontalMargin + .5*([_scrollLayer bounds].size.width - [self itemSize].width * [[_scrollLayer sublayers] count] - MBCoverFlowViewCellSpacing * ([[_scrollLayer sublayers] count] - 1))) + self.selectedIndex * ([self itemSize].width + MBCoverFlowViewCellSpacing) - .5 * [_scrollLayer bounds].size.width + .5 * [self itemSize].width;
}

- (void)_scrollerChange:(MBCoverFlowScroller *)sender
{
	NSScrollerPart clickedPart = [sender hitPart];
	if (clickedPart == NSScrollerIncrementLine) {
		[self _setSelectionIndex:(self.selectedIndex + 1)];
	} else if (clickedPart == NSScrollerDecrementLine) {
		[self _setSelectionIndex:(self.selectedIndex - 1)];
	} else if (clickedPart == NSScrollerKnob) {
		[self _setSelectionIndex:[sender integerValue]];
	}
}

- (void)_refreshLayer:(CALayer *)layer
{
	NSObject *object = [layer valueForKey:@"representedObject"];
	NSInteger index = [self.content indexOfObject:object];
	
	[layer setValue:[NSNumber numberWithInteger:index] forKey:@"index"];
	[layer setValue:[NSNumber numberWithBool:NO] forKey:@"hasImage"];
	
	// Create the operation
	NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_loadImageForLayer:) object:layer];
	[_imageLoadQueue addOperation:operation];
	[operation release];
}

- (void)_loadImageForLayer:(CALayer *)layer
{
	@try {
		NSImage *image;
		NSObject *object = [layer valueForKey:@"representedObject"];
		
		if (self.imageKeyPath != nil) {
			image = [object valueForKeyPath:self.imageKeyPath];
		} else if ([object isKindOfClass:[NSImage class]]) {
			image = (NSImage *)object;
		}
		
		if ([image isKindOfClass:[NSData class]]) {
			image = [[[NSImage alloc] initWithData:(NSData *)image] autorelease];
		}
		
		CGImageRef imageRef;
		
		if (!image) {
			imageRef = CGImageRetain(_placeholderRef);
			[layer setValue:[NSNumber numberWithBool:NO] forKey:@"hasImage"];
		} else {
			imageRef = [image imageRef];
			[layer setValue:[NSNumber numberWithBool:YES] forKey:@"hasImage"];
		}
		
		CALayer *imageLayer = [[layer sublayers] objectAtIndex:0];
		CALayer *reflectionLayer = [[imageLayer sublayers] objectAtIndex:0];
		
		imageLayer.contents = (id)imageRef;
		reflectionLayer.contents = (id)imageRef;
		imageLayer.backgroundColor = NULL;
		reflectionLayer.backgroundColor = NULL;
		CGImageRelease(imageRef);
	} @catch (NSException *e) {
		// If the key path isn't valid, do nothing
	}
}

- (CALayer *)_layerForObject:(id)object
{
	for (CALayer *layer in [_scrollLayer sublayers]) {
		if ([object isEqual:[layer valueForKey:@"representedObject"]]) {
			return layer;
		}
	}
	return nil;
}

- (void)_recachePlaceholder
{	
	CGImageRelease(_placeholderRef);
	
	NSSize itemSize = self.itemSize;
	NSSize placeholderSize;
	placeholderSize.height = MBCoverFlowViewPlaceholderHeight;
	placeholderSize.width = itemSize.width * placeholderSize.height/itemSize.height;
	
	NSImage *placeholder = [[NSImage alloc] initWithSize:placeholderSize];
	[placeholder lockFocus];
	NSColor *topColor = [NSColor colorWithCalibratedWhite:0.15 alpha:1.0];
	NSColor *bottomColor = [NSColor colorWithCalibratedWhite:0.0 alpha:1.0];
	NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:topColor endingColor:bottomColor];
	[gradient drawInRect:NSMakeRect(0, 0, placeholderSize.width, placeholderSize.height) relativeCenterPosition:NSMakePoint(0, 1)];
	[gradient release];
	
	// Draw the top bevel line
	NSColor *bevelColor = [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
	[bevelColor set];
	NSRectFill(NSMakeRect(0, placeholderSize.height-5.0, placeholderSize.width, 5.0));
	
	NSColor *bottomBevelColor = [NSColor colorWithCalibratedWhite:0.1 alpha:1.0];
	[bottomBevelColor set];
	NSRectFill(NSMakeRect(0, 0, placeholderSize.width, 5.0));
	
	// Draw the placeholder icon
	if (self.placeholderIcon) {
		NSRect iconRect;
		iconRect.size.height = placeholderSize.height/2;
		iconRect.size.width = iconRect.size.height * [self placeholderIcon].size.width/[self placeholderIcon].size.height;
		
		if (iconRect.size.width > placeholderSize.width * 0.666) {
			iconRect.size.width = placeholderSize.width/2;
			iconRect.size.height = iconRect.size.width * [self placeholderIcon].size.height/[self placeholderIcon].size.width;
		}
		
		iconRect.origin.x = (placeholderSize.width - iconRect.size.width)/2;
		iconRect.origin.y = (placeholderSize.height - iconRect.size.height)/2;
		
		NSImage *icon = [[NSImage alloc] initWithSize:iconRect.size];
		[icon lockFocus];
		NSColor *iconTopColor = [NSColor colorWithCalibratedRed:0.380 green:0.400 blue:0.427 alpha:1.0];
		NSColor *iconBottomColor = [NSColor colorWithCalibratedRed:0.224 green:0.255 blue:0.302 alpha:1.0];
		NSGradient *iconGradient = [[NSGradient alloc] initWithStartingColor:iconTopColor endingColor:iconBottomColor];
		[iconGradient drawInRect:NSMakeRect(0, 0, iconRect.size.width, iconRect.size.width) angle:-90.0];
		[iconGradient release];
		[self.placeholderIcon drawInRect:NSMakeRect(0, 0, iconRect.size.width, iconRect.size.height) fromRect:NSZeroRect operation:NSCompositeDestinationIn fraction:1.0];
		[icon unlockFocus];
		
		[icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		[icon release];		
	}
	
	[placeholder unlockFocus];
	
	_placeholderRef = [placeholder imageRef];
	
	// Update the placeholder for all necessary items
	for (CALayer *layer in [_scrollLayer sublayers]) {
		if (![[layer valueForKey:@"hasImage"] boolValue]) {
			CALayer *imageLayer = [[self.layer sublayers] objectAtIndex:0];
			CALayer *reflectionLayer = [[imageLayer sublayers] objectAtIndex:0];
			imageLayer.contents = (id)_placeholderRef;
			reflectionLayer.contents = (id)_placeholderRef;
		}
	}
}

- (void)_setSelectionIndex:(NSInteger)index
{
	if (index < 0) {
		index = 0;
	} else if (index >= [self.content count]) {
		index = [self.content count] - 1;
	}
	
	if ([self infoForBinding:@"selectionIndex"]) {
		id container = [[self infoForBinding:@"selectionIndex"] objectForKey:NSObservedObjectKey];
		NSString *keyPath = [[self infoForBinding:@"selectionIndex"] objectForKey:NSObservedKeyPathKey];
		[container setValue:[NSNumber numberWithInteger:index] forKey:keyPath];
		return;
	}
	
	self.selectedIndex = index;
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
		if (index < self.selectedIndex) {
			// Left
			frame.origin.x += [self itemSize].width * MBCoverFlowViewPerspectiveSideSpacingFactor * (float)(self.selectedIndex - index - MBCoverFlowViewPerspectiveRowScaleFactor);
			imageLayer.transform = _leftTransform;
			imageLayer.zPosition = MBCoverFlowViewPerspectiveSidePosition;
			sublayer.zPosition = MBCoverFlowViewPerspectiveSidePosition - 0.1 * (self.selectedIndex - index);
		} else if (index > self.selectedIndex) {
			// Right
			frame.origin.x -= [self itemSize].width * MBCoverFlowViewPerspectiveSideSpacingFactor * (float)(index - self.selectedIndex - MBCoverFlowViewPerspectiveRowScaleFactor);
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
		[reflectionLayer setFrame:reflectionFrame];
		[reflectionLayer setBounds:CGRectMake(0, 0, [reflectionLayer bounds].size.width, [reflectionLayer bounds].size.height)];
	}
}

#pragma mark NSKeyValueObserving

+ (NSSet *)keyPathsForValuesAffectingSelectedObject
{
	return [NSSet setWithObjects:@"selectedIndex", nil];
}

#pragma mark -
#pragma mark Bindings

- (void)bind:(NSString *)bindingName toObject:(id)observableObject withKeyPath:(NSString *)observableKeyPath options:(NSDictionary *)options
{
	if ([bindingName isEqualToString:@"content"]) {
		if ([_bindingInfo objectForKey:@"content"] != nil) {
			[self unbind:@"content"];
		}
		
		// Observe controller for changes
		NSDictionary *bindingsData = [NSDictionary dictionaryWithObjectsAndKeys:
									  observableObject, NSObservedObjectKey,
									  [[observableKeyPath copy] autorelease], NSObservedKeyPathKey,
									  [[options copy] autorelease], NSOptionsKey, nil];
		[_bindingInfo setObject:bindingsData forKey:@"content"];
		
		[observableObject addObserver:self
						   forKeyPath:observableKeyPath
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:&MBCoverFlowViewContentBindingContext];
	} else if ([bindingName isEqualToString:@"selectionIndex"]) {
		if ([_bindingInfo objectForKey:@"selectionIndex"] != nil) {
			[self unbind:@"selectionIndex"];
		}
		
		// Observe controller for changes
		NSDictionary *bindingsData = [NSDictionary dictionaryWithObjectsAndKeys:
									  observableObject, NSObservedObjectKey,
									  [[observableKeyPath copy] autorelease], NSObservedKeyPathKey,
									  [[options copy] autorelease], NSOptionsKey, nil];
		[_bindingInfo setObject:bindingsData forKey:@"selectionIndex"];
		
		[observableObject addObserver:self
						   forKeyPath:observableKeyPath
							  options:(NSKeyValueObservingOptionNew |
									   NSKeyValueObservingOptionOld)
							  context:&MBCoverFlowViewSelectionIndexContext];
	} else {
		[super bind:bindingName toObject:observableObject withKeyPath:observableKeyPath options:options];
	}
	[self setNeedsDisplay:YES];
}

- (void)unbind:(NSString *)bindingName
{
	if ([bindingName isEqualToString:@"content"])
	{
		id container = [[self infoForBinding:@"content"] objectForKey:NSObservedObjectKey];
		NSString *keyPath = [[self infoForBinding:@"content"] objectForKey:NSObservedKeyPathKey];
		
		[container removeObserver:self forKeyPath:keyPath];
		[_bindingInfo removeObjectForKey:@"content"];
		self.content = nil;
	} else if ([bindingName isEqualToString:@"selectionIndex"]) {
		id container = [[self infoForBinding:@"selectionIndex"] objectForKey:NSObservedObjectKey];
		NSString *keyPath = [[self infoForBinding:@"selectionIndex"] objectForKey:NSObservedKeyPathKey];
		
		[container removeObserver:self forKeyPath:keyPath];
		[_bindingInfo removeObjectForKey:@"selectionIndex"];
	} else {
		[super unbind:bindingName];
	}
	[self setNeedsDisplay:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == &MBCoverFlowViewContentBindingContext) {
		id container = [[self infoForBinding:@"content"] objectForKey:NSObservedObjectKey];
		NSString *keyPath = [[self infoForBinding:@"content"] objectForKey:NSObservedKeyPathKey];
		self.content = [container valueForKeyPath:keyPath];
	} else if (context == &MBCoverFlowViewSelectionIndexContext) {
		id container = [[self infoForBinding:@"selectionIndex"] objectForKey:NSObservedObjectKey];
		NSString *keyPath = [[self infoForBinding:@"selectionIndex"] objectForKey:NSObservedKeyPathKey];
		self.selectedIndex = [[container valueForKeyPath:keyPath] integerValue];
	} else if (context == &MBCoverFlowViewImagePathContext) {
		[self _refreshLayer:[self _layerForObject:object]];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (NSDictionary *)infoForBinding:(NSString *)bindingName
{
	NSDictionary *info = [_bindingInfo objectForKey:bindingName];
	if (info == nil) {
		info = [super infoForBinding:bindingName];
	}
	return info;
}

@end

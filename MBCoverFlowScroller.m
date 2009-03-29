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

#import "MBCoverFlowScroller.h"

// Constants
static NSColor *MBCoverFlowScrollerOutlineColor, *MBCoverFlowScrollerInactiveOutlineColor, *MBCoverFlowScrollerPressedOutlineColor;
static NSColor *MBCoverFlowScrollerBackgroundTopColor, *MBCoverFlowScrollerInactiveBackgroundTopColor, *MBCoverFlowScrollerPressedBackgroundTopColor;
static NSColor *MBCoverFlowScrollerBackgroundBottomColor, *MBCoverFlowScrollerInactiveBackgroundBottomColor, *MBCoverFlowScrollerPressedBackgroundBottomColor;
static NSColor *MBCoverFlowScrollerGlossTopColor, *MBCoverFlowScrollerInactiveGlossTopColor, *MBCoverFlowScrollerPressedGlossTopColor;
static NSColor *MBCoverFlowScrollerGlossBottomColor, *MBCoverFlowScrollerInactiveGlossBottomColor, *MBCoverFlowScrollerPressedGlossBottomColor;
static NSColor *MBCoverFlowScrollerSlotBackgroundColor, *MBCoverFlowScrollerInactiveSlotBackgroundColor, *MBCoverFlowScrollerSlotInsetColor;

@interface MBCoverFlowScroller ()
- (NSBezierPath *)_leftArrowPath;
- (NSBezierPath *)_rightArrowPath;
@end

@interface NSScroller (Private)
- (NSRect)_drawingRectForPart:(NSScrollerPart)aPart;
@end

const float MBCoverFlowScrollerKnobMinimumWidth = 30.0;

@implementation MBCoverFlowScroller

@synthesize numberOfIncrements=_numberOfIncrements;

+ (void)initialize
{
	MBCoverFlowScrollerOutlineColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] retain];
	MBCoverFlowScrollerInactiveOutlineColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] retain];
	MBCoverFlowScrollerPressedOutlineColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] retain];
	MBCoverFlowScrollerBackgroundTopColor = [[NSColor colorWithCalibratedWhite:0.1 alpha:1.0] retain];
	MBCoverFlowScrollerInactiveBackgroundTopColor = [[NSColor colorWithCalibratedWhite:0.1 alpha:1.0] retain];
	MBCoverFlowScrollerPressedBackgroundTopColor = [[NSColor colorWithCalibratedWhite:0.8 alpha:1.0] retain];
	MBCoverFlowScrollerBackgroundBottomColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] retain];
	MBCoverFlowScrollerInactiveBackgroundBottomColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] retain];
	MBCoverFlowScrollerPressedBackgroundBottomColor = [[NSColor colorWithCalibratedWhite:0.4 alpha:1.0] retain];
	MBCoverFlowScrollerGlossTopColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] retain];
	MBCoverFlowScrollerInactiveGlossTopColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] retain];
	MBCoverFlowScrollerPressedGlossTopColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] retain];
	MBCoverFlowScrollerGlossBottomColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.1] retain];
	MBCoverFlowScrollerInactiveGlossBottomColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.0] retain];
	MBCoverFlowScrollerPressedGlossBottomColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.1] retain];
	MBCoverFlowScrollerSlotBackgroundColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] retain];
	MBCoverFlowScrollerInactiveSlotBackgroundColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.2] retain];
	MBCoverFlowScrollerSlotInsetColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] retain];
}

- (void)drawRect:(NSRect)rect
{
	// Don't draw the scroller if it can't be scrolled
	if ([self knobProportion] >= 1.0) {
		return;
	}
	
	[self drawKnobSlotInRect:[self rectForPart:NSScrollerKnobSlot] highlight:NO] ;
	[self drawArrow:NSScrollerIncrementArrow highlight:( [self hitPart] == NSScrollerIncrementLine )] ;
	[self drawArrow:NSScrollerDecrementArrow highlight:( [self hitPart] == NSScrollerDecrementLine )] ;
	[self drawKnob];
}

- (NSScrollerPart)testPart:(NSPoint)aPoint
{
	[super testPart:aPoint];
	
	aPoint = [self convertPoint:aPoint fromView:nil];

	if ([[self _leftArrowPath] containsPoint:aPoint]) {
		return NSScrollerDecrementLine;
	} else if ([[self _rightArrowPath] containsPoint:aPoint]) {
		return NSScrollerIncrementLine;
	} else if (NSPointInRect(aPoint, [self rectForPart:NSScrollerKnob])) {
		return NSScrollerKnob;
	}
	return NSScrollerNoPart;
}

- (NSRect)rectForPart:(NSScrollerPart)aPart
{
	if (aPart == NSScrollerDecrementLine) {
		NSRect rect = [self rectForPart:NSScrollerKnobSlot];
		rect.origin.x = 0;
		rect.size.width = 30.0;
		return rect;
	} else if (aPart == NSScrollerIncrementLine) {
		NSRect rect = [self rectForPart:NSScrollerKnobSlot];
		rect.size.width = 30.0;
		rect.origin.x = [self frame].size.width - rect.size.width;
		return rect;
	} else if (aPart == NSScrollerKnobSlot) {
		NSRect rect;
		rect.size.height = 16.0;
		rect.origin.x = 15.0;
		rect.size.width = [self frame].size.width - 2*rect.origin.x;
		rect.origin.y = [self frame].size.height - rect.size.height;
		return rect;
	} else if (aPart == NSScrollerKnob) {
		NSRect rect = [self rectForPart:NSScrollerKnobSlot];
		float maxWidth = [self frame].size.width - ([self rectForPart:NSScrollerDecrementLine].size.width - 8.0 - 1.0) - ([self rectForPart:NSScrollerIncrementLine].size.width - 8.0 - 1.0);
		float minWidth = MBCoverFlowScrollerKnobMinimumWidth;
		rect.size.width = fmax(maxWidth * [self knobProportion], minWidth);
		
		rect.origin.x = NSMaxX([self rectForPart:NSScrollerDecrementLine]) - 8.0 - 1.0;
		
		float incrementWidth = (maxWidth - rect.size.width) / (self.numberOfIncrements);
		rect.origin.x += [self integerValue] * incrementWidth;
		
		return rect;
	} else if (aPart == NSScrollerDecrementPage) {
		
	} else if (aPart == NSScrollerIncrementPage) {
		
	}

	return NSZeroRect;
}

- (NSInteger)integerValue
{
	return floor([self floatValue] * (self.numberOfIncrements));
}

- (void)setIntegerValue:(NSInteger)value
{
	[self setFloatValue:((float)value / (float)self.numberOfIncrements)+0.01];
}

- (void)setNumberOfIncrements:(NSUInteger)newIncrements
{
	_numberOfIncrements = newIncrements;
	if (newIncrements > 0) {
		[self setKnobProportion:(1.0/(self.numberOfIncrements+1))];
	} else {
		[self setKnobProportion:1.0];
	}
	[self setNeedsDisplay:YES];
}

/* The documentation for NSScroller says to use -drawArrow:highlight:, but
 * that's never called. -drawArrow:highlightPart: is.
 */
- (void)drawArrow:(NSScrollerArrow)arrow highlightPart:(BOOL)flag
{
	[self drawArrow:arrow highlight:flag];
}

/* Since we've repositioned the arrows, NSScroller doesn't want to redisplay
 * the left one when it's clicked. Thus, we should just always redisplay the
 * entire view */
- (void)setNeedsDisplayInRect:(NSRect)rect
{
	if (!NSEqualRects(rect, [self bounds])) {
		rect = [self bounds];
	}
	
	[super setNeedsDisplayInRect:rect];
}

- (void)drawArrow:(NSScrollerArrow)arrow highlight:(BOOL)flag
{
	if (arrow == NSScrollerDecrementArrow) {
		NSBezierPath *arrowPath = [self _leftArrowPath];
		[[NSGraphicsContext currentContext] saveGraphicsState];
		[arrowPath addClip];
		
		// Determine the proper colors
		NSColor *outlineColor = MBCoverFlowScrollerOutlineColor;
		NSColor *bgTop = MBCoverFlowScrollerBackgroundTopColor;
		NSColor *bgBottom = MBCoverFlowScrollerBackgroundBottomColor;
		NSColor *glossTop = MBCoverFlowScrollerGlossTopColor;
		NSColor *glossBottom = MBCoverFlowScrollerGlossBottomColor;
		
		if (flag) {
			outlineColor = MBCoverFlowScrollerPressedOutlineColor;
			bgTop = MBCoverFlowScrollerPressedBackgroundTopColor;
			bgBottom = MBCoverFlowScrollerPressedBackgroundBottomColor;
			glossTop = MBCoverFlowScrollerPressedGlossTopColor;
			glossBottom = MBCoverFlowScrollerPressedGlossBottomColor;
		} else if (![[self window] isKeyWindow]) {
			outlineColor = MBCoverFlowScrollerInactiveOutlineColor;
			bgTop = MBCoverFlowScrollerInactiveBackgroundTopColor;
			bgBottom = MBCoverFlowScrollerInactiveBackgroundBottomColor;
			glossTop = MBCoverFlowScrollerInactiveGlossTopColor;
			glossBottom = MBCoverFlowScrollerInactiveGlossBottomColor;
		}
		
		// Draw the background
		NSGradient *bgGradient = [[NSGradient alloc] initWithStartingColor:bgTop endingColor:bgBottom];
		[bgGradient drawInBezierPath:arrowPath angle:90.0];
		[bgGradient release];
		
		// Draw the gloss
		NSGradient *glossGradient = [[NSGradient alloc] initWithStartingColor:glossTop endingColor:glossBottom];
		NSRect glossRect = [self rectForPart:NSScrollerDecrementLine];
		glossRect.origin.x += 4.0;
		glossRect.size.width += 20.0;
		glossRect.size.height /= 2.0;
		NSBezierPath *glossPath = [NSBezierPath bezierPathWithRoundedRect:glossRect xRadius:8.0 yRadius:4.0];
		[glossGradient drawInBezierPath:glossPath angle:90.0];
		[glossGradient release];
		
		[arrowPath setLineWidth:2.0];
		
		[outlineColor set];
		[arrowPath stroke];
		
		[[NSGraphicsContext currentContext] restoreGraphicsState];
		
		// Draw the arrow
		NSRect arrowRect = [self rectForPart:NSScrollerDecrementLine];
		NSPoint glyphTip = NSMakePoint(arrowRect.origin.x + 9.0, NSMidY(arrowRect));
		NSPoint glyphTop = NSMakePoint(glyphTip.x + 6.0, NSMinY(arrowRect) + 5.0);
		NSPoint glyphBottom = NSMakePoint(glyphTop.x, NSMaxY(arrowRect) - 5.0);
		NSBezierPath *glyphPath = [NSBezierPath bezierPath];
		[glyphPath moveToPoint:glyphTip];
		[glyphPath lineToPoint:glyphTop];
		[glyphPath lineToPoint:glyphBottom];
		[glyphPath lineToPoint:glyphTip];
		[glyphPath closePath];
		[outlineColor set];
		[glyphPath fill];
		
	} else if (arrow == NSScrollerIncrementArrow) {
		NSBezierPath *arrowPath = [self _rightArrowPath];
		[[NSGraphicsContext currentContext] saveGraphicsState];
		[arrowPath addClip];
		
		// Determine the proper colors
		NSColor *outlineColor = MBCoverFlowScrollerOutlineColor;
		NSColor *bgTop = MBCoverFlowScrollerBackgroundTopColor;
		NSColor *bgBottom = MBCoverFlowScrollerBackgroundBottomColor;
		NSColor *glossTop = MBCoverFlowScrollerGlossTopColor;
		NSColor *glossBottom = MBCoverFlowScrollerGlossBottomColor;
		
		if (flag) {
			outlineColor = MBCoverFlowScrollerPressedOutlineColor;
			bgTop = MBCoverFlowScrollerPressedBackgroundTopColor;
			bgBottom = MBCoverFlowScrollerPressedBackgroundBottomColor;
			glossTop = MBCoverFlowScrollerPressedGlossTopColor;
			glossBottom = MBCoverFlowScrollerPressedGlossBottomColor;
		} else if (![[self window] isKeyWindow]) {
			outlineColor = MBCoverFlowScrollerInactiveOutlineColor;
			bgTop = MBCoverFlowScrollerInactiveBackgroundTopColor;
			bgBottom = MBCoverFlowScrollerInactiveBackgroundBottomColor;
			glossTop = MBCoverFlowScrollerInactiveGlossTopColor;
			glossBottom = MBCoverFlowScrollerInactiveGlossBottomColor;
		}
		
		// Draw the background
		NSGradient *bgGradient = [[NSGradient alloc] initWithStartingColor:bgTop endingColor:bgBottom];
		[bgGradient drawInBezierPath:arrowPath angle:90.0];
		[bgGradient release];
		
		// Draw the gloss
		NSGradient *glossGradient = [[NSGradient alloc] initWithStartingColor:glossTop endingColor:glossBottom];
		NSRect glossRect = [self rectForPart:NSScrollerIncrementLine];
		glossRect.origin.x -= 24.0;
		glossRect.size.width += 20.0;
		glossRect.size.height /= 2.0;
		NSBezierPath *glossPath = [NSBezierPath bezierPathWithRoundedRect:glossRect xRadius:8.0 yRadius:4.0];
		[glossGradient drawInBezierPath:glossPath angle:90.0];
		[glossGradient release];
		
		[arrowPath setLineWidth:2.0];
		
		[outlineColor set];
		[arrowPath stroke];
		
		[[NSGraphicsContext currentContext] restoreGraphicsState];
		
		// Draw the arrow
		NSRect arrowRect = [self rectForPart:NSScrollerIncrementLine];
		NSPoint glyphTip = NSMakePoint(NSMaxX(arrowRect) - 9.0, NSMidY(arrowRect));
		NSPoint glyphTop = NSMakePoint(glyphTip.x - 6.0, NSMinY(arrowRect) + 5.0);
		NSPoint glyphBottom = NSMakePoint(glyphTop.x, NSMaxY(arrowRect) - 5.0);
		NSBezierPath *glyphPath = [NSBezierPath bezierPath];
		[glyphPath moveToPoint:glyphTip];
		[glyphPath lineToPoint:glyphTop];
		[glyphPath lineToPoint:glyphBottom];
		[glyphPath lineToPoint:glyphTip];
		[glyphPath closePath];
		[outlineColor set];
		[glyphPath fill];
	}
}

- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)flag
{
	NSBezierPath *slotPath = [NSBezierPath bezierPathWithRect:NSInsetRect(slotRect, 0.5, 0.5)];
	
	// Determine the proper colors
	NSColor *bgColor = MBCoverFlowScrollerSlotBackgroundColor;
	NSColor *outlineColor = MBCoverFlowScrollerOutlineColor;
	if (![[self window] isKeyWindow]) {
		bgColor = MBCoverFlowScrollerInactiveSlotBackgroundColor;
		outlineColor = MBCoverFlowScrollerInactiveOutlineColor;
	}
	
	[bgColor set];
	[slotPath fill];
	[outlineColor set];
	[slotPath setLineWidth:1.0];
	[slotPath stroke];
	
	NSRect insetRect = NSMakeRect(slotRect.origin.x, slotRect.origin.y+1.0, slotRect.size.width, 1.0);
	[MBCoverFlowScrollerSlotInsetColor set];
	[NSBezierPath fillRect:insetRect];
}

- (void)drawKnob
{
	NSRect knobRect = [self rectForPart:NSScrollerKnob];
	NSBezierPath *path = [NSBezierPath bezierPath];
	
	NSPoint topLeft = NSMakePoint(NSMinX(knobRect) + 8.0, NSMinY(knobRect));
	NSPoint bottomLeft = NSMakePoint(topLeft.x, NSMaxY(knobRect));
	NSPoint topRight = NSMakePoint(NSMaxX(knobRect) - 8.0, topLeft.y);
	NSPoint bottomRight = NSMakePoint(topRight.x, bottomLeft.y);
	
	[path appendBezierPathWithArcWithCenter:NSMakePoint(topLeft.x, (topLeft.y + bottomLeft.y)/2) radius:(bottomLeft.y - topLeft.y)/2 startAngle:90 endAngle:270];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(topRight.x, (topRight.y + bottomRight.y)/2) radius:(bottomRight.y - topRight.y)/2 startAngle:-90 endAngle:90];
	[path moveToPoint:bottomLeft];
	[path lineToPoint:bottomRight];
	
	NSBezierPath *knobPath = path;
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	[knobPath addClip];
	
	// Determine the proper colors
	NSColor *outlineColor = MBCoverFlowScrollerOutlineColor;
	NSColor *bgTop = MBCoverFlowScrollerBackgroundTopColor;
	NSColor *bgBottom = MBCoverFlowScrollerBackgroundBottomColor;
	NSColor *glossTop = MBCoverFlowScrollerGlossTopColor;
	NSColor *glossBottom = MBCoverFlowScrollerGlossBottomColor;
	
	if (![[self window] isKeyWindow]) {
		outlineColor = MBCoverFlowScrollerInactiveOutlineColor;
		bgTop = MBCoverFlowScrollerInactiveBackgroundTopColor;
		bgBottom = MBCoverFlowScrollerInactiveBackgroundBottomColor;
		glossTop = MBCoverFlowScrollerInactiveGlossTopColor;
		glossBottom = MBCoverFlowScrollerInactiveGlossBottomColor;
	}
	
	// Draw the background
	NSGradient *bgGradient = [[NSGradient alloc] initWithStartingColor:bgTop endingColor:bgBottom];
	[bgGradient drawInBezierPath:knobPath angle:90.0];
	[bgGradient release];
	
	// Draw the gloss
	NSGradient *glossGradient = [[NSGradient alloc] initWithStartingColor:glossTop endingColor:glossBottom];
	NSRect glossRect = [self rectForPart:NSScrollerKnob];
	glossRect.origin.x += 4.0;
	glossRect.size.width -= 8.0;
	glossRect.size.height /= 2.0;
	NSBezierPath *glossPath = [NSBezierPath bezierPathWithRoundedRect:glossRect xRadius:8.0 yRadius:4.0];
	[glossGradient drawInBezierPath:glossPath angle:90.0];
	[glossGradient release];
	
	[knobPath setLineWidth:2.0];
	
	[outlineColor set];
	[knobPath stroke];
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (NSRect)_drawingRectForPart:(NSScrollerPart)aPart
{
	// Super's implementation has some side effects
	[super _drawingRectForPart:aPart];
	
	// Return the appropriate rectangle
	return [self rectForPart:aPart];
}

- (NSBezierPath *)_leftArrowPath
{
	NSRect arrowRect = [self rectForPart:NSScrollerDecrementLine];
	NSBezierPath *path = [NSBezierPath bezierPath];
	
	NSPoint topLeft = NSMakePoint(NSMinX(arrowRect) + 8.0, NSMinY(arrowRect));
	NSPoint bottomLeft = NSMakePoint(topLeft.x, NSMaxY(arrowRect));
	NSPoint topRight = NSMakePoint(NSMaxX(arrowRect), topLeft.y);
	NSPoint bottomRight = NSMakePoint(topRight.x, bottomLeft.y);
	
	[path appendBezierPathWithArcWithCenter:NSMakePoint(topLeft.x, (topLeft.y + bottomLeft.y)/2) radius:(bottomLeft.y - topLeft.y)/2 startAngle:90 endAngle:270];
	[path lineToPoint:topRight];
	[path lineToPoint:bottomRight];
	[path moveToPoint:topRight];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(arrowRect), (topRight.y + bottomRight.y)/2) radius:(bottomRight.y - topRight.y)/2 startAngle:90 endAngle:270];
	[path moveToPoint:bottomRight];
	[path lineToPoint:bottomLeft];
	[path setWindingRule:NSEvenOddWindingRule];
	[path closePath];
	
	return path;
}

- (NSBezierPath *)_rightArrowPath
{
	NSRect arrowRect = [self rectForPart:NSScrollerIncrementLine];
	NSBezierPath *path = [NSBezierPath bezierPath];
	
	NSPoint topLeft = NSMakePoint(NSMinX(arrowRect), NSMinY(arrowRect));
	NSPoint bottomLeft = NSMakePoint(topLeft.x, NSMaxY(arrowRect));
	NSPoint topRight = NSMakePoint(NSMaxX(arrowRect)-8.0, topLeft.y);
	NSPoint bottomRight = NSMakePoint(topRight.x, bottomLeft.y);
	
	[path appendBezierPathWithArcWithCenter:NSMakePoint(topRight.x, (topRight.y + bottomRight.y)/2) radius:(bottomRight.y - topRight.y)/2 startAngle:-90 endAngle:90];
	[path lineToPoint:bottomLeft];
	[path lineToPoint:topLeft];
	[path moveToPoint:bottomLeft];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(arrowRect), (topLeft.y + bottomLeft.y)/2) radius:(bottomLeft.y - topLeft.y)/2 startAngle:270 endAngle:90];
	[path moveToPoint:topLeft];
	[path lineToPoint:topRight];
	[path setWindingRule:NSEvenOddWindingRule];
	[path closePath];
	
	return path;	
}

/*- (NSScrollerPart)hitPart
{
	return [self testPart:[[NSApp currentEvent] locationInWindow]];
}*/

@end

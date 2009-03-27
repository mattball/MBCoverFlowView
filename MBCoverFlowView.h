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

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@class MBCoverFlowScroller;

@interface MBCoverFlowView : NSView {
	NSInteger _selectionIndex;
	
	CAScrollLayer *_scrollLayer;
	CALayer *_containerLayer;
	CALayer *_leftGradientLayer;
	CALayer *_rightGradientLayer;
	CALayer *_bottomGradientLayer;
	
	CGImageRef _shadowImage;
	CATransform3D _leftTransform;
	CATransform3D _rightTransform;
	
	NSSize _itemSize;
	NSArray *_content;
	
	NSViewController *_accessoryController;
	
	MBCoverFlowScroller *_scroller;
}

/**
 * @name        Loading Data
 */

/**
 * @brief       The receiver's content object.
 */
@property (nonatomic, copy) NSArray *content;

/**
 * @name        Setting Display Attributes
 */

/**
 * @brief       The size of the flow items.
 */
@property (nonatomic, assign) NSSize itemSize;

/**
 * @brief       The controller which manages the receiver's accessory view.
 *
 * @details     The accessory view will be displayed below the flow images.
 */
@property (nonatomic, retain) NSViewController *accessoryController;

/**
 * @name        Managing the Selection
 */

/**
 * @brief       The index of the receiver's front-most item.
 */
@property (nonatomic, assign) NSInteger selectionIndex;

/**
 * @name    Layout Support
 */

/**
 * @brief       Returns the area occupied by the flow item at the 
 *              specified index.
 *
 * @param       index       The index of the item
 *
 * @return      A rectangle defining the area in which the view draws the
 *              item at \c index, or \c NSZeroRect if the index is invalid.
 */
- (NSRect)rectForItemAtIndex:(NSInteger)index;

/**
 * @brief       Returns the index of the flow item a given point lies in.
 *
 * @param       aPoint      A point in the coordinate system of the receiver.
 *
 * @return      The index of the flow item \c aPoint lies in, or \c NSNotFound
 *              is \c aPoint does not lie inside an item.
 */
- (NSInteger)indexOfItemAtPoint:(NSPoint)aPoint;

@end

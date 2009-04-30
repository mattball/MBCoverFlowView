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

/**
 * @brief       An NSView subclass which displays a collection of
 *              items using the Cover Flow style.
 */
@interface MBCoverFlowView : NSView {
	NSInteger _selectionIndex;
	
	// Layers
	CAScrollLayer *_scrollLayer;
	CALayer *_containerLayer;
	CALayer *_leftGradientLayer;
	CALayer *_rightGradientLayer;
	CALayer *_bottomGradientLayer;
	
	// Appearance
	CGImageRef _shadowImage;
	CATransform3D _leftTransform;
	CATransform3D _rightTransform;
	
	// Display Attributes
	NSSize _itemSize;
	NSViewController *_accessoryController;
	MBCoverFlowScroller *_scroller;
	BOOL _showsScrollbar;
	BOOL _autoresizesItems;
	CGImageRef _placeholderRef;
	NSImage *_placeholderIcon;
	
	// Data
	NSArray *_content;
	NSString *_imageKeyPath;
	NSOperationQueue *_imageLoadQueue;
	
	// Bindings
	NSMutableDictionary *_bindingInfo;
	
	// Actions
	id _target;
	SEL _action;
}

/**
 * @name        Loading Data
 */

/**
 * @brief       The receiver's content object.
 *
 * @see         imageKeyPath
 */
@property (nonatomic, copy) NSArray *content;

/**
 * @brief       The key path which returns the image for an item
 *              in the receiver's \c content array.
 *
 * @see         content
 */
@property (nonatomic, copy) NSString *imageKeyPath;

/**
 * @name        Setting Display Attributes
 */

/**
 * @brief       Whether or not the receiver should resize items to fit
 *              the available vertical space. Defaults to \c YES.
 */
@property (nonatomic, assign) BOOL autoresizesItems;

/**
 * @brief       The size of the flow items.
 */
@property (nonatomic, assign) NSSize itemSize;

/**
 * @brief       Whether or not the receiver should display a scrollbar at
 *              the bottom of the view.
 */
@property (nonatomic, assign) BOOL showsScrollbar;

/**
 * @brief       The controller which manages the receiver's accessory view.
 * @details     The accessory controller's representedObject will be bound
 *              to the receiver's selectedObject. The accessory controller's 
 *              view will be displayed below the flow images.
 */
@property (nonatomic, retain) NSViewController *accessoryController;

/**
 * @brief       The icon which will be displayed for items which have not had
			    image data loaded.
 * @details     This image should preferably be a template icon (using NSImage's
 *              \c -setTemplate: method), so that the view can color the icon
 *              appropriately.
 */
@property (nonatomic, retain) NSImage *placeholderIcon;

/**
 * @name        Managing the Selection
 */

/**
 * @brief       The index of the receiver's front-most item.
 *
 * @see         selectedObject
 */
@property (nonatomic, assign) NSInteger selectionIndex;

/**
 * @brief       The receiver's front-most item.
 *
 * @see         selectionIndex
 */
@property (nonatomic, assign) id selectedObject;

/**
 * @name        The Target/Action Mechanism
 */

/**
 * @brief       The target object that receives action messages from the view.
 *
 * @see         action
 */
@property (nonatomic, assign) id target;

/**
 * @brief       The selector associated with the view.
 * @details     The action will be called when the user double-clicks an item
 *              or presses the Return key.
 *
 * @see         target
 */
@property (nonatomic, assign) SEL action;

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
 *
 * @see         indexOfItemAtPoint:
 */
- (NSRect)rectForItemAtIndex:(NSInteger)index;

/**
 * @brief       Returns the index of the flow item a given point lies in.
 *
 * @param       aPoint      A point in the coordinate system of the receiver.
 *
 * @return      The index of the flow item \c aPoint lies in, or \c NSNotFound
 *              is \c aPoint does not lie inside an item.
 *
 * @see         rectForItemAtIndex:
 */
- (NSInteger)indexOfItemAtPoint:(NSPoint)aPoint;

@end

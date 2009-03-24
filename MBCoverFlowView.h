//
//  MBCoverFlowView.h
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/13/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface MBCoverFlowView : NSView {
	NSInteger _selectedIndex;
	CAScrollLayer *_scrollLayer;
	CALayer *_containerLayer;
	CALayer *_leftGradientLayer;
	CALayer *_rightGradientLayer;
	CALayer *_bottomGradientLayer;
	
	CGImageRef _shadowImage;
	CATransform3D _leftTransform;
	CATransform3D _rightTransform;
	
	NSSize _itemSize;
	NSArray *_contents;
	
	NSViewController *_accessoryController;
}

@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, assign) NSSize itemSize;
@property (nonatomic, copy) NSArray *contents;
@property (nonatomic, retain) NSViewController *accessoryController;

/**
 * @name    Layout
 */

- (NSInteger)indexOfItemAtPoint:(NSPoint)aPoint;
- (NSRect)frameOfItemAtIndex:(NSUInteger)index;

@end

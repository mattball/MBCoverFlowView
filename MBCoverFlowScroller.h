//
//  MBCoverFlowScroller.h
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/24/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MBCoverFlowScroller : NSScroller {
	NSUInteger _numberOfIncrements;
}

@property (nonatomic, assign) NSUInteger numberOfIncrements;

@end

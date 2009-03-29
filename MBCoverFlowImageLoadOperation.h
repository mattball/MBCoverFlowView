//
//  MBCoverFlowImageLoadOperation.h
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/28/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface MBCoverFlowImageLoadOperation : NSOperation {
	CALayer *_layer;
	NSString *_imageKeyPath;
}

@property (nonatomic, retain) CALayer *layer;
@property (nonatomic, copy) NSString *imageKeyPath;

- (id)initWithLayer:(CALayer *)layer imageKeyPath:(NSString *)imageKeyPath;

@end

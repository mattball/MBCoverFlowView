//
//  MBCoverFlowImageLoadOperation.h
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/28/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

/**
 * @class       MBCoverFlowImageLoadOperation
 *
 * @brief       An NSOperation which loads the image for a Cover Flow layer.
 */
@interface MBCoverFlowImageLoadOperation : NSOperation {
	CALayer *_layer;
	NSString *_imageKeyPath;
}

/**
 * @name        Initialization
 */

/**
 * @brief       Returns an initialized MBCoverFlowImageLoadOperation object
 *              for the specified layer with the specified key path.
 *
 * @param       layer           The operation's \c layer property.
 * @param       imageKeyPath    The operation's \c imageKeyPath property.
 *
 * @return      The initialized MBCoverFlowImageLoadOperation object.
 */
- (id)initWithLayer:(CALayer *)layer imageKeyPath:(NSString *)imageKeyPath;

/**
 * @name        Relationships
 */

/**
 * @brief       The layer whose image should be loaded.
 */
@property (nonatomic, retain) CALayer *layer;

/**
 * @brief       The key path which, when applied to the layer's 
 *              \c representedObject, will return the image for the layer.
 * @details     If this property is \c nil, the layer's \c representedObject
 *              will be interpreted as the image.
 */
@property (nonatomic, copy) NSString *imageKeyPath;

@end

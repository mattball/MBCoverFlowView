//
//  NSImage+MBCoverFlowAdditions.h
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/23/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (MBCoverFlowAdditions)

/**
 * @brief       Returns a CGImageRef for the image.
 *
 * @return      A CGImageRef representation for the image.
 */
- (CGImageRef)imageRef;

@end

//
//  MBCoverFlowViewController.m
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/17/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import "MBCoverFlowViewController.h"


@implementation MBCoverFlowViewController

- (void)awakeFromNib
{
	NSMutableArray *images = [NSMutableArray array];
	
	NSString *file;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:@"/Users/matt/Pictures/Photo Booth"];
	
	int count = 0;
	while ((file = [dirEnum nextObject])) 
	{
		NSImage *image = [[NSImage alloc] initWithContentsOfFile:[@"/Users/matt/Pictures/Photo Booth" stringByAppendingPathComponent:file]];
		if (image != nil) {
			[images addObject:image];
		}
		[image release];
		
		count++;
	}
	
	[self.view setContents:images];
	
}

@end

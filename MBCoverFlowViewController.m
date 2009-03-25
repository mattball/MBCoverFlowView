//
//  MBCoverFlowViewController.m
//  MBCoverFlowView
//
//  Created by Matt Ball on 3/17/09.
//  Copyright 2009 Daybreak Apps. All rights reserved.
//

#import "MBCoverFlowViewController.h"

#import "MBCoverFlowView.h"

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
	
	[(MBCoverFlowView *)self.view setContent:images];
	
	NSViewController *labelViewController = [[NSViewController alloc] initWithNibName:nil bundle:nil];
	NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
	[label setBordered:NO];
	[label setBezeled:NO];
	[label setObjectValue:@"Test"];
	[label setDrawsBackground:NO];
	[label setTextColor:[NSColor whiteColor]];
	[label setFont:[NSFont boldSystemFontOfSize:12.0]];
	[label sizeToFit];
	[labelViewController setView:label];
	[label release];
	[(MBCoverFlowView *)self.view setAccessoryController:labelViewController];
	[labelViewController release];
}

@end

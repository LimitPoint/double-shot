//  NSString+OpenCV.mm
//  Double Shot
//
//  
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//

#import "UIImage+OpenCV.h"

#import "NSString+OpenCV.h"
#import "Stitcher.h"

@implementation NSString (NSString_OpenCV)

-(IplImage*)IPLImage
{
	IplImage* iplImage = nil;
	
	UIImage *uiImage = [[UIImage imageNamed:self] fixOrientation];
    
	if (uiImage) {
		iplImage = [uiImage IPLImage];
	}
	
	return iplImage;
}

-(IplImage*)IPLImageByScaling:(float)scale
{
	IplImage* iplImageScaled = nil;
	
	IplImage* iplImage = [self IPLImage];
	
	if (iplImage) {
		
		if (scale > 0) {
			iplImageScaled = [Stitcher createImageWithSize:cvSize(iplImage->width*scale, iplImage->height*scale) depth:iplImage->depth channels:iplImage->nChannels];
			
			if (iplImageScaled) {
				cvResize(iplImage, iplImageScaled, CV_INTER_CUBIC);
			}
			
			[Stitcher releaseImage:&iplImage];
		}
		else {
			iplImageScaled = iplImage;
		}
	}
	
	return iplImageScaled;
}


@end

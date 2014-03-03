//  UIImage+OpenCV.mm
//  Double Shot
//
//  
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//

#import "UIImage+OpenCV.h"
#import "Stitcher.h"

@implementation UIImage (UIImage_OpenCV)

-(IplImage*)IPLImage
{
	IplImage *iplimage = nil;
	
	try {
		
		iplimage = [Stitcher createImageWithSize:cvSize(self.size.width, self.size.height) depth:IPL_DEPTH_8U channels:4];
		
		if (iplimage) {
			CGImageRef imageRef = self.CGImage;
			
			CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.CGImage);
			
			CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
															iplimage->depth, iplimage->widthStep,
															colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
			
			if (contextRef) {
				CGContextDrawImage(contextRef, CGRectMake(0, 0, self.size.width, self.size.height), imageRef);
				CGContextRelease(contextRef);
			}
			
			CGColorSpaceRelease(colorSpace);
		}
		
	} catch (cv::Exception exp) {
		NSLog(@"%s", exp.msg.c_str());
	}
	
	return iplimage;
}

-(IplImage*)IPLImageByScaling:(float)scale
{
	IplImage* iplImageScaled = nil;
	
	IplImage* iplImage = [self IPLImage];
	
	if (iplImage) {
		
		iplImageScaled = [Stitcher createImageWithSize:cvSize(iplImage->width*scale, iplImage->height*scale) depth:iplImage->depth channels:iplImage->nChannels];
		
		if (iplImageScaled) {
			cvResize(iplImage, iplImageScaled, CV_INTER_CUBIC);
		}
		
		[Stitcher releaseImage:&iplImage];
	}
	
	return iplImageScaled;
}

+ (UIImage *)imageWithCVMat:(const cv::Mat&)cvMat
{
    return MatToUIImage(cvMat);
}

+(UIImage *)imageWithIPLImage:(IplImage*)iplImage
{
	UIImage * uiImage = nil;
	
	if (iplImage) {
        // Note that
        // cv::Mat has a conversion operator to IplImage.
		uiImage = [UIImage imageWithCVMat:iplImage];
	}
	
	return uiImage;
}

/*
 
 UIImage orientation issues are discussed in Stack Overflow
 
 http://stackoverflow.com/questions/20204495/mfmailcomposeviewcontroller-image-orientation
 
 and
 
 http://stackoverflow.com/questions/5427656/ios-uiimagepickercontroller-result-image-orientation-after-upload
 
 with the solution chosen from the latter.
 
*/
- (UIImage *)fixOrientation {
	
    // No-op if the orientation is already correct
    if (self.imageOrientation == UIImageOrientationUp) return self;
	
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
	
    switch (self.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, self.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
			
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
			
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, self.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
    }
	
    switch (self.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
			
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
    }
	
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, self.size.width, self.size.height,
                                             CGImageGetBitsPerComponent(self.CGImage), 0,
                                             CGImageGetColorSpace(self.CGImage),
                                             CGImageGetBitmapInfo(self.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (self.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,self.size.height,self.size.width), self.CGImage);
            break;
			
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,self.size.width,self.size.height), self.CGImage);
            break;
    }
	
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}


@end

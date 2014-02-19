//
//  Stitcher.h
//  Double Shot
//
//  Created by Joe Pagliaro.
//  Copyright 2014 Limit Point LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol StitcherDelegate;

@interface Stitcher : NSObject {
	//id<StitcherDelegate> delegate;
	
	int depth;
	int channels;
	
	int input_image_width;
	int input_image_height;
	
	int marginSize;
	
	int blended_width;
	int blended_height;
	CvSize blended_size;
		
	float progress;
	float progressMax;
}

@property (nonatomic, retain) UIImage* intermediateResult;

@property (nonatomic, assign) id<StitcherDelegate> delegate;

// Settable options, in "stitch" method
@property (nonatomic, assign) float inputImageScaling;	// scale, as a fraction, each input image
@property (nonatomic, assign) float blendWidthScaling;
@property (nonatomic, assign) float marginPercent;		// percent, as a fraction, to specify amount of overlap of the input images
@property (nonatomic, assign) float homographyScaling;	// scale, as a fraction, of image for homograph

@property (nonatomic, assign) bool crop;				// crop the final "joined image", performed at end of "stitchImages"
@property (nonatomic, assign) bool betterInterpolation; // CV_INTER_CUBIC vs. CV_INTER_LINEAR
/*
 interpolationMethodWarp
 
 Interpolation method for cvWarpPerspective
 
 CV_INTER_NN - nearest-neigbor interpolation
 CV_INTER_LINEAR - bilinear interpolation (used by default)
 CV_INTER_AREA - resampling using pixel area relation. It is the preferred method for image decimation that gives moire-free results. In terms of zooming it is similar to the CV_INTER_NN method
 CV_INTER_CUBIC - bicubic interpolation
 
 */

@property (nonatomic, assign) int interpolationMethodWarp; // Value based on "betterInterpolation", used in calls to cvWarpPerspective

@property (nonatomic, assign) bool warpStitchPerspective; // warp the stitched images to fit into the destination image, using cvWarpPerspective

@property (nonatomic, assign) bool equalize;			// compute the homography on equalized copies of the input images
@property (nonatomic, assign) bool blend;				// blend images after applying the homography
@property (nonatomic, assign) bool makeHomography;		// set the homograhy to the identity


+ (void)shouldAbort;

+ (IplImage*)createImageWithSize:(CvSize)size depth:(int)in_depth channels:(int)in_channels;
+ (void)releaseImage:(IplImage**)image;

- (void)freeMemory:(NSString*)msg;

- (IplImage*)stitchImages:(NSMutableArray*)images error:(NSError**)error;
- (void)beginStitchingImages:(NSMutableArray*)images error:(NSError**)error;

@end

// The delegate is "DoubleShotViewController"
@protocol StitcherDelegate

- (void)stitcher:(Stitcher*)stitcher didFinishIntermediateStitchWithImage:(UIImage*)image;
- (void)stitcher:(Stitcher*)stitcher didFinishStitch:(UIImage*)image;
- (void)stitcher:(Stitcher*)stitcher didUpdate:(NSString*)update;
- (void)stitcher:(Stitcher*)stitcher didUpdateWithProgress:(NSNumber*)progressPercent;

@end

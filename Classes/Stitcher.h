//
//  Stitcher.h
//  Double Shot
//
//  
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

// Options, some may be modified in the App's options pane
@property (nonatomic, assign) float inputImageScaling;      // percent fraction to reduce input image size
@property (nonatomic, assign) float blendWidthScaling;      // effectively blend over a region inset from the computed blend region
@property (nonatomic, assign) float marginPercent;          // percent fraction specifying width of matching region (determines width of guides)
@property (nonatomic, assign) float homographyScaling;      // percent fraction to scale the matching region determined by mrginPercent

@property (nonatomic, assign) bool crop;                    // flag determining if the full homogrph will be displayed
@property (nonatomic, assign) int interpolationMethodWarp;  // Interpolation methiod used in cvWarpPerspective: CV_INTER_CUBIC (default) vs CV_INTER_LINEAR
@property (nonatomic, assign) bool equalize;                // compute the homography using histogram equalized copies of the input images
@property (nonatomic, assign) bool blend;                   // blend images after applying the homography, otherwise just "add" them with cvAdd
@property (nonatomic, assign) bool makeHomography;          // set the homograhy to the identity
@property (nonatomic, assign) bool highHessianThreshold;    // choose between 300 and 500 (default) for the Hessian threshold for SURF
@property (nonatomic, assign) bool extendedDescriptors;     // choose between 64 (default) and 128 length descriptors for SURF

+ (void)shouldAbort;

+ (IplImage*)createImageWithSize:(CvSize)size depth:(int)in_depth channels:(int)in_channels;
+ (void)releaseImage:(IplImage**)image;



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

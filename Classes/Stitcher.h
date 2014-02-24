//
//  Stitcher.h
//  Double Shot
//
//  
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol StitcherDelegate;

@interface Stitcher : NSObject {
    
	int depth;                  // images should have same depth and channels
	int channels;
	
	int input_image_width;      // images should be the same dimensions
	int input_image_height;
	
	int marginSize;             // determined by marginPercent property
	
	int blended_width;          // these paramaters depend on the crop property choice
	int blended_height;
	CvSize blended_size;
		
	float progress;             // progress percent is determined by index of current progress update, up to total updates
	float progressMax;
}

@property (nonatomic, retain) UIImage* intermediateResult;
@property (nonatomic, assign) id<StitcherDelegate> delegate;

// Options, some may be modified in the App's options pane
@property (nonatomic, assign) float inputImageScaling;      // percent fraction to reduce input image size
@property (nonatomic, assign) float blendWidthScaling;      // percent to reduce blend width of computed blend region, less ghosting vs smoother blend
@property (nonatomic, assign) float marginPercent;          // percent fraction specifying width of matching region (determines width of guides)
@property (nonatomic, assign) float homographyScaling;      // percent fraction to scale the matching region determined by mrginPercent
@property (nonatomic, assign) float lastMinSquaredDistancePercent;      // used when computing nearest neighbor of a SURF descriptor

@property (nonatomic, assign) bool crop;                    // flag determines if the full homogrph will be displayed
@property (nonatomic, assign) int interpolationMethodWarp;  // Interpolation methiod used in cvWarpPerspective: CV_INTER_CUBIC (default) vs CV_INTER_LINEAR
@property (nonatomic, assign) bool equalize;                // compute the homography using histogram equalized copies of the input images
@property (nonatomic, assign) bool blend;                   // blend images after applying the homography, otherwise just "add" them with cvAdd
@property (nonatomic, assign) bool makeHomography;          // set the homograhy to the identity
@property (nonatomic, assign) bool highHessianThreshold;    // choose between 300 and 500 (default - faster) for the Hessian threshold for SURF
@property (nonatomic, assign) bool extendedDescriptors;     // choose between 64 (default - faster) and 128 length descriptors for SURF
@property (nonatomic, assign) bool useLastMinSquaredDistancePercent;     // for "naive" descriptor method


+ (void)shouldAbort;

+ (IplImage*)createImageWithSize:(CvSize)size depth:(int)in_depth channels:(int)in_channels;
+ (void)releaseImage:(IplImage**)image;

- (IplImage*)stitchImages:(NSMutableArray*)images error:(NSError**)error;

- (void)beginStitchingImages:(NSMutableArray*)images error:(NSError**)error;

@end

// DoubleShotViewController implements these
@protocol StitcherDelegate
- (void)stitcher:(Stitcher*)stitcher didFinishIntermediateStitchWithImage:(UIImage*)image;
- (void)stitcher:(Stitcher*)stitcher didFinishStitch:(UIImage*)image;
- (void)stitcher:(Stitcher*)stitcher didUpdate:(NSString*)update;
- (void)stitcher:(Stitcher*)stitcher didUpdateWithProgress:(NSNumber*)progressPercent;

@end

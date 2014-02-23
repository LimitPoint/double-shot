//  UIImage+OpenCV.mm
//  Double Shot
//
//  
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//

@interface UIImage (UIImage_OpenCV)

-(IplImage*)IPLImage;
-(IplImage*)IPLImageByScaling:(float)scaleFactor;
+(UIImage *)imageWithCVMat:(const cv::Mat&)cvMat;
+(UIImage *)imageWithIPLImage:(IplImage*)iplImage;

- (UIImage *)fixOrientation;

@end

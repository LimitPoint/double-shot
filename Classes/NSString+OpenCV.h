//  NSString+OpenCV.h
//  Double Shot
//
//  
//  Copyright 2014 Limit Point LLC. All rights reserved.
//

@interface NSString (NSString_OpenCV)
-(IplImage*)IPLImage;
-(IplImage*)IPLImageByScaling:(float)scaleFactor;
@end

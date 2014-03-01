//
//  Stitcher.mm
//  Double Shot
//
//  
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//

#import "Stitcher.h"
#import "UIImage+OpenCV.h"

#import <mach/mach.h> 
#import <mach/mach_host.h>

static int s_nbrImagesCreated = 0;
static int s_cummulativeImageSize = 0;
static int s_nbrImagesReleased = 0;
static bool s_should_abort = false;

class pair {
public:
    int i;
    int j;
    float distance;
    
    friend bool operator<(const pair& x, const pair& y);
};

bool operator<(const pair& x, const pair& y)
{
    return x.distance < y.distance;
}

static UInt32 freeMemory(UInt32 divisor)
{
    mach_port_t           host_port = mach_host_self();
    mach_msg_type_number_t   host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t               pagesize;
    vm_statistics_data_t     vm_stat;
	
    host_page_size(host_port, &pagesize);
	
    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) NSLog(@"Failed to fetch vm statistics");
	
    natural_t mem_free = vm_stat.free_count * pagesize;
	
    return mem_free/divisor;
}

@implementation Stitcher

- (id)init
{
	self = [super init];
	
    self.inputImageScaling = 0;
    self.blendWidthScaling = 0.33;
	self.marginPercent = 0.33;
	self.homographyScaling = 0.5;
    self.crop = true;
	self.blend = true;
	self.equalize = true;
	self.makeHomography = true;
	self.interpolationMethodWarp = CV_INTER_LINEAR;
    self.highHessianThreshold = YES;
    self.extendedDescriptors = NO;
    self.lastMinSquaredDistancePercent = 0.7;
    self.useLastMinSquaredDistancePercent = YES;
    self.keypointPercent = 1.0;
    self.useRANSAC = true;
		
	self.intermediateResult = nil;
	
	self.progress = 0;
	self.progressMax = 11;
	
	s_nbrImagesCreated = 0;
 	s_cummulativeImageSize = 0;
	s_nbrImagesReleased = 0;
	s_should_abort = false;
	
	return self;
}

- (void)sendDelegateIntermediateStitchUIImage:(UIImage*)image
{
	self.intermediateResult = image;
	[self.delegate stitcher:self didFinishIntermediateStitchWithImage:self.intermediateResult];
}

- (void)sendDelegateIntermediateStitchImage:(IplImage*)image
{
	self.intermediateResult = [UIImage imageWithIPLImage:image];
	[self.delegate stitcher:self didFinishIntermediateStitchWithImage:self.intermediateResult];
}

+ (void)shouldAbort
{
	s_should_abort = true;
	
	NSLog(@"Aborting stitch. (Free memory = %lu)", freeMemory(1000000));
}

- (void)freeMemory:(NSString*)msg
{
	[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Free memory%@= %lu", msg, freeMemory(1000000)]];
	NSLog(@"Free memory%@= %lu", msg, freeMemory(1000000));
}

+ (IplImage*)createImageWithSize:(CvSize)size depth:(int)in_depth channels:(int)in_channels
{
	IplImage* iplImage = nil;
		
	try {
		if (!s_should_abort) {
			iplImage = cvCreateImage(size, in_depth, in_channels);
			if (iplImage) {
				s_nbrImagesCreated += 1;
				s_cummulativeImageSize += iplImage->imageSize;
			}
		}
	}
	catch (std::exception& e) {
		NSLog(@"%s", e.what());
	}
	
	return iplImage;
}

+ (void)releaseImage:(IplImage**)image
{
	if (*image != nil) {
		s_nbrImagesReleased += 1;
		s_cummulativeImageSize -= (*image)->imageSize;		
		cvReleaseImage(image);
		*image = nil;
	}
}

- (float)progressPercent
{
    return self.progress/self.progressMax;
}

- (IplImage*)create_cropped_image:(IplImage*)src cropRect:(CvRect)roi
{
	if (!src || s_should_abort) {
		return nil;
	}
	
	// Must have dimensions of output image
	IplImage* cropped = [Stitcher createImageWithSize:cvSize(roi.width,roi.height) depth:src->depth channels:src->nChannels];
	
	if (cropped) {
		// Say what the source region is
		cvSetImageROI(src, roi);
		
		// Do the copy
		cvCopy(src, cropped);
		cvResetImageROI(src);
	}
	
	return cropped;
}

- (IplImage*)create_cropped_image_top_bottom:(IplImage*)src inset:(int)inset
{
	if (!src || s_should_abort) {
		return nil;
	}
	
	IplImage* cropped_image = nil;
	
	int top = 0;
	int bottom = src->height;
	
	for(int x=0; x < src->width; x++)
	{			
		for(int y=0; y < src->height; y++) 
        {			
			CvScalar source = cvGet2D(src, y, x);
			
			if ((source.val[0] == 0) && (source.val[1] == 0) && (source.val[2] == 0)) {
				if (top < y) {
					top = y;
				}
			}
			else {
				break;
			}
        }
		
	}
	
	for(int x=0; x < src->width; x++)
	{			
		for(int y=src->height-1; y >= 0; y--) 
        {			
			CvScalar source = cvGet2D(src, y, x);
			
			if ((source.val[0] == 0) && (source.val[1] == 0) && (source.val[2] == 0)) {
				if (bottom > y) {
					bottom = y;
				}
			}
			else {
				break;
			}
        }
		
	}
	
	if (bottom > top) {
		
		// fudge!
		bottom -= inset;
		top += inset;
		
		CvRect roi = cvRect(0, top, src->width, bottom-top);
		cropped_image = [self create_cropped_image:src cropRect:roi];
	}
	
	
	return cropped_image;
}

- (void)warpImageCoordinates:(IplImage*)image into:(CvPoint2D32f*)dst withPerspectiveTransform:(CvMat*)h
{	
	if (!image || s_should_abort) {
		return;
	}
	
	CvPoint2D32f src[4];
	
	// top left	
	src[0].x = 0;			
	src[0].y = 0;
	
	// top right
	src[1].x = image->width;	
	src[1].y = 0;	
	
	// bottom right
	src[2].x = image->width;	
	src[2].y = image->height;	
	
	// bottom left
	src[3].x = 0;				
	src[3].y = image->height;
	
	float h1 = cvmGet(h, 0, 0);
	float h2 = cvmGet(h, 0, 1);
	float h3 = cvmGet(h, 0, 2);
	
	float h4 = cvmGet(h, 1, 0);
	float h5 = cvmGet(h, 1, 1);
	float h6 = cvmGet(h, 1, 2);
	
	float h7 = cvmGet(h, 2, 0);
	float h8 = cvmGet(h, 2, 1);
	float h9 = cvmGet(h, 2, 2);
	
	dst[0].x = (src[0].x*h1+src[0].y*h2+h3 )/(src[0].x*h7+src[0].y*h8+h9);			
	dst[0].y = (src[0].x*h4+src[0].y*h5+h6 )/(src[0].x*h7+src[0].y*h8+h9);
	
	dst[1].x = (src[1].x*h1+src[1].y*h2+h3 )/(src[1].x*h7+src[1].y*h8+h9);			
	dst[1].y = (src[1].x*h4+src[1].y*h5+h6 )/(src[1].x*h7+src[1].y*h8+h9);
	
	dst[2].x = (src[2].x*h1+src[2].y*h2+h3 )/(src[2].x*h7+src[2].y*h8+h9);			
	dst[2].y = (src[2].x*h4+src[2].y*h5+h6 )/(src[2].x*h7+src[2].y*h8+h9);	
	
	dst[3].x = (src[3].x*h1+src[3].y*h2+h3 )/(src[3].x*h7+src[3].y*h8+h9);			
	dst[3].y = (src[3].x*h4+src[3].y*h5+h6 )/(src[3].x*h7+src[3].y*h8+h9);

}

- (IplImage*)prepareImage:(IplImage*)in_image
{
	if (!in_image || s_should_abort) {
		return nil;
	}
	
	IplImage* ipl_prepared = [Stitcher createImageWithSize:cvSize(in_image->width, in_image->height) depth:8 channels:1]; 
	
	if (ipl_prepared) {
		
		cvCvtColor(in_image, ipl_prepared, CV_BGR2GRAY); 
		
		if (ipl_prepared->nChannels == 1) {
			if (self.equalize) {
				
				IplImage* ipl_prepared_eq = [Stitcher createImageWithSize:cvSize(in_image->width, in_image->height) depth:8 channels:1]; 
				
				if (ipl_prepared_eq) {
					cvEqualizeHist(ipl_prepared, ipl_prepared_eq);
					[Stitcher releaseImage:&ipl_prepared];
					ipl_prepared = ipl_prepared_eq;
				}	
			}
		}
	}
	
	return ipl_prepared;
}

- (void)makeTranslationTransform:(CvMat*)T translation_x:(int)translation_x translation_y:(int)translation_y
{
	CvPoint2D32f from[4];
	CvPoint2D32f to[4];
	
	from[0].x = 0;
	from[0].y = 0;
	
	// top-right
	from[1].x = 1;
	from[1].y = 0;
	
	// bottom-right
	from[2].x = 1;
	from[2].y = 1;
	
	// bottom-left
	from[3].x = 0;
	from[3].y = 1;
	
	// to
	// top-left
	to[0].x = from[0].x + translation_x;
	to[0].y = from[0].y + translation_y;
	
	// top-right
	to[1].x = from[1].x + translation_x;
	to[1].y = from[1].y + translation_y;
	
	// bottom-right
	to[2].x = from[2].x + translation_x;
	to[2].y = from[2].y + translation_y;
	
	// bottom-left
	to[3].x = from[3].x + translation_x;
	to[3].y = from[3].y + translation_y;
	
	cvGetPerspectiveTransform(from, to, T);
}

- (double)compareSURFDescriptors:(const float*)imageRightDescriptor
             imageLeftDescriptor:(const float*)imageLeftDescriptor
                descriptorsCount:(int)descriptorsCount
          lastMinSquaredDistance:(float)lastMinSquaredDistance
{
    double squaredDistance = 0;
	
    for (int i = 0; i < descriptorsCount; i += 4) {
		
		squaredDistance += (pow((imageRightDescriptor[i+0] - imageLeftDescriptor[i+0]), 2) +
                            pow((imageRightDescriptor[i+1] - imageLeftDescriptor[i+1]), 2) +
                            pow((imageRightDescriptor[i+2] - imageLeftDescriptor[i+2]), 2) +
                            pow((imageRightDescriptor[i+3] - imageLeftDescriptor[i+3]), 2));
		
        if (squaredDistance > lastMinSquaredDistance)
            break;
    }
	
	return squaredDistance; 
}

- (int)findNearestNeighbor:(const float*)imageRightDescriptor
             imageRightKeyPoint:(const CvSURFPoint*)imageRightKeyPoint
           imageLeftDescriptors:(CvSeq*)imageLeftDescriptors
             imageLeftKeyPoints:(CvSeq*)imageLeftKeyPoints
           nearestDistance:(double*)minSquaredDistance
{
    int descriptorsCount = (int)(imageLeftDescriptors->elem_size/sizeof(float));
    *minSquaredDistance = std::numeric_limits<double>::max();
    double lastMinSquaredDistance = std::numeric_limits<double>::max();
	
    int neighbor = -1;
    for (int i = 0; i < imageLeftDescriptors->total; i++) {
        const CvSURFPoint* imageLeftKeyPoint = (const CvSURFPoint*) cvGetSeqElem(imageLeftKeyPoints, i);
        const float* imageLeftDescriptor = (const float*) cvGetSeqElem(imageLeftDescriptors, i);
		
        if (imageRightKeyPoint->laplacian != imageLeftKeyPoint->laplacian)
            continue;
		
        double squaredDistance = [self compareSURFDescriptors:imageRightDescriptor imageLeftDescriptor:imageLeftDescriptor descriptorsCount:descriptorsCount lastMinSquaredDistance:lastMinSquaredDistance];
		
        if (squaredDistance < *minSquaredDistance) {
            neighbor = i;
            lastMinSquaredDistance = *minSquaredDistance;
            *minSquaredDistance = squaredDistance;
        } else if (squaredDistance < lastMinSquaredDistance) {
            lastMinSquaredDistance = squaredDistance;
        }
        
        if (s_should_abort)
            continue;
    }
    
    if (self.useLastMinSquaredDistancePercent) {
        if (*minSquaredDistance < self.lastMinSquaredDistancePercent * lastMinSquaredDistance)
            return neighbor;
    }
    else {
        return neighbor;
    }
    
    return -1;
}

- (void)computeKeypointMatchesForImage:(IplImage*)ipl_right andImage:(IplImage*)ipl_left withMemoryBlock:(CvMemStorage*)memoryBlock keyPointMatches:(cv::vector<cv::vector<CvPoint2D32f> >&)keyPointMatches
{
    CvSeq* imageRightKeyPoints;
    CvSeq* imageRightDescriptors;
    CvSeq* imageLeftKeyPoints;
    CvSeq* imageLeftDescriptors;
    
    double hessianThreshold = 300;
    int extended = 0;
    
    if (self.highHessianThreshold) {
        hessianThreshold = 500;
    }
    
    if (self.extendedDescriptors) {
        extended = 1;
    }
    
    CvSURFParams params = cvSURFParams(hessianThreshold, extended);
    
    cvExtractSURF(ipl_right, 0, &imageRightKeyPoints, &imageRightDescriptors, memoryBlock, params);
    cvExtractSURF(ipl_left, 0, &imageLeftKeyPoints, &imageLeftDescriptors, memoryBlock, params);
    
    cv::vector<CvPoint2D32f> imageRightMatches;
    cv::vector<CvPoint2D32f> imageLeftMatches;
    
    keyPointMatches.push_back(imageRightMatches);
    keyPointMatches.push_back(imageLeftMatches);
    
    std::vector<pair> pairs;
    
    for (int i = 0; i < imageRightDescriptors->total; i++) {
        
        const CvSURFPoint* imageRightKeyPoint = (const CvSURFPoint*) cvGetSeqElem(imageRightKeyPoints, i);
        const float* imageRightDescriptor =  (const float*) cvGetSeqElem(imageRightDescriptors, i);
        
        double nearestDistance;
        
        int nearestNeighbor = [self findNearestNeighbor:imageRightDescriptor imageRightKeyPoint:imageRightKeyPoint imageLeftDescriptors:imageLeftDescriptors imageLeftKeyPoints:imageLeftKeyPoints nearestDistance:&nearestDistance];
        
        if (nearestNeighbor == -1)
            continue;
        
        pair p;
        
        p.i = i;
        p.j = nearestNeighbor;
        p.distance = nearestDistance;
        
        pairs.push_back(p);
        
        // break out of this loop if aborting
        if (s_should_abort)
            break;
    }
    
    // sort them acsending by distance
    std::sort(pairs.begin(), pairs.end());
    
    int nbrPairsToUse = pairs.size();
    
    nbrPairsToUse *= self.keypointPercent;
    
    for (int i = 0; i < nbrPairsToUse; i++) {
        
        pair p = pairs[i];
        
        //NSLog(@"distance = %f", p.distance);
        
        CvPoint2D32f p1 = ((CvSURFPoint*) cvGetSeqElem(imageRightKeyPoints, p.i))->pt;
        CvPoint2D32f p2 = ((CvSURFPoint*) cvGetSeqElem(imageLeftKeyPoints, p.j))->pt;
        
        keyPointMatches[0].push_back(p1);
        keyPointMatches[1].push_back(p2);
        
        // break out of this loop if aborting
        if (s_should_abort)
            break;
    }
}

- (void)prepareRightMargin:(IplImage*)right_margin andLeftMargin:(IplImage*)left_margin preparedRightMargin:(IplImage*&)ipl_right preparedLeftImage:(IplImage*&)ipl_left scaling:(CvMat&)S
{
    if ((self.homographyScaling != 0) && (self.homographyScaling < 1.0)) {
        
        NSLog(@"Scaling homography margins by %f", self.homographyScaling);
        
        IplImage *scaled_right = [Stitcher createImageWithSize:cvSize(right_margin->width*self.homographyScaling, right_margin->height*self.homographyScaling) depth:depth channels:channels];
        
        if (scaled_right) {
            
            IplImage *scaled_left = [Stitcher createImageWithSize:cvSize(left_margin->width*self.homographyScaling, left_margin->height*self.homographyScaling) depth:depth channels:channels];
            
            if (scaled_left) {
                
                cvResize(right_margin, scaled_right);
                cvResize(left_margin, scaled_left);
                
                ipl_right = [self prepareImage:scaled_right];
                
                if (ipl_right) {
                    
                    ipl_left = [self prepareImage:scaled_left];
                    
                    if (ipl_left) {
                        
                        CvPoint2D32f from[4];
                        CvPoint2D32f to[4];
                        
                        // from
                        // top-left
                        from[0].x = 0;
                        from[0].y = 0;
                        
                        // top-right
                        from[1].x = scaled_right->width;
                        from[1].y = 0;
                        
                        // bottom-right
                        from[2].x = scaled_right->width;
                        from[2].y = scaled_right->height;
                        
                        // bottom-left
                        from[3].x = 0;
                        from[3].y = scaled_right->height;
                        
                        // to
                        // top-left
                        to[0].x = 0;
                        to[0].y = 0;
                        
                        // top-right
                        to[1].x = right_margin->width;
                        to[1].y = 0;
                        
                        // bottom-right
                        to[2].x = right_margin->width;
                        to[2].y = right_margin->height;
                        
                        // bottom-left
                        to[3].x = 0;
                        to[3].y = right_margin->height;
                        
                        cvGetPerspectiveTransform(from, to, &S);
                        
                    }
                }
                
                [Stitcher releaseImage:&scaled_left];
            }
            [Stitcher releaseImage:&scaled_right];
        }
    }
    else {
        ipl_right = [self prepareImage:right_margin];
        
        if (ipl_right) {
            ipl_left = [self prepareImage:left_margin];
        }
        
    }

}

- (bool)validateHomographyCoordinates:(CvPoint2D32f*)warpedCoordinates
{
	bool is_valid = false;
	
	int x1,x2,x3,x4;
	int y1,y2,y3,y4;
	
	x1 = warpedCoordinates[0].x;
	x2 = warpedCoordinates[1].x;
	x3 = warpedCoordinates[2].x;
	x4 = warpedCoordinates[3].x;
	
	y1 = warpedCoordinates[0].y;
	y2 = warpedCoordinates[1].y;
	y3 = warpedCoordinates[2].y;
	y4 = warpedCoordinates[3].y;
	
	NSLog(@"Homograph coordinates =");
	NSLog(@"x, y = %d, %d", x1, y1);
	NSLog(@"x, y = %d, %d", x2, y2);
	NSLog(@"x, y = %d, %d", x3, y3);
	NSLog(@"x, y = %d, %d", x4, y4);
	
	[self.delegate stitcher:self didUpdate:@"Homography Coordinates"];
	[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"x, y = %d, %d", x1, y1]];
	[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"x, y = %d, %d", x2, y2]];
	[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"x, y = %d, %d", x3, y3]];
	[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"x, y = %d, %d", x4, y4]];
	
	if (x1 < marginSize) {
		if (x4 < marginSize) {
			
			//if (x2 > x1) {
			//if (x3 > x4) {
			if ((x2 > x1) && ((fabs(x2-x1) < (2*marginSize))) && ((fabs(x2-x1) > (marginSize/3.0)))) {
				if ((x3 > x4) && ((fabs(x3-x4) < (2*marginSize))) && ((fabs(x3-x4) > (marginSize/3.0)))) {
					
					is_valid = true;
				}
			}
		}
	}
	
	return is_valid;
}


- (void)makeHomographyFor:(IplImage*)in_right toImage:(IplImage*)in_left homography:(CvMat*)H
{
	// homography
	double h_prime[9];
	CvMat H_prime = cvMat(3, 3, CV_32F, h_prime);
	cvSetIdentity(&H_prime);
	
	double t[9];
	CvMat T = cvMat(3, 3, CV_32F, t);
	cvSetIdentity(&T);
    
    [self makeTranslationTransform:&T translation_x:in_left->width - marginSize translation_y:0];

	if ((self.makeHomography == NO) || s_should_abort) {
        [self.delegate stitcher:self didUpdate:@"Make homography is false, or aborting only translating"];
        NSLog(@"Make homography is false, or aborting only translating");
		// apply the translation to the homograph
		cvMatMul(&T, &H_prime, H);
		return;
	}
		
    self.progress += 1;
    [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
    [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Preparing images %f", self.progressPercent]];
	NSLog(@"Preparing images %f", self.progressPercent);
	
	IplImage* right_margin;
	IplImage* left_margin;
	
	int width = MIN(in_right->width, in_left->width);
	int height = in_right->height;
	
	// homographyScaling
	double s_prime[9];
	CvMat S_prime = cvMat(3, 3, CV_32F, s_prime);
	cvSetIdentity(&S_prime);
	
	double s_inverse[9];
	CvMat S_inverse = cvMat(3, 3, CV_32F, s_inverse);
	cvSetIdentity(&S_inverse);
	
	double s[9];
	CvMat S = cvMat(3, 3, CV_32F, s);
	cvSetIdentity(&S);
	
	// extract the image of width marginSize
	CvSize size;
	
	if (marginSize == 0) {
		marginSize = width;
	}
	
	size.width = marginSize;
	size.height = height;
	
	left_margin = [Stitcher createImageWithSize:size depth:depth channels:channels];
	
	if (left_margin) {
		
		right_margin = [Stitcher createImageWithSize:size depth:depth channels:channels];
		
		if (right_margin) {
			
			// copy left marginSize into left
			CvRect left_roi = {in_left->width - size.width, 0, size.width, size.height};
			cvSetImageROI(in_left, left_roi);
			cvCopy(in_left, left_margin);
			cvResetImageROI(in_left);
			
			// copy right marginSize into right
			CvRect right_roi = {0, 0, size.width, size.height};
			cvSetImageROI(in_right, right_roi);
			cvCopy(in_right, right_margin);
			cvResetImageROI(in_right);
			
			IplImage* ipl_right;
			IplImage* ipl_left;
			
            [self prepareRightMargin:right_margin andLeftMargin:left_margin preparedRightMargin:ipl_right preparedLeftImage:ipl_left scaling:S];
            
            cvInvert(&S, &S_inverse);
			
			[Stitcher releaseImage:&right_margin];
			[Stitcher releaseImage:&left_margin];
			
			// create the homograph
			
			if (ipl_right) {
				if (ipl_left) {
                    
                    self.progress += 1;
                    [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
                    [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Finding and matching keypoints %f", self.progressPercent]];
                    NSLog(@"Finding and matching keypoints %f", self.progressPercent);
					
					CvMemStorage* memoryBlock = cvCreateMemStorage();
					
					if (memoryBlock) {
						
						if (!s_should_abort) {
                            
                            cv::vector<cv::vector<CvPoint2D32f> > keyPointMatches;
                            
                            [self computeKeypointMatchesForImage:ipl_right andImage:ipl_left withMemoryBlock:memoryBlock keyPointMatches:keyPointMatches];
							
							CvMat imageRightPoints = cvMat(1, keyPointMatches[0].size(), CV_32FC2, keyPointMatches[0].data());
							CvMat imageLeftPoints = cvMat(1, keyPointMatches[1].size(), CV_32FC2, keyPointMatches[1].data());
                            
                            [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"%lu key point matches", keyPointMatches[0].size()]];
                            
                            NSLog(@"%lu key point matches", keyPointMatches[0].size());
							
							int result = 0;
							
							try {
								if (!s_should_abort) {
                                    
                                    self.progress += 1;
                                    [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
                                    
                                    int method = (self.useRANSAC ? CV_RANSAC : CV_LMEDS); // CV_RANSAC = 8, CV_LMEDS = 4
                                    
                                    [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Finding homography, using %@ method", (self.useRANSAC ? @"RANSAC" : @"LMEDS")]];
                                    
                                    NSLog(@"Finding homography, using %@ method", (self.useRANSAC ? @"RANSAC" : @"LMEDS"));
                                    
									result = cvFindHomography(&imageRightPoints, &imageLeftPoints, &H_prime, method);
                                }
							} catch (std::exception& e) {
								result = 0;
								NSLog(@"%s", e.what());
								[self performSelectorOnMainThread:@selector(showAlert:) withObject:[NSString stringWithFormat:@"%s", e.what()] waitUntilDone:NO];
							}
                            
							if (result == 0) {
								[self.delegate stitcher:self didUpdate:@"Homography result is zero."];
								NSLog(@"Homography result is zero.");
								
								cvSetIdentity(&H_prime);
							}
							else {
                        
								[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"width, height = %d, %d", ipl_right->width, ipl_right->height]];
								NSLog(@"Right image width, height = %d, %d", ipl_right->width, ipl_right->height);
								
                                CvPoint2D32f warpedCoordinates[4];
								[self warpImageCoordinates:ipl_right into:warpedCoordinates withPerspectiveTransform:&H_prime];
                                
                                bool is_valid = [self validateHomographyCoordinates:warpedCoordinates];
								
								if (is_valid == false) {
									[self.delegate stitcher:self didUpdate:@"*** Setting homography to identity ***"];
									NSLog(@"*** Setting homography to identity ***");
																		
									cvSetIdentity(&H_prime);
									is_valid = true;
								}
                            }
							
							// apply the homographyScaling to the homograph
							cvMatMul(&H_prime, &S_inverse, &S_prime);
							cvMatMul(&S, &S_prime, &H_prime);
							
							// apply the translation to the homograph
							cvMatMul(&T, &H_prime, H);
							
						}
                        
						cvReleaseMemStorage(&memoryBlock);
					}
					
					[Stitcher releaseImage:&ipl_left];
				}
				[Stitcher releaseImage:&ipl_right];
			}
			[Stitcher releaseImage:&right_margin];
		}
		[Stitcher releaseImage:&left_margin];
	}
}



- (IplImage*)blend:(IplImage*)right_image with:(IplImage*)left_image usingMask:(IplImage*)warped_mask
{
	if (!right_image || !left_image || !warped_mask || s_should_abort) {
		return nil;
	}
	
    self.progress += 1;
    [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
	[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Blending %f", self.progressPercent]];
	NSLog(@"Blending %f", self.progressPercent);
	
	// the blended image!
	IplImage* blended_image_4 = [Stitcher createImageWithSize:blended_size depth:depth channels:4];
	
	if (blended_image_4) {
		
		cvSet(blended_image_4,cvScalar( 0, 0, 0, 1 ),0);
		
		// blend the images
		for(int y=0; y < blended_height; y++) // loop over rows
		{
			int start = 0;
			int stop = 0;
			
			if (s_should_abort) break;
			
			for(int x=0; x < blended_width; x++) // loop through pixels of current row of mask to find the start and stop of the overlap polygon
			{
				
				if (s_should_abort) break;
				
				CvScalar source_mask = cvGet2D(warped_mask, y, x);
				if (start == 0) {
					if (source_mask.val[0] == 255) {
						start = MAX(x-1,0);
					}
				}
				else {
					if (stop == 0) {
						if (source_mask.val[0] == 0) {
							stop = MAX(x-1,0);
						}
					}
				}
				
				if (stop && start) {
					break;
				}
			}
			
			// blend scaling
			
			//float mergeReductionFactor = BlendWidth();
            float mergeReductionFactor = self.blendWidthScaling;
			int f;
			
			if (stop > start) {
				f = ((stop - start)*(1.0 - mergeReductionFactor))/2;
				start += f;
				stop -= f;
			}
			
			// do the blend
			
			for(int x=0; x < blended_width; x++) // loop through pixels of current row
			{
				if (s_should_abort) break;
				
				if (start == stop) {
					// this ensures nothing is "cut off" above or below the top or bottom of the overlap region
					// (this used to not be a problem when we were using "left_and_right_image"
					CvScalar source_left = cvGet2D(left_image, y, x);
					CvScalar source_right = cvGet2D(right_image, y, x);
					
					CvScalar blended_pixel;
					
					for(int i=0;i<3;i++)
						blended_pixel.val[i] = (source_left.val[i]+source_right.val[i]);
					
					blended_pixel.val[3] = 1;
					
					cvSet2D(blended_image_4, y, x, blended_pixel);
				}
				else {
					if (x < start) {
						//CvScalar source_left = cvGet2D(left_and_right_image, y, x);
						CvScalar source_left = cvGet2D(left_image, y, x);
						cvSet2D(blended_image_4, y, x, source_left);
					}
					else if (x > stop) {
						//CvScalar source_right = cvGet2D(left_and_right_image, y, x);
						CvScalar source_right = cvGet2D(right_image, y, x);
						cvSet2D(blended_image_4, y, x, source_right);
					}
					else {
						CvScalar source_left = cvGet2D(left_image, y, x);
						CvScalar source_right = cvGet2D(right_image, y, x);
						
						float d_left = x-start;
						float d_right = stop-x;
						
						float w_left = d_left/(d_left+d_right);
						float w_right = d_right/(d_left+d_right);
						
						CvScalar blended_pixel;
						
						for(int i=0;i<3;i++)
							blended_pixel.val[i] = (w_right*source_left.val[i]+w_left*source_right.val[i]);
						
						blended_pixel.val[3] = 1;
						
						cvSet2D(blended_image_4, y, x, blended_pixel);
					}
				}
			}
		}
	}
	
	[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Blended %f", self.progressPercent]];
	NSLog(@"Blended %f", self.progressPercent);
	
	return blended_image_4;
}

- (IplImage*)warpImage:(IplImage*)imageToWarp with:(CvMat*)M
{
	if (!imageToWarp || s_should_abort) {
		return nil;
	}
	
	IplImage* warped_image = [Stitcher createImageWithSize:blended_size depth:depth channels:channels]; 
	
	if (warped_image) {
		
		cvSet(warped_image,cvScalarAll(0),0);
		cvWarpPerspective(imageToWarp, warped_image, M, self.interpolationMethodWarp+CV_WARP_FILL_OUTLIERS, cvScalar( 0, 0, 0 ));
	}
	
	return warped_image;
}

- (IplImage*)makeMaskWithCoordinates:(CvPoint2D32f*)image1Coordinates andCoordinates:(CvPoint2D32f*)image2Coordinates
{	
	
	if (s_should_abort) return nil;
	
	[self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Computing blender mask %f", self.progressPercent]];
	NSLog(@"Computing blender mask %f", self.progressPercent);
	
	IplImage* mask = [Stitcher createImageWithSize:blended_size depth:depth channels:1];
	
	if (mask) {
        
		cvZero(mask);
        
        CvPoint* left = new CvPoint[4];
        CvPoint* right = new CvPoint[4];
        
        left[0].x = image1Coordinates[0].x;
		left[0].y = image1Coordinates[0].y;
        
        left[1].x = image1Coordinates[1].x;
		left[1].y = image1Coordinates[1].y;
        
        left[2].x = image1Coordinates[2].x;
		left[2].y = image1Coordinates[2].y;
        
        left[3].x = image1Coordinates[3].x;
		left[3].y = image1Coordinates[3].y;
        
        right[0].x = image2Coordinates[0].x;
		right[0].y = image2Coordinates[0].y;
        
        right[1].x = image2Coordinates[1].x;
		right[1].y = image2Coordinates[1].y;
        
        right[2].x = image2Coordinates[2].x;
		right[2].y = image2Coordinates[2].y;
        
        right[3].x = image2Coordinates[3].x;
		right[3].y = image2Coordinates[3].y;
        
        IplImage* image_left = [Stitcher createImageWithSize:blended_size depth:depth channels:1];
        
        if (image_left) {
            
            cvZero(image_left);
            
            IplImage* image_right = [Stitcher createImageWithSize:blended_size depth:depth channels:1];
            
            if (image_right) {
                
                cvZero(image_right);
                
                int num_vertices = 4;
                
                cvFillPoly(image_right, &right, &num_vertices, 1, cvScalar(125));
                
                cvFillPoly(image_left, &left, &num_vertices, 1, cvScalar(125));
                
                cvAddWeighted(image_right, 1, image_left, 1, 0, mask);
                
                cvThreshold(mask, mask, 126, 256, 0);
                
                [Stitcher releaseImage:&image_right];
            }
            
            [Stitcher releaseImage:&image_left];
            
        }
	}
	
	return mask;
}

- (IplImage*)warpMask:(IplImage*)mask with:(CvMat*)M
{
	if (!mask || s_should_abort) {
		return nil;
	}
	
	IplImage* warped_mask = [Stitcher createImageWithSize:blended_size depth:8 channels:1];
	
	if (warped_mask) {
		
		cvSet(warped_mask,cvScalarAll(0),0);
		
		cvWarpPerspective(mask, warped_mask, M, self.interpolationMethodWarp+CV_WARP_FILL_OUTLIERS, cvScalarAll(0));
		
	}
	
	return warped_mask;
}

- (IplImage*)addImage:(IplImage*)left_image to:(IplImage*)right_image
{
	if (!left_image || !right_image || s_should_abort) {
		return nil;
	}
	
	NSLog(@"Adding input images.");
	
	IplImage* blended_image = [Stitcher createImageWithSize:blended_size depth:depth channels:channels]; 
	
	if (blended_image) {
		cvSet(blended_image,cvScalarAll(0),0);
		cvAdd(left_image, right_image, blended_image);
	}
	
	NSLog(@"Added!");
	
	return blended_image;
}

- (IplImage*)stitchImageRight:(IplImage *)in_imageRight toImageLeft:(IplImage *)in_imageLeft
{
    IplImage* blended_image = nil;
    
    @autoreleasepool {
        if (!in_imageRight || !in_imageLeft || s_should_abort) {
            return nil;
        }
        
        self.progress += 1;
        [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
        
        depth = in_imageLeft->depth;
        channels = in_imageLeft->nChannels;
        
        double h[9];
        CvMat H = cvMat(3, 3, CV_32F, h);
        
        [self makeHomographyFor:in_imageRight toImage:in_imageLeft homography:&H];
        
        self.progress += 1;
        [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
        
        // warp the shape of the right image
        CvPoint2D32f right_coordinates[4];
        CvPoint2D32f left_coordinates[4];
        
        [self warpImageCoordinates:in_imageRight into:right_coordinates withPerspectiveTransform:&H];
        
        int y_top = MIN(right_coordinates[0].y, right_coordinates[1].y);
        int y_bottom = MAX(right_coordinates[3].y, right_coordinates[2].y);
        
        // create T for translation
        double t[9];
        CvMat T = cvMat(3, 3, CV_32F, t);
        cvSetIdentity(&T);
        
        if (self.crop) {
            y_top = 0;
            blended_width = MIN(right_coordinates[1].x, right_coordinates[2].x);
            blended_height = in_imageLeft->height;
            blended_size = cvSize(blended_width, blended_height);
        }
        else {
            blended_width = MAX(right_coordinates[1].x, right_coordinates[2].x);
            blended_height = y_bottom-y_top;
            blended_size = cvSize(blended_width, blended_height);
            
            [self makeTranslationTransform:&T translation_x:0 translation_y:-y_top];
        }
        
        // top left
        left_coordinates[0].x = 0;
        left_coordinates[0].y = -y_top;
        
        // top right
        left_coordinates[1].x = in_imageLeft->width;
        left_coordinates[1].y = -y_top;
        
        // bottom right
        left_coordinates[2].x = in_imageLeft->width;
        left_coordinates[2].y = blended_height-y_top;
        
        // bottom left
        left_coordinates[3].x = 0;
        left_coordinates[3].y = blended_height-y_top;
        
        
        // top left
        right_coordinates[0].y -= y_top;
        
        // top right
        right_coordinates[1].y -= y_top;
        
        // bottom right
        right_coordinates[2].y -= y_top;
        
        // bottom left
        right_coordinates[3].y -= y_top;
        
        // make a mask using the left and warped right coordinates
        IplImage* mask = [self makeMaskWithCoordinates:left_coordinates andCoordinates:right_coordinates];
        
        if (mask) {
            
            self.progress += 1;
            [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
            
            [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Preparing blend %f", self.progressPercent]];
            NSLog(@"Preparing blend.");
            
            double th[9];
            CvMat T_H = cvMat(3, 3, CV_32F, th);
            cvMatMul(&T, &H, &T_H);
            
            IplImage* right_image = [self warpImage:in_imageRight with:&T_H];
            
            self.progress += 1;
            [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
            [Stitcher releaseImage:&in_imageRight];
            
            if (right_image) {
                
                IplImage* left_image = [self warpImage:in_imageLeft with:&T];
                
                self.progress += 1;
                [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
                [Stitcher releaseImage:&in_imageLeft];
                
                if (left_image) {
                    
                    if (self.blend) {
                        blended_image = [self blend:right_image with:left_image usingMask:mask];                    }
                    else
                        blended_image = [self addImage:left_image to:right_image];
                    
                    self.progress += 1;
                    [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
                    
                    [Stitcher releaseImage:&left_image];
                }
                
                [Stitcher releaseImage:&right_image];
            }
            
            [Stitcher releaseImage:&mask];
        }
        
        
        [Stitcher releaseImage:&in_imageRight];
        [Stitcher releaseImage:&in_imageLeft];
        
        if (blended_image == nil) {
            if (s_should_abort == false) {
                if (self.intermediateResult) {
                    blended_image = [self.intermediateResult IPLImage];
                }
                else {
                    blended_image = [Stitcher createImageWithSize:blended_size depth:depth channels:channels];
                    cvSet(blended_image,cvScalarAll(0),0);
                }
            }
        }
        
        if (blended_image) {
            [self sendDelegateIntermediateStitchImage:blended_image];
        }
        
        self.progress += 1;
        [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:(self.progressPercent)]];
    }
		
	[self freeMemory:@""];
	
	return blended_image;
}

- (IplImage*)stitchImages:(NSMutableArray*)images error:(NSError**)error
{
    IplImage* blended_image = nil;
    
	[self freeMemory:@" -------------> (start) "];
	   
    @autoreleasepool {
        if ([images count] < 2) {
            return nil;
        }
        
        self.progress = 0;
        
        [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Stitching %d images", [images count]]];
        NSLog(@"Stitching %d images", (int)[images count]);
        
        for (int i = 0; i < [images count]; i++) {
            [self.delegate stitcher:self didUpdate:[images objectAtIndex:i]];
            NSLog(@"%@", [images objectAtIndex:i]);
        }
		
        [self.delegate stitcher:self didUpdateWithProgress:[NSNumber numberWithFloat:self.progress]];
        
        IplImage* firstImage = [[images objectAtIndex:0] IPLImageByScaling:self.inputImageScaling];
        
        if (!firstImage) {
            return nil;
        }
        
        [self sendDelegateIntermediateStitchImage:firstImage];
        
        input_image_width = firstImage->width;
        input_image_height = firstImage->height;
        
        [Stitcher releaseImage:&firstImage];
        
        marginSize = input_image_width*self.marginPercent;
        
        [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Input image width: %d", input_image_width]];
        NSLog(@"Input image width: %d", input_image_width);
        
        [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Input image height: %d", input_image_height]];
        NSLog(@"Input image height: %d", input_image_height);
        
        [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Margin size: %d", marginSize]];
        NSLog(@"Margin size: %d", marginSize);
        
        try {
            
            blended_image = [self stitchImageRight:[[images objectAtIndex:1] IPLImageByScaling:self.inputImageScaling] toImageLeft:[[images objectAtIndex:0] IPLImageByScaling:self.inputImageScaling]];
            
    
            if (self.crop && blended_image) {
                IplImage* cropped = [self create_cropped_image_top_bottom:blended_image inset:5];
                if (cropped) {
                    [Stitcher releaseImage:&blended_image];
                    blended_image = cropped;
                }
            }
            
            if (blended_image) {
                [self.delegate stitcher:self didFinishStitch:[UIImage imageWithIPLImage:blended_image]];
            }
            else {
                // return some other default image?
                if (self.intermediateResult) {
                    [self.delegate stitcher:self didFinishStitch:self.intermediateResult];
                }
            }
            
        } catch (std::exception& e) {
            
            NSLog(@"%s", e.what());
            
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:[NSString stringWithFormat:@"%s",e.what()] forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"stitcher" code:963 userInfo:details];
            
            [self.delegate stitcher:self didFinishStitch:self.intermediateResult];
        }
        
        
        [self.delegate stitcher:self didUpdate:@"Stitching completed."];
        NSLog(@"Stitching completed.");
        
        [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Images allocated: %d", (int)s_nbrImagesCreated]];
        NSLog(@"Images allocated: %d", (int)s_nbrImagesCreated);
        
        [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Images released: %d", (int)s_nbrImagesReleased]];
        NSLog(@"Images released: %d", (int)s_nbrImagesReleased);
        
        [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Progress maximum: %d", (int)self.progress]];
        NSLog(@"Progress maximum: %d", (int)self.progress);
        
        [self.delegate stitcher:self didUpdate:[NSString stringWithFormat:@"Progress: %f", self.progressPercent]];
        NSLog(@"Progress: %f", self.progressPercent);
    }
	
	[self freeMemory:@" -------------> (finish) "];
	
	return blended_image;
}

- (void)beginStitchingImages:(NSMutableArray*)images error:(NSError**)error
{
	IplImage* result = [self stitchImages:images error:error];
	
	if (result) {
		[Stitcher releaseImage:&result];
	}
}

@end
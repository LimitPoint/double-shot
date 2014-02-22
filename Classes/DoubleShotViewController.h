//  DoubleShotViewController.h
//  Double Shot
//
//  Created by Joe Pagliaro.
//  Copyright 2014 Limit Point LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Stitcher.h"

@interface DoubleShotViewController : UIViewController<StitcherDelegate>
{
    int seconds;
    NSTimer *secondsTimer;
    
    BOOL fastStitch;
    NSInteger memoryWarningCount;
    
    
}

@property (nonatomic, retain) IBOutlet UITextView *textView;
@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) Stitcher *stitcher;
@property (nonatomic, retain) UIImage* joined_uiimage;


@property (nonatomic, retain) IBOutlet UILabel *secondsLabel;

// Options, set in "stitch" method of the Stitcher
@property (nonatomic, retain) IBOutlet UISlider *inputImageScalingSlider;
@property (nonatomic, retain) IBOutlet UISlider *blendWidthScalingSlider;
@property (nonatomic, retain) IBOutlet UISlider *matchingMarginSizeSlider;
@property (nonatomic, retain) IBOutlet UISlider *homographyScalingSlider;

@property (nonatomic, retain) IBOutlet UISwitch *cropSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *blendSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *betterInterpolationSwitch;

@property (nonatomic, retain) IBOutlet UILabel *inputImageScalingLabel;
@property (nonatomic, retain) IBOutlet UILabel *blendWidthScalingLabel;
@property (nonatomic, retain) IBOutlet UILabel *matchingMarginSizeLabel;
@property (nonatomic, retain) IBOutlet UILabel *homographyScalingLabel;

@property (nonatomic, retain) IBOutlet UIButton *stitchButton;
@property (nonatomic, retain) IBOutlet UIButton *fastStitchButton;
@property (nonatomic, retain) IBOutlet UIButton *saveButton;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityView;

- (IBAction)sliderChanged:(id)sender;
- (IBAction)stitchButtonPressed:(id)sender;
- (IBAction)fastStitchButtonPressed:(id)sender;
- (IBAction)resetOptionsButtonPressed:(id)sender;
- (IBAction)saveImage:(id)sender;
- (void)saveOptions;
@end

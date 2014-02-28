//  DoubleShotViewController.h
//  Double Shot
//
//  
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Stitcher.h"

@interface DoubleShotViewController : UIViewController<StitcherDelegate, UIAlertViewDelegate, UIPickerViewDataSource,UIPickerViewDelegate>
{
    int seconds;
    NSTimer *secondsTimer;
    
    BOOL fastStitch;
    NSInteger memoryWarningCount;
    
    NSMutableArray *imageNames;
}

@property (nonatomic, retain) IBOutlet UITextView *textView;
@property (nonatomic, retain) IBOutlet UIScrollView *scrollView;
@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) Stitcher *stitcher;
@property (nonatomic, retain) UIImage* joined_uiimage;


@property (nonatomic, retain) IBOutlet UILabel *secondsLabel;

// Options, set in "stitch" method of the Stitcher
@property (nonatomic, retain) IBOutlet UISlider *inputImageScalingSlider;
@property (nonatomic, retain) IBOutlet UISlider *blendWidthScalingSlider;
@property (nonatomic, retain) IBOutlet UISlider *matchingMarginSizeSlider;
@property (nonatomic, retain) IBOutlet UISlider *homographyScalingSlider;
@property (nonatomic, retain) IBOutlet UISlider *lastMinSquaredDistancePercentSlider;
@property (nonatomic, retain) IBOutlet UISlider *keyMatchesPercentSlider;

@property (nonatomic, retain) IBOutlet UISwitch *cropSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *blendSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *equalizeSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *betterInterpolationSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *highHessianThresholdSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *extendedDescriptorsSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *lastMinSquaredDistancePercentSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *useRANSACSwitch;

@property (nonatomic, retain) IBOutlet UILabel *inputImageScalingLabel;
@property (nonatomic, retain) IBOutlet UILabel *blendWidthScalingLabel;
@property (nonatomic, retain) IBOutlet UILabel *matchingMarginSizeLabel;
@property (nonatomic, retain) IBOutlet UILabel *homographyScalingLabel;
@property (nonatomic, retain) IBOutlet UILabel *lastMinSquaredDistancePercentLabel;
@property (nonatomic, retain) IBOutlet UILabel *keyMatchesPercentLabel;

@property (nonatomic, retain) IBOutlet UIButton *stitchButton;
@property (nonatomic, retain) IBOutlet UIButton *fastStitchButton;
@property (nonatomic, retain) IBOutlet UIButton *cancelButton;
@property (nonatomic, retain) IBOutlet UIButton *saveButton;
@property (nonatomic, retain) IBOutlet UIButton *expandButton;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityView;

@property (nonatomic, retain) IBOutlet UIButton *customButton;
@property (nonatomic, retain) IBOutlet UIView * selectImageView;
@property (nonatomic, retain) IBOutlet UIPickerView * selectImagePicker;


- (IBAction)sliderChanged:(id)sender;
- (IBAction)stitchButtonPressed:(id)sender;
- (IBAction)fastStitchButtonPressed:(id)sender;
- (IBAction)resetOptionsButtonPressed:(id)sender;
- (IBAction)saveImage:(id)sender;
- (void)saveOptions;
@end

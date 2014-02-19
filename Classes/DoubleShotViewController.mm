//  DoubleShotViewController.mm
//  Double Shot
//
//  Created by Joe Pagliaro.
//  Copyright 2014 Limit Point LLC. All rights reserved.
//

#import "UIImage+OpenCV.h"
#import "DoubleShotViewController.h"

bool done = false;

@interface DoubleShotViewController ()
@end

@implementation DoubleShotViewController

// no @synthesize necessary with LLVM Compiler 4.0+
// See http://useyourloaf.com/blog/2012/08/01/property-synthesis-with-xcode-4-dot-4.html


- (void)stitcher:(Stitcher*)stitcher didFinishStitch:(UIImage*)image
{
	[self performSelectorOnMainThread:@selector(displayImage:) withObject:image waitUntilDone:NO];
    
    [secondsTimer invalidate];
}

- (void)stitcher:(Stitcher*)stitcher didUpdateWithProgress:(NSNumber*)progressPercent
{
	[self performSelectorOnMainThread:@selector(updateTextWithString:) withObject:[NSString stringWithFormat:@"Progress = %f", [progressPercent floatValue]] waitUntilDone:NO];
}

- (void)stitcher:(Stitcher*)stitcher didUpdate:(NSString *)update
{
    
    [self performSelectorOnMainThread:@selector(updateTextWithString:) withObject:update waitUntilDone:NO];
    
}
     
- (void)updateTextWithString:(NSString*)string
{
    
    self.textView.text = [self.textView.text stringByAppendingFormat:@"%@ \n", string];
    
    [self.textView scrollRangeToVisible:NSMakeRange([self.textView.text length], 0)];
    [self.textView setScrollEnabled:NO];
    [self.textView setScrollEnabled:YES];
    
}

- (void)stitcher:(Stitcher*)stitcher didFinishIntermediateStitchWithImage:(UIImage*)image
{
    
    [self performSelectorOnMainThread:@selector(displayImage:) withObject:image waitUntilDone:NO];
    
}

-(void)displayImage:(UIImage*)image
{    
	self.imageView.image = image;
}

-(void)displayActivityViewController:(UIActivityViewController*)activityViewController
{
    [self presentViewController:activityViewController animated:YES completion:^{}];
}

- (void)saveOptions
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.inputImageScalingSlider.value] forKey:@"Input Image Scaling"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.blendWidthScalingSlider.value] forKey:@"Blend Width Scaling"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.matchingMarginSizeSlider.value] forKey:@"Matching Margin Size"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.homographyScalingSlider.value] forKey:@"Homography Scaling"];
    
    BOOL value;
    
    value = self.cropSwitch.on;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:value] forKey:@"Crop"];
    
    value = self.betterInterpolationSwitch.on;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:value] forKey:@"Better Interpolation"];

}

- (void)restoreOptions
{
    id preference;
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Input Image Scaling"];
    if (preference) {
        self.inputImageScalingSlider.value = [preference floatValue];
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Blend Width Scaling"];
    if (preference) {
        self.blendWidthScalingSlider.value = [preference floatValue];
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Matching Margin Size"];
    if (preference) {
        self.matchingMarginSizeSlider.value = [preference floatValue];
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Homography Scaling"];
    if (preference) {
        self.homographyScalingSlider.value = [preference floatValue];
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Crop"];
    if (preference) {
        self.cropSwitch.on = [preference boolValue];
    }

    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Better Interpolation"];
    if (preference) {
        self.betterInterpolationSwitch.on = [preference boolValue];
    }
    
    [self sliderChanged:self];
}

- (IBAction)sliderChanged:(id)sender
{
	self.inputImageScalingLabel.text = [NSString stringWithFormat:@"%.0f", self.inputImageScalingSlider.value];
	self.blendWidthScalingLabel.text = [NSString stringWithFormat:@"%.0f", self.blendWidthScalingSlider.value];
    
    self.matchingMarginSizeLabel.text = [NSString stringWithFormat:@"%.0f", self.matchingMarginSizeSlider.value];
    self.homographyScalingLabel.text = [NSString stringWithFormat:@"%.0f", self.homographyScalingSlider.value];
    
    [self saveOptions];
}

- (void)setSecondsLabel
{
    self.secondsLabel.text= [NSString stringWithFormat:@"%d", seconds++];
}

- (IBAction)stitchButtonPressed:(id)sender
{
    memoryWarningCount = 0;
    
    fastStitch = FALSE;
    
    [self saveOptions];
    
    self.stitchButton.enabled = false;
    self.fastStitchButton.enabled = false;
    
    self.secondsLabel.text = @"0";
    
    [self.activityView startAnimating];
    
    seconds = 0;
    secondsTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(setSecondsLabel) userInfo:nil repeats:YES];
    
    [self performSelectorInBackground:@selector(stitch) withObject:nil];
}

- (IBAction)fastStitchButtonPressed:(id)sender
{
    memoryWarningCount = 0;
    
    fastStitch = TRUE;
    
    [self saveOptions];
    
    self.stitchButton.enabled = false;
    self.fastStitchButton.enabled = false;
    
    self.secondsLabel.text = @"0";
    
    [self.activityView startAnimating];
    
    seconds = 0;
    secondsTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(setSecondsLabel) userInfo:nil repeats:YES];
    
    [self performSelectorInBackground:@selector(stitch) withObject:nil];
}

- (IBAction)resetOptionsButtonPressed:(id)sender
{
    self.inputImageScalingSlider.value = 100;
    self.blendWidthScalingSlider.value = 33;
    self.matchingMarginSizeSlider.value = 33;
    self.homographyScalingSlider.value = 100;
    
    self.cropSwitch.on = YES;
    self.betterInterpolationSwitch.on = YES;
    
    [self sliderChanged:self];
}

- (void)stitch
{
	NSLog(@"Started!");
	   
    @autoreleasepool {
        
        self.stitcher = [[Stitcher alloc] init];
        self.stitcher.delegate = self;
        
        if (fastStitch) {
            self.stitcher.makeHomography = NO;
        }
        
        // override default values
        self.stitcher.marginPercent = self.matchingMarginSizeSlider.value/100.0;  // default 0.33
        self.stitcher.homographyScaling = self.homographyScalingSlider.value/100.0; // default 1.0, i.e. none
        
        self.stitcher.crop = self.cropSwitch.on;  // default ON
        
        if (self.betterInterpolationSwitch.on == YES) {
            self.stitcher.interpolationMethodWarp = CV_INTER_CUBIC;  // default "better"
        }
        else {
            self.stitcher.interpolationMethodWarp = CV_INTER_LINEAR;
        }
        
        if (self.inputImageScalingSlider.value == 100) {
            self.stitcher.inputImageScaling = 0;  // default, none
        }
        else {
            self.stitcher.inputImageScaling = self.inputImageScalingSlider.value/100.0;
        }
        
        if (fastStitch) {
            self.stitcher.homographyScaling = 0.5;
        }
        
        self.stitcher.blendWidthScaling = self.blendWidthScalingSlider.value/100.0; // default 0.33
        
        NSError* error;
        
        NSMutableArray* images = [NSMutableArray arrayWithObjects:@"left_screen.jpg", @"right_screen.jpg", nil];
        
        IplImage* joined_image = [self.stitcher stitchImages:images error:&error];
        
        if (joined_image) {
            
            [self displayImage:[UIImage imageWithIPLImage:joined_image]];
            
            UIImage* joined_uiimage = [UIImage imageWithIPLImage:joined_image];
            
            [self stitcher:self.stitcher didUpdate:@"Releasing result."];
            [Stitcher releaseImage:&joined_image];
            
            if (joined_uiimage) {
                
                [self stitcher:self.stitcher didUpdate:@"Saving result to camera roll."];
                
                UIImageWriteToSavedPhotosAlbum(joined_uiimage, nil, nil, nil);
                
                NSData* imageData =  UIImagePNGRepresentation(joined_uiimage);
                UIImage* pngImage = [UIImage imageWithData:imageData];
                
                UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:pngImage] applicationActivities:nil];
                
                /*
                 
                 Built-in Activity Types:
                 
                 https://developer.apple.com/library/ios/documentation/uikit/reference/UIActivity_Class/Reference/Reference.html#//apple_ref/doc/uid/TP40011974-CH1-SW13
                 
                 */
                [activityViewController setCompletionHandler:^(NSString *activityType, BOOL completed) {
                    
                    NSLog(@"completed dialog - activity: %@ - finished flag: %d", activityType, completed);
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        UIAlertView *alert;
                        
                        /*
                         UIKIT_EXTERN NSString *const UIActivityTypePostToFacebook     NS_AVAILABLE_IOS(6_0);
                         UIKIT_EXTERN NSString *const UIActivityTypePostToTwitter      NS_AVAILABLE_IOS(6_0);
                         UIKIT_EXTERN NSString *const UIActivityTypePostToWeibo        NS_AVAILABLE_IOS(6_0);    // SinaWeibo
                         UIKIT_EXTERN NSString *const UIActivityTypeMessage            NS_AVAILABLE_IOS(6_0);
                         UIKIT_EXTERN NSString *const UIActivityTypeMail               NS_AVAILABLE_IOS(6_0);
                         UIKIT_EXTERN NSString *const UIActivityTypePrint              NS_AVAILABLE_IOS(6_0);
                         UIKIT_EXTERN NSString *const UIActivityTypeCopyToPasteboard   NS_AVAILABLE_IOS(6_0);
                         UIKIT_EXTERN NSString *const UIActivityTypeAssignToContact    NS_AVAILABLE_IOS(6_0);
                         UIKIT_EXTERN NSString *const UIActivityTypeSaveToCameraRoll   NS_AVAILABLE_IOS(6_0);
                         UIKIT_EXTERN NSString *const UIActivityTypeAddToReadingList   NS_AVAILABLE_IOS(7_0);
                         UIKIT_EXTERN NSString *const UIActivityTypePostToFlickr       NS_AVAILABLE_IOS(7_0);
                         UIKIT_EXTERN NSString *const UIActivityTypePostToVimeo        NS_AVAILABLE_IOS(7_0);
                         UIKIT_EXTERN NSString *const UIActivityTypePostToTencentWeibo NS_AVAILABLE_IOS(7_0);
                         UIKIT_EXTERN NSString *const UIActivityTypeAirDrop            NS_AVAILABLE_IOS(7_0);
                         */
                        
                        if ([activityType isEqualToString:UIActivityTypeMessage]) {
                            alert = [[UIAlertView alloc] initWithTitle:@"Message completed?" message:(completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        }
                        else if ([activityType isEqualToString:UIActivityTypeMail]) {
                            alert = [[UIAlertView alloc] initWithTitle:@"Mail completed?" message:(completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        }
                        else if ([activityType isEqualToString:UIActivityTypePrint]) {
                            alert = [[UIAlertView alloc] initWithTitle:@"Print completed?" message:(completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        }
                        else if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                            alert = [[UIAlertView alloc] initWithTitle:@"Copy completed?" message:(completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        }
                        else if ([activityType isEqualToString:UIActivityTypeAssignToContact]) {
                            alert = [[UIAlertView alloc] initWithTitle:@"Assign to contact completed?" message:(completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        }
                        else if ([activityType isEqualToString:UIActivityTypeSaveToCameraRoll]) {
                            alert = [[UIAlertView alloc] initWithTitle:@"Save completed?" message:(completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        }
                        else if ([activityType isEqualToString:UIActivityTypeAirDrop]) {
                            alert = [[UIAlertView alloc] initWithTitle:@"Airdrop completed?" message:(completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        }
                        else {
                            alert = [[UIAlertView alloc] initWithTitle:@"Cancelled?" message:(!completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        }
                        
                        
                        
                        [alert show];
                    });
                }];
                
                // display the share dialog
                
                // See https://www.mikeash.com/pyblog/friday-qa-2009-08-28-intro-to-grand-central-dispatch-part-i-basics-and-dispatch-queues.html
                
                
                dispatch_async(dispatch_get_main_queue(), ^{[self presentViewController:activityViewController animated:YES completion:nil]; });
                
            }
        }
        
        self.stitchButton.enabled = true;
        self.fastStitchButton.enabled = true;
        
        [self.activityView stopAnimating];
    }
			
	NSLog(@"Finished!");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

-(void)viewWillAppear:(BOOL)animated
{
    [self restoreOptions];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.imageView = nil;

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    memoryWarningCount += 1;
    
    if (memoryWarningCount >= 2) {
        
		if (memoryWarningCount == 3) {
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Memory is getting low."
                                                            message:@"If problem persists try input image scaling option."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            
            [alert show];
		}
    }
}

@end

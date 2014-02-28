//  DoubleShotViewController.mm
//  Double Shot
//
//  
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//

#import "UIImage+OpenCV.h"
#import "DoubleShotViewController.h"

bool done = false;

@interface DoubleShotViewController ()
@end

@implementation DoubleShotViewController

- (void)updateTexViewtWithString:(NSString*)string
{
    self.textView.text = [self.textView.text stringByAppendingFormat:@"%@ \n", string];
    
    [self.textView scrollRangeToVisible:NSMakeRange([self.textView.text length], 0)];
    [self.textView setScrollEnabled:NO];
    [self.textView setScrollEnabled:YES];
    
     self.progressView.progress = self.stitcher.progressPercent;
}

// Stitcher Delegate

- (void)stitcher:(Stitcher*)stitcher didFinishStitch:(UIImage*)image
{
	[self performSelectorOnMainThread:@selector(stitchFinished:) withObject:image waitUntilDone:NO];
    
}

- (void)stitcher:(Stitcher*)stitcher didUpdateWithProgress:(NSNumber*)progressPercent
{
	[self performSelectorOnMainThread:@selector(updateTexViewtWithString:) withObject:[NSString stringWithFormat:@"Progress = %f", [progressPercent floatValue]] waitUntilDone:NO];
}

- (void)stitcher:(Stitcher*)stitcher didUpdate:(NSString *)update
{
    
    [self performSelectorOnMainThread:@selector(updateTexViewtWithString:) withObject:update waitUntilDone:NO];
    
}

- (void)stitcher:(Stitcher*)stitcher didFinishIntermediateStitchWithImage:(UIImage*)image
{
    
    [self performSelectorOnMainThread:@selector(displayImage:) withObject:image waitUntilDone:NO];
    
}

-(void)stitchFinished:(UIImage*)image
{
    self.joined_uiimage = image;
    
    if (self.joined_uiimage) {
        
        [self displayImage:image];
        
        self.saveButton.enabled = YES;
        
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:self.joined_uiimage] applicationActivities:nil];
        
        /*
         
         Built-in Activity Types:
         
         https://developer.apple.com/library/ios/documentation/uikit/reference/UIActivity_Class/Reference/Reference.html#//apple_ref/doc/uid/TP40011974-CH1-SW13
         
         */
        [activityViewController setCompletionHandler:^(NSString *activityType, BOOL completed) {
            
            NSLog(@"completed dialog - activity: %@ - finished flag: %d", activityType, completed);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                UIAlertView *alert;
                
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
                    alert = [[UIAlertView alloc] initWithTitle:@"Cancelled share?" message:(!completed ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                }
                
                [alert show];
                
            });
        }];
        
        // display the share dialog
        
        // See https://www.mikeash.com/pyblog/friday-qa-2009-08-28-intro-to-grand-central-dispatch-part-i-basics-and-dispatch-queues.html
        
        
        dispatch_async(dispatch_get_main_queue(), ^{[self presentViewController:activityViewController animated:YES completion:nil]; });
        
    }
    else {
        self.saveButton.enabled = NO;
    }
    
    
    self.stitchButton.enabled = YES;
    self.fastStitchButton.enabled = YES;
    self.cancelButton.enabled = NO;
    
    [self.activityView stopAnimating];
    
    NSLog(@"Finished!");
    
    [secondsTimer invalidate];
}

-(void)displayImage:(UIImage*)image
{    
	self.imageView.image = image;
}

- (void)saveOptions
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.inputImageScalingSlider.value] forKey:@"Input Image Scaling"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.blendWidthScalingSlider.value] forKey:@"Blend Width Scaling"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.matchingMarginSizeSlider.value] forKey:@"Matching Margin Size"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.homographyScalingSlider.value] forKey:@"Homography Scaling"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.lastMinSquaredDistancePercentSlider.value] forKey:@"Last Min Squared Distance Percent"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.keyMatchesPercentSlider.value] forKey:@"Key Matches Percent"];
    
    BOOL value;
    
    value = self.cropSwitch.on;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"Crop"];
    
    value = self.blendSwitch.on;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"Blend"];
    
    value = self.equalizeSwitch.on;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"Equalize"];
    
    value = self.betterInterpolationSwitch.on;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"Better Interpolation"];
    
    value = self.highHessianThresholdSwitch.on;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"High Hessian Threshold"];
    
    value = self.extendedDescriptorsSwitch.on;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"Extended Descriptors"];
    
    value = self.lastMinSquaredDistancePercentSwitch.on;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"Use Last Min Squared Distance Percent"];
    
    value = self.useRANSACSwitch.on;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"Use RANSAC"];

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
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Min Squared Distance Percent"];
    if (preference) {
        self.lastMinSquaredDistancePercentSlider.value = [preference floatValue];
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Key Matches Percent"];
    if (preference) {
        self.keyMatchesPercentSlider.value = [preference floatValue];
    }
    
    BOOL value;
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Crop"];
    if (preference) {
        value =[preference boolValue];
        self.cropSwitch.on = value;
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Blend"];
    if (preference) {
        value =[preference boolValue];
        self.blendSwitch.on = value;
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Equalize"];
    if (preference) {
        value =[preference boolValue];
        self.equalizeSwitch.on = value;
    }

    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Better Interpolation"];
    if (preference) {
        value =[preference boolValue];
        self.betterInterpolationSwitch.on = value;
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"High Hessian Threshold"];
    if (preference) {
        value =[preference boolValue];
        self.highHessianThresholdSwitch.on = value;
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Extended Descriptors"];
    if (preference) {
        value =[preference boolValue];
        self.extendedDescriptorsSwitch.on = value;
    }
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Use Last Min Squared Distance Percent"];
    if (preference) {
        value =[preference boolValue];
        self.lastMinSquaredDistancePercentSwitch.on = value;
    }
    
    self.lastMinSquaredDistancePercentSlider.enabled = self.lastMinSquaredDistancePercentSwitch.on;
    
    preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"Use RANSAC"];
    if (preference) {
        value =[preference boolValue];
        self.useRANSACSwitch.on = value;
    }
    
    [self sliderChanged:self];
}

- (IBAction)sliderChanged:(id)sender
{
	self.inputImageScalingLabel.text = [NSString stringWithFormat:@"%.0f", self.inputImageScalingSlider.value];
	self.blendWidthScalingLabel.text = [NSString stringWithFormat:@"%.0f", self.blendWidthScalingSlider.value];
    self.matchingMarginSizeLabel.text = [NSString stringWithFormat:@"%.0f", self.matchingMarginSizeSlider.value];
    self.homographyScalingLabel.text = [NSString stringWithFormat:@"%.0f", self.homographyScalingSlider.value];
    self.lastMinSquaredDistancePercentLabel.text = [NSString stringWithFormat:@"%.0f", self.lastMinSquaredDistancePercentSlider.value];
    self.keyMatchesPercentLabel.text = [NSString stringWithFormat:@"%.0f", self.keyMatchesPercentSlider.value];
    
    self.lastMinSquaredDistancePercentSlider.enabled = self.lastMinSquaredDistancePercentSwitch.on;
    
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
    
    self.stitchButton.enabled = NO;
    self.fastStitchButton.enabled = NO;
    self.cancelButton.enabled = YES;
    
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
    
    self.stitchButton.enabled = NO;
    self.fastStitchButton.enabled = NO;
    self.cancelButton.enabled = YES;
    
    self.secondsLabel.text = @"0";
    
    [self.activityView startAnimating];
    
    seconds = 0;
    secondsTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(setSecondsLabel) userInfo:nil repeats:YES];
    
    [self performSelectorInBackground:@selector(stitch) withObject:nil];
}

- (IBAction)expandButtonPressed:(id)sender
{
    
    if ([_expandButton.titleLabel.text compare:@"+"] == NSOrderedSame) {
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options: UIViewAnimationCurveEaseInOut
                         animations:^{
                            CGRect frame = _imageView.frame;
                             frame.size.height += (_scrollView.frame.size.height + _textView.frame.size.height);
                             _scrollView.frame = frame;
                         }
                         completion:^(BOOL finished){
                             if(finished) {
                                 
                                 _expandButton.titleLabel.text = @"-";
                                 
                             }
                         }];
    }
    else {
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options: UIViewAnimationCurveEaseInOut
                         animations:^{
                             CGRect frame = _scrollView.frame;
                             
                             CGPoint point = _scrollView.frame.origin;
                             point.y += _imageView.frame.size.height;
                             frame.origin = point;
                             
                             CGSize size = _scrollView.frame.size;
                             size.height -= (_imageView.frame.size.height + _textView.frame.size.height);
                             frame.size = size;

                             _scrollView.frame = frame;
                             
                         }
                         completion:^(BOOL finished){
                             if(finished) {
                                
                                 _expandButton.titleLabel.text = @"+";
                                 
                             }
                         }];
    }
    
    
    
}

- (IBAction)resetOptionsButtonPressed:(id)sender
{
    UIAlertView *alert;
    
    alert = [[UIAlertView alloc] initWithTitle:@"Are you sure you want to reset options?" message:nil delegate:self cancelButtonTitle:@"Yes" otherButtonTitles:@"No", nil];
    
    alert.tag = 1;
    
    [alert show];
        
}

- (IBAction)saveImage:(id)sender
{
    [self stitcher:self.stitcher didUpdate:@"Saving result to camera roll."];
    
    UIImageWriteToSavedPhotosAlbum(self.joined_uiimage, nil, nil, nil);
}

- (IBAction)cancelStitch:(id)sender
{
    [Stitcher shouldAbort];
}

- (void)initStitchProperties
{
    if (fastStitch) {
        self.stitcher.makeHomography = NO;
    }
    
    // override default values
    self.stitcher.marginPercent = self.matchingMarginSizeSlider.value/100.0;  // default 0.33
    self.stitcher.homographyScaling = self.homographyScalingSlider.value/100.0; // default 1.0, i.e. none
    self.stitcher.lastMinSquaredDistancePercent = self.lastMinSquaredDistancePercentSlider.value/100.0; // default 1.0, i.e. none
    self.stitcher.keypointPercent = self.keyMatchesPercentSlider.value/100.0; // default 1.0, i.e. none
    
    self.stitcher.useLastMinSquaredDistancePercent = self.lastMinSquaredDistancePercentSwitch.on;
    
    
    self.stitcher.crop = self.cropSwitch.on;  // default ON
    self.stitcher.blend = self.blendSwitch.on;  // default ON
    self.stitcher.equalize = self.equalizeSwitch.on;  // default ON
    
    self.stitcher.highHessianThreshold = self.highHessianThresholdSwitch.on;  // default ON
    self.stitcher.extendedDescriptors = self.extendedDescriptorsSwitch.on;  // default OFF
    self.stitcher.useRANSAC = self.useRANSACSwitch.on;  // default ON
    
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
    
    self.stitcher.blendWidthScaling = self.blendWidthScalingSlider.value/100.0; // default 0.33
}

- (void)stitch
{
	NSLog(@"Started!");
	   
    @autoreleasepool {
        
        self.stitcher = [[Stitcher alloc] init];
        self.stitcher.delegate = self;
        
        [self initStitchProperties];
        
        NSError* error;
        
        //NSMutableArray* images = [NSMutableArray arrayWithObjects:@"left_amsterdam.jpg", @"right_amsterdam.jpg", nil];
        
        //NSMutableArray* images = [NSMutableArray arrayWithObjects:@"left_rice.jpg", @"right_rice.jpg", nil];
        
        //NSMutableArray* images = [NSMutableArray arrayWithObjects:@"left_machine_room.jpg", @"right_machine_room.jpg", nil];
        
        //NSMutableArray* images = [NSMutableArray arrayWithObjects:@"left_pizza.jpg", @"right_pizza.jpg", nil];
        
        //NSMutableArray* images = [NSMutableArray arrayWithObjects:@"left_umbrella_and_bench.jpg", @"right_umbrella_and_bench.jpg", nil];
        
        //NSMutableArray* images = [NSMutableArray arrayWithObjects:@"left_mural.jpg", @"right_mural.jpg", nil];
        
        NSMutableArray* images = [NSMutableArray arrayWithObjects:@"left_sophies_room.jpg", @"right_sophies_room.jpg", nil];
        
        [self.stitcher beginStitchingImages:images error:&error];
        
    }
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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ((alertView.tag == 1) && (buttonIndex == 0)) {
        
        self.inputImageScalingSlider.value = 100;
        self.blendWidthScalingSlider.value = 33;
        self.matchingMarginSizeSlider.value = 33;
        self.homographyScalingSlider.value = 50;
        self.lastMinSquaredDistancePercentSlider.value = 70;
        self.keyMatchesPercentSlider.value = 100;
        
        self.cropSwitch.on = YES;
        self.blendSwitch.on = YES;
        self.equalizeSwitch.on = YES;
        self.betterInterpolationSwitch.on = YES;
        self.highHessianThresholdSwitch.on = YES;
        self.extendedDescriptorsSwitch.on = NO;
        self.lastMinSquaredDistancePercentSwitch.on = YES;
        self.useRANSACSwitch.on = YES;
        
        [self sliderChanged:self];

        UIAlertView *alert;
        
        alert = [[UIAlertView alloc] initWithTitle:@"Options reset." message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
        alert.tag = 0;
        
        [alert show];
    }
}

@end

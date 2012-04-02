//
//  ViewController.m
//  NovocaineExamples
//
//  Created by Alex Wiltschko on 4/2/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    ringBuffer = new RingBuffer(32768, 2); 
    audioManager = [Novocaine audioManager];
    
    // Basic playthru example
    [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        float volume = 0.5;
        vDSP_vsmul(data, 1, &volume, data, 1, numFrames*numChannels);
        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
    }];
    
    
    [audioManager setOutputBlock:^(float *outData, UInt32 numFrames, UInt32 numChannels) {
        ringBuffer->FetchInterleavedData(outData, numFrames, numChannels);
    }];
    
    
    /*
     // Basic Output-only example
     // MAKE SOME NOOOOO OIIIISSSEEE
     [signalManager setOutputBlock:^(float *newdata, UInt32 numFrames, UInt32 thisNumChannels){
     for (int i = 0; i < numFrames * thisNumChannels; i++) {
     newdata[i] = INT16_MAX * (rand() % 100) / 100.0f / 2;
     }
     }];
     */
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

@end

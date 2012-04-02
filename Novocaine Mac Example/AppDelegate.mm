//
//  AppDelegate.m
//  NovocaineExamples Mac
//
//  Created by Alex Wiltschko on 4/2/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // ========================================
    // A simple delay that's hard to express without ring buffers
    
    ringBuffer = new RingBuffer(32768, 2); 
    audioManager = [Novocaine audioManager];
    
    
    [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
    }];
    
    
    
    int echoDelay = 11025;
    float *holdingBuffer = (float *)calloc(16384, sizeof(float));
    [audioManager setOutputBlock:^(float *outData, UInt32 numFrames, UInt32 numChannels) {
        
        // Grab the play-through audio
        ringBuffer->FetchInterleavedData(outData, numFrames, numChannels);
        float volume = 0.8;
        vDSP_vsmul(outData, 1, &volume, outData, 1, numFrames*numChannels);
        
        
        // Seek back, and grab some delayed audio
        ringBuffer->SeekReadHeadPosition(-echoDelay-numFrames);
        ringBuffer->FetchInterleavedData(holdingBuffer, numFrames, numChannels);
        ringBuffer->SeekReadHeadPosition(echoDelay);
        
        volume = 0.5;
        vDSP_vsmul(holdingBuffer, 1, &volume, holdingBuffer, 1, numFrames*numChannels);
        vDSP_vadd(holdingBuffer, 1, outData, 1, outData, 1, numFrames*numChannels);
    }];
    
}

@end

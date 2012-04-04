// Copyright (c) 2012 Alex Wiltschko
// 
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


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

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
    

    audioManager = [Novocaine audioManager];
//    ringBuffer = new RingBuffer(32768, 2); 
    

// A simple delay that's hard to express without ring buffers
// ========================================
//
//    [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
//        ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
//    }];
//    
//    int echoDelay = 11025;
//    float *holdingBuffer = (float *)calloc(16384, sizeof(float));
//    [audioManager setOutputBlock:^(float *outData, UInt32 numFrames, UInt32 numChannels) {
//        
//        // Grab the play-through audio
//        ringBuffer->FetchInterleavedData(outData, numFrames, numChannels);
//        float volume = 0.8;
//        vDSP_vsmul(outData, 1, &volume, outData, 1, numFrames*numChannels);
//        
//        
//        // Seek back, and grab some delayed audio
//        ringBuffer->SeekReadHeadPosition(-echoDelay-numFrames);
//        ringBuffer->FetchInterleavedData(holdingBuffer, numFrames, numChannels);
//        ringBuffer->SeekReadHeadPosition(echoDelay);
//        
//        volume = 0.5;
//        vDSP_vsmul(holdingBuffer, 1, &volume, holdingBuffer, 1, numFrames*numChannels);
//        vDSP_vadd(holdingBuffer, 1, outData, 1, outData, 1, numFrames*numChannels);
//    }];
//    
    
    // AUDIO FILE READING COOL!
    // ========================================    
    NSURL *inputFileURL = [[NSBundle mainBundle] URLForResource:@"TLC" withExtension:@"mp3"];        
    
    fileReader = [[AudioFileReader alloc] 
                  initWithAudioFileURL:inputFileURL 
                  samplingRate:audioManager.samplingRate
                  numChannels:audioManager.numOutputChannels];

    fileReader.currentTime = 5;    
    [fileReader play];
    
    
    __block int counter = 0;
    [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
     {
         [fileReader retrieveFreshAudio:data numFrames:numFrames numChannels:numChannels];
         counter++;
         if (counter % 80 == 0)
             NSLog(@"Time: %f", fileReader.currentTime);
         
     }];
    


    
    // AUDIO FILE WRITING YEAH!
    // ========================================    
//    NSArray *pathComponents = [NSArray arrayWithObjects:
//                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject], 
//                               @"My Recording.m4a", 
//                               nil];
//    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];
//
//    fileWriter = [[AudioFileWriter alloc] 
//                  initWithAudioFileURL:outputFileURL 
//                  samplingRate:audioManager.samplingRate 
//                  numChannels:audioManager.numInputChannels];
//    
//    
//    __block int counter = 0;
//    audioManager.inputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
//        [fileWriter writeNewAudio:data numFrames:numFrames numChannels:numChannels];
//        counter += 1;
//        if (counter > 10 * audioManager.samplingRate / numChannels) { // 10 seconds of recording
//            audioManager.inputBlock = nil;
//            [fileWriter release];
//        }
//    };

    
}

@end

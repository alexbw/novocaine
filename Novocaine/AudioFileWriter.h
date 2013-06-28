//
//  AudioFileWriter.h
//  Novocaine
//
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

#import <Foundation/Foundation.h>
#import "Novocaine.h"


@interface AudioFileWriter : NSObject

// ----- Read-write ------
@property (nonatomic, copy) NovocaineInputBlock writerBlock;

// ----- Read-only ------
@property (nonatomic, assign, getter=getDuration, readonly) float currentTime;
@property (nonatomic, assign, getter=getDuration, readonly) float duration;
@property (nonatomic, assign, readonly) float samplingRate;
@property (nonatomic, assign, readonly) UInt32 numChannels;
@property (nonatomic, assign, readonly) float latency;
@property (nonatomic, copy, readonly)   NSURL *audioFileURL;
@property (nonatomic, assign, readonly) BOOL recording;


- (id)initWithAudioFileURL:(NSURL *)urlToAudioFile samplingRate:(float)thisSamplingRate numChannels:(UInt32)thisNumChannels;

// You use this method to grab audio if you have your own callback.
// The buffer'll fill at the speed the audio is normally being played.
- (void)writeNewAudio:(float *)newData numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels;

- (void)record;
- (void)pause;


@end

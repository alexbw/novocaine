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
#import "RingBuffer.h"
#import "Novocaine.h"


@interface AudioFileReader : NSObject

// ----- Read-write ------

@property (nonatomic, assign, getter=getCurrentTime, setter=setCurrentTime:) float currentTime;
@property (nonatomic, copy) NovocaineInputBlock readerBlock;
@property (nonatomic, assign) float latency;

// ----- Read-only ------

@property (nonatomic, copy, readonly)   NSURL *audioFileURL;
@property (nonatomic, assign, readonly, getter=getDuration) float duration;
@property (nonatomic, assign, readonly) float samplingRate;
@property (nonatomic, assign, readonly) UInt32 numChannels;
@property (nonatomic, assign, readonly) BOOL playing;


- (id)initWithAudioFileURL:(NSURL *)urlToAudioFile samplingRate:(float)thisSamplingRate numChannels:(UInt32)thisNumChannels;

// You use this method to grab audio if you have your own callback.
// The buffer'll fill at the speed the audio is normally being played.

- (void)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels;

- (void)play;
- (void)pause;
- (void)stop;


@end

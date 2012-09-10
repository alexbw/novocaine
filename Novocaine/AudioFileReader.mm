//
//  AudioFileReader.m
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

#import "AudioFileReader.h"

@interface AudioFileReader ()
{
    RingBuffer *ringBuffer;
}

@property AudioStreamBasicDescription outputFormat;
@property ExtAudioFileRef inputFile;
@property UInt32 outputBufferSize;
@property float *outputBuffer;
@property float *holdingBuffer;
@property UInt32 numSamplesReadPerPacket;
@property UInt32 desiredPrebufferedSamples;
@property SInt64 currentFileTime;
@property dispatch_source_t callbackTimer;


- (void)bufferNewAudio;

@end



@implementation AudioFileReader

@synthesize outputFormat = _outputFormat;
@synthesize inputFile = _inputFile;
@synthesize outputBuffer = _outputBuffer;
@synthesize holdingBuffer = _holdingBuffer;
@synthesize outputBufferSize = _outputBufferSize;
@synthesize numSamplesReadPerPacket = _numSamplesReadPerPacket;
@synthesize desiredPrebufferedSamples = _desiredPrebufferedSamples;
@synthesize currentFileTime = _currentFileTime;
@synthesize callbackTimer = _callbackTimer;
@synthesize currentTime = _currentTime;
@synthesize duration = _duration;
@synthesize samplingRate = _samplingRate;
@synthesize latency = _latency;
@synthesize numChannels = _numChannels;
@synthesize audioFileURL = _audioFileURL;
@synthesize readerBlock = _readerBlock;
@synthesize playing = _playing;

- (void)dealloc
{
    // If the dispatch timer is active, close it off
    if (self.playing)
        [self pause];
    
    self.readerBlock = nil;
    
    // Close the ExtAudioFile
    ExtAudioFileDispose(self.inputFile);
    
    free(self.outputBuffer);
    free(self.holdingBuffer);
    
    delete ringBuffer;
    
    [super dealloc];
}


- (id)initWithAudioFileURL:(NSURL *)urlToAudioFile samplingRate:(float)thisSamplingRate numChannels:(UInt32)thisNumChannels
{
    self = [super init];
    if (self)
    {
        
        // Zero-out our timer, so we know we're not using our callback yet
        self.callbackTimer = nil;
        
        
        // Open a reference to the audio file
        self.audioFileURL = urlToAudioFile;
        CFURLRef audioFileRef = (CFURLRef)self.audioFileURL;
        CheckError(ExtAudioFileOpenURL(audioFileRef, &_inputFile), "Opening file URL (ExtAudioFileOpenURL)");

        
        // Set a few defaults and presets
        self.samplingRate = thisSamplingRate;
        self.numChannels = thisNumChannels;
        self.latency = .011609977; // 512 samples / ( 44100 samples / sec ) default
        
        
        // We're going to impose a format upon the input file
        // Single-channel float does the trick.
        _outputFormat.mSampleRate = self.samplingRate;
        _outputFormat.mFormatID = kAudioFormatLinearPCM;
        _outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
        _outputFormat.mBytesPerPacket = 4*self.numChannels;
        _outputFormat.mFramesPerPacket = 1;
        _outputFormat.mBytesPerFrame = 4*self.numChannels;
        _outputFormat.mChannelsPerFrame = self.numChannels;
        _outputFormat.mBitsPerChannel = 32;
        
        // Apply the format to our file
        ExtAudioFileSetProperty(_inputFile, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &_outputFormat);
        
        
        // Arbitrary buffer sizes that don't matter so much as long as they're "big enough"
        self.outputBufferSize = 65536;
        self.numSamplesReadPerPacket = 8192;
        self.desiredPrebufferedSamples = self.numSamplesReadPerPacket*2;
        self.outputBuffer = (float *)calloc(2*self.samplingRate, sizeof(float));
        self.holdingBuffer = (float *)calloc(2*self.samplingRate, sizeof(float));
        
        
        // Allocate a ring buffer (this is what's going to buffer our audio)
        ringBuffer = new RingBuffer(self.outputBufferSize, self.numChannels);
        
        
        // Fill up the buffers, so we're ready to play immediately
        [self bufferNewAudio];
        
    }
    return self;
}

- (void)clearBuffer
{
    ringBuffer->Clear();
}

- (void)bufferNewAudio
{
    
    if (ringBuffer->NumUnreadFrames() > self.desiredPrebufferedSamples)
        return;
    
    memset(self.outputBuffer, 0, sizeof(float)*self.desiredPrebufferedSamples);
    
    AudioBufferList incomingAudio;
    incomingAudio.mNumberBuffers = 1;
    incomingAudio.mBuffers[0].mNumberChannels = self.numChannels;
    incomingAudio.mBuffers[0].mDataByteSize = self.outputBufferSize;
    incomingAudio.mBuffers[0].mData = self.outputBuffer;
    
    // Figure out where we are in the file
    SInt64 frameOffset = 0;
    ExtAudioFileTell(self.inputFile, &frameOffset);
    self.currentFileTime = (float)frameOffset / self.samplingRate;

    // Read the audio
    UInt32 framesRead = self.numSamplesReadPerPacket;
    ExtAudioFileRead(self.inputFile, &framesRead, &incomingAudio);
    
    // Update where we are in the file
    ExtAudioFileTell(self.inputFile, &frameOffset);
    self.currentFileTime = (float)frameOffset / self.samplingRate;
    
    // Add the new audio to the ring buffer
    ringBuffer->AddNewInterleavedFloatData(self.outputBuffer, framesRead, self.numChannels);
    
    if ((self.currentFileTime - self.duration) < 0.01 && framesRead == 0) {
        // modified to allow for auto-stopping. //
        // Need to change your output block to check for [fileReader playing] and nuke your fileReader if it is   //
        // not playing and not paused, on the next frame. Otherwise, the sound clip's final buffer is not played. //
//        self.currentTime = 0.0f;
        [self stop];
        ringBuffer->Clear();
    }
    
    
}

- (float)getCurrentTime
{
    return self.currentFileTime - ringBuffer->NumUnreadFrames()/self.samplingRate;
}


- (void)setCurrentTime:(float)thisCurrentTime
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pause];
        ExtAudioFileSeek(self.inputFile, thisCurrentTime*self.samplingRate);
        
        [self clearBuffer];
        [self bufferNewAudio];
        
        [self play];
    });
}

- (float)getDuration
{
    // We're going to directly calculate the duration of the audio file (in seconds)
    SInt64 framesInThisFile;
    UInt32 propertySize = sizeof(framesInThisFile);
    ExtAudioFileGetProperty(self.inputFile, kExtAudioFileProperty_FileLengthFrames, &propertySize, &framesInThisFile);
    
    AudioStreamBasicDescription fileStreamFormat;
    propertySize = sizeof(AudioStreamBasicDescription);
    ExtAudioFileGetProperty(self.inputFile, kExtAudioFileProperty_FileDataFormat, &propertySize, &fileStreamFormat);
    
    return (float)framesInThisFile/(float)fileStreamFormat.mSampleRate;
    
}

- (void)configureReaderCallback
{
    
    if (!self.callbackTimer)
    {
        self.callbackTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        UInt32 numSamplesPerCallback = (UInt32)( self.latency * self.samplingRate );
        dispatch_source_set_timer(self.callbackTimer, dispatch_walltime(NULL, 0), self.latency*NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(self.callbackTimer, ^{
            
            if (self.playing) {
            
                if (self.readerBlock) {
                    // Suck some audio down from our ring buffer
                    [self retrieveFreshAudio:self.holdingBuffer numFrames:numSamplesPerCallback numChannels:self.numChannels];
                
                    // Call out with the audio that we've got.
                    self.readerBlock(self.holdingBuffer, numSamplesPerCallback, self.numChannels);
                }
                
                // Asynchronously fill up the buffer (if it needs filling)
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self bufferNewAudio];
                });
                
            }
            
         });
        
        dispatch_resume(self.callbackTimer);
    }
}


- (void)retrieveFreshAudio:(float *)buffer numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
    ringBuffer->FetchInterleavedData(buffer, thisNumFrames, thisNumChannels);
}


- (void)play;
{

    // Configure (or if necessary, create and start) the timer for retrieving audio
    if (!self.playing) {
        [self configureReaderCallback];
        self.playing = TRUE;
    }

}

- (void)pause
{
    // Pause the dispatch timer for retrieving the MP3 audio
    self.playing = FALSE;
}

- (void)stop
{
    // Release the dispatch timer because it holds a reference to this class instance
    [self pause];
    if (self.callbackTimer) {
        dispatch_release(self.callbackTimer);
    }
}


@end

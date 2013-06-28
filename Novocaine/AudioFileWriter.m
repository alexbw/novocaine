//
//  AudioFileWriter.m
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
#import "AudioFileWriter.h"
#import <pthread.h>

@interface AudioFileWriter()

// redeclare as readwrite in class continuation
@property (nonatomic, assign, getter=getDuration, readwrite) float currentTime;
@property (nonatomic, assign, getter=getDuration, readwrite) float duration;
@property (nonatomic, assign, readwrite) float samplingRate;
@property (nonatomic, assign, readwrite) UInt32 numChannels;
@property (nonatomic, assign, readwrite) float latency;
@property (nonatomic, copy, readwrite)   NSURL *audioFileURL;
@property (nonatomic, assign, readwrite) BOOL recording;

@property (nonatomic, assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic, assign) ExtAudioFileRef outputFile;
@property (nonatomic, assign) UInt32 outputBufferSize;
@property (nonatomic, assign) float *outputBuffer;
@property (nonatomic, assign) float *holdingBuffer;
@property (nonatomic, assign) SInt64 currentFileTime;
@property (nonatomic, assign) dispatch_source_t callbackTimer;

@end


@implementation AudioFileWriter

static pthread_mutex_t outputAudioFileLock;

- (void)dealloc
{
    [self stop];
    
    free(self.outputBuffer);
    free(self.holdingBuffer);
    
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
        CFURLRef audioFileRef = (__bridge CFURLRef)self.audioFileURL;
        
        AudioStreamBasicDescription outputFileDesc = {44100.0, kAudioFormatMPEG4AAC, 0, 0, 1024, 0, thisNumChannels, 0, 0};
        
        CheckError(ExtAudioFileCreateWithURL(audioFileRef, kAudioFileM4AType, &outputFileDesc, NULL, kAudioFileFlags_EraseFile, &_outputFile), "Creating file");
        
        
        // Set a few defaults and presets
        self.samplingRate = thisSamplingRate;
        self.numChannels = thisNumChannels;
        self.currentTime = 0.0;
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
        ExtAudioFileSetProperty(_outputFile, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &_outputFormat);
        
        
        // Arbitrary buffer sizes that don't matter so much as long as they're "big enough"
        self.outputBuffer = (float *)calloc(2*self.samplingRate, sizeof(float));
        self.holdingBuffer = (float *)calloc(2*self.samplingRate, sizeof(float));
        
        pthread_mutex_init(&outputAudioFileLock, NULL);
        
        // mutex here //
        if( 0 == pthread_mutex_trylock( &outputAudioFileLock ) ) 
        {       
            CheckError( ExtAudioFileWriteAsync(self.outputFile, 0, NULL), "Initializing audio file");
        }
        pthread_mutex_unlock( &outputAudioFileLock );
        
    }
    return self;
}

- (void)writeNewAudio:(float *)newData numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
    UInt32 numIncomingBytes = thisNumFrames*thisNumChannels*sizeof(float);
    memcpy(self.outputBuffer, newData, numIncomingBytes);
    
    AudioBufferList outgoingAudio;
    outgoingAudio.mNumberBuffers = 1;
    outgoingAudio.mBuffers[0].mNumberChannels = thisNumChannels;
    outgoingAudio.mBuffers[0].mDataByteSize = numIncomingBytes;
    outgoingAudio.mBuffers[0].mData = self.outputBuffer;
    
    if( 0 == pthread_mutex_trylock( &outputAudioFileLock ) ) 
    {       
        ExtAudioFileWriteAsync(self.outputFile, thisNumFrames, &outgoingAudio);
    }
    pthread_mutex_unlock( &outputAudioFileLock );
    
    // Figure out where we are in the file
    SInt64 frameOffset = 0;
    ExtAudioFileTell(self.outputFile, &frameOffset);
    self.currentTime = (float)frameOffset / self.samplingRate;
    
}


- (float)getDuration
{
    // We're going to directly calculate the duration of the audio file (in seconds)
    SInt64 framesInThisFile;
    UInt32 propertySize = sizeof(framesInThisFile);
    ExtAudioFileGetProperty(self.outputFile, kExtAudioFileProperty_FileLengthFrames, &propertySize, &framesInThisFile);
    
    AudioStreamBasicDescription fileStreamFormat;
    propertySize = sizeof(AudioStreamBasicDescription);
    ExtAudioFileGetProperty(self.outputFile, kExtAudioFileProperty_FileDataFormat, &propertySize, &fileStreamFormat);
    
    return (float)framesInThisFile/(float)fileStreamFormat.mSampleRate;
    
}



- (void)configureWriterCallback
{
    
    if (!self.callbackTimer)
    {
        self.callbackTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    }
    
    if (self.callbackTimer)
    {
        UInt32 numSamplesPerCallback = (UInt32)( self.latency * self.samplingRate );
        dispatch_source_set_timer(self.callbackTimer, dispatch_walltime(NULL, 0), self.latency*NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(self.callbackTimer, ^{
            
            
            if (self.writerBlock) {                
                // Call out with the audio that we've got.
                self.writerBlock(self.outputBuffer, numSamplesPerCallback, self.numChannels);
                
                // Get audio from the block supplier
                [self writeNewAudio:self.outputBuffer numFrames:numSamplesPerCallback numChannels:self.numChannels];
                
            }
            
        });
        
    }
    
}



- (void)record;
{
    
    // Configure (or if necessary, create and start) the timer for retrieving MP3 audio
    [self configureWriterCallback];
    
    if (!self.recording)
    {
        dispatch_resume(self.callbackTimer);
        self.recording = TRUE;
    }
    
}

- (void)stop
{
    // Close the
    pthread_mutex_lock( &outputAudioFileLock );
    ExtAudioFileDispose(self.outputFile);
    pthread_mutex_unlock( &outputAudioFileLock );
    self.recording = FALSE;
}

- (void)pause
{
    // Pause the dispatch timer for retrieving the MP3 audio
    if (self.callbackTimer) {
        dispatch_suspend(self.callbackTimer);
        self.recording = FALSE;
    }
}



@end


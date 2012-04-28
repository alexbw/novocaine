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
//
// TODO:
// Switching mic and speaker on/off
//
// HOUSEKEEPING AND NICE FEATURES:
// Disambiguate outputFormat (the AUHAL's stream format)
// More nuanced input detection on the Mac
// Route switching should work, check with iPhone
// Device switching should work, check with laptop. Read that damn book.
// Wrap logging with debug macros.
// Think about what should be public, what private.
// Ability to select non-default devices.


#import "Novocaine.h"
#define kInputBus 1
#define kOutputBus 0
#define kDefaultDevice 999999



static Novocaine *audioManager = nil;

@interface Novocaine()
- (void)setupAudio;

- (NSString *)applicationDocumentsDirectory;

@end


@implementation Novocaine
@synthesize inputUnit;
@synthesize outputUnit;
@synthesize inputBuffer;
@synthesize inputRoute, inputAvailable;
@synthesize numInputChannels, numOutputChannels;
@synthesize inputBlock, outputBlock;
@synthesize samplingRate;
@synthesize isInterleaved;
@synthesize numBytesPerSample;
@synthesize inData;
@synthesize outData;
@synthesize playing;

@synthesize outputFormat;
@synthesize inputFormat;
// @synthesize playThroughEnabled;

#if defined( USING_OSX )
@synthesize deviceIDs;
@synthesize deviceNames;
@synthesize defaultInputDeviceID;
@synthesize defaultInputDeviceName;
@synthesize defaultOutputDeviceID;
@synthesize defaultOutputDeviceName;
#endif

#pragma mark - Singleton Methods
+ (Novocaine *) audioManager
{
	@synchronized(self)
	{
		if (audioManager == nil) {
			audioManager = [[Novocaine alloc] init];
		}
	}
    return audioManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (audioManager == nil) {
            audioManager = [super allocWithZone:zone];
            return audioManager;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

- (id)init
{
	if (self = [super init])
	{
		
		// Initialize some stuff k?
        outputBlock		= nil;
		inputBlock	= nil;
        
        // Initialize a float buffer to hold audio
		self.inData  = (float *)calloc(8192, sizeof(float)); // probably more than we'll need
        self.outData = (float *)calloc(8192, sizeof(float));
        
        self.inputBlock = nil;
        self.outputBlock = nil;
        
#if defined ( USING_OSX )
        self.deviceNames = [[NSMutableArray alloc] initWithCapacity:100]; // more than we'll need
#endif
        
        self.playing = NO;
        // self.playThroughEnabled = NO;
		
		// Fire up the audio session ( with steady error checking ... )
        [self ifAudioInputIsAvailableThenSetupAudioSession];
		
		return self;
		
	}
	
	return nil;
}


#pragma mark - Block Handling
- (void)setInputBlock:(InputBlock)newInputBlock
{
    inputBlock = Block_copy(newInputBlock);
}

- (void)setOutputBlock:(OutputBlock)newOutputBlock
{
    outputBlock = Block_copy(newOutputBlock);
}



#pragma mark - Audio Methods


- (void)ifAudioInputIsAvailableThenSetupAudioSession {
	// Initialize and configure the audio session, and add an interuption listener
    
#if defined ( USING_IOS )
    CheckError( AudioSessionInitialize(NULL, NULL, sessionInterruptionListener, self), "Couldn't initialize audio session");
    [self checkAudioSource];    
#elif defined ( USING_OSX )
    // TODO: grab the audio device
    [self enumerateAudioDevices];
    self.inputAvailable = YES;
#endif
	
    // Check the session properties (available input routes, number of channels, etc)
    
    
    
    // If we do have input, then let's rock 'n roll.
	if (self.inputAvailable) {
		[self setupAudio];
		[self play];
	}
    
    // If we don't have input, then ask the user to provide some
	else
    {
#if defined ( USING_IOS )
		UIAlertView *noInputAlert =
		[[UIAlertView alloc] initWithTitle:@"No Audio Input"
								   message:@"Couldn't find any audio input. Plug in your Apple headphones or another microphone."
								  delegate:self
						 cancelButtonTitle:@"OK"
						 otherButtonTitles:nil];
		
		[noInputAlert show];
		[noInputAlert release];
#endif
        
	}
}


- (void)setupAudio
{
    
    
    // --- Audio Session Setup ---
    // ---------------------------
    
#if defined ( USING_IOS )
    
    UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
    CheckError( AudioSessionSetProperty (kAudioSessionProperty_AudioCategory,
                                         sizeof (sessionCategory),
                                         &sessionCategory), "Couldn't set audio category");    
    
    
    // Add a property listener, to listen to changes to the session
    CheckError( AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, sessionPropertyListener, self), "Couldn't add audio session property listener");
    
    // Set the buffer size, this will affect the number of samples that get rendered every time the audio callback is fired
    // A small number will get you lower latency audio, but will make your processor work harder
    Float32 preferredBufferSize = 0.0232;
    CheckError( AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize), "Couldn't set the preferred buffer duration");
    
    
    // Set the audio session active
    CheckError( AudioSessionSetActive(YES), "Couldn't activate the audio session");
    
    [self checkSessionProperties];
    
#elif defined ( USING_OSX )
    
    
    
#endif
    
    
    
    // ----- Audio Unit Setup -----
    // ----------------------------
    
    
    // Describe the output unit.
    
#if defined ( USING_OSX )
    AudioComponentDescription inputDescription = {0};	
    inputDescription.componentType = kAudioUnitType_Output;
    inputDescription.componentSubType = kAudioUnitSubType_HALOutput;
    inputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AudioComponentDescription outputDescription = {0};	
    outputDescription.componentType = kAudioUnitType_Output;
    outputDescription.componentSubType = kAudioUnitSubType_HALOutput;
    outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;    
    
#elif defined (USING_IOS)
    AudioComponentDescription inputDescription = {0};	
    inputDescription.componentType = kAudioUnitType_Output;
    inputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    inputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    
#endif
    
    
    
    // Get component
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &inputDescription);
    CheckError( AudioComponentInstanceNew(inputComponent, &inputUnit), "Couldn't create the output audio unit");
    
#if defined ( USING_OSX )
    AudioComponent outputComponent = AudioComponentFindNext(NULL, &outputDescription);
    CheckError( AudioComponentInstanceNew(outputComponent, &outputUnit), "Couldn't create the output audio unit");
#endif
    
    
    // Enable input
    UInt32 one = 1;
    CheckError( AudioUnitSetProperty(inputUnit, 
                                     kAudioOutputUnitProperty_EnableIO, 
                                     kAudioUnitScope_Input, 
                                     kInputBus, 
                                     &one, 
                                     sizeof(one)), "Couldn't enable IO on the input scope of output unit");
    
#if defined ( USING_OSX )    
    // Disable output on the input unit
    // (only on Mac, since on the iPhone, the input unit is also the output unit)
    UInt32 zero = 0;
    CheckError( AudioUnitSetProperty(inputUnit, 
                                     kAudioOutputUnitProperty_EnableIO, 
                                     kAudioUnitScope_Output, 
                                     kOutputBus, 
                                     &zero, 
                                     sizeof(UInt32)), "Couldn't disable output on the audio unit");
    
    // Enable output
    CheckError( AudioUnitSetProperty(outputUnit, 
                                     kAudioOutputUnitProperty_EnableIO, 
                                     kAudioUnitScope_Output, 
                                     kOutputBus, 
                                     &one, 
                                     sizeof(one)), "Couldn't enable IO on the input scope of output unit");
    
    // Disable input
    CheckError( AudioUnitSetProperty(outputUnit, 
                                     kAudioOutputUnitProperty_EnableIO, 
                                     kAudioUnitScope_Input, 
                                     kInputBus, 
                                     &zero, 
                                     sizeof(UInt32)), "Couldn't disable output on the audio unit");
    
#endif
    
    // TODO: first query the hardware for desired stream descriptions
    // Check the input stream format
    
# if defined ( USING_IOS )
    UInt32 size;
	size = sizeof( AudioStreamBasicDescription );
	CheckError( AudioUnitGetProperty( inputUnit, 
                                     kAudioUnitProperty_StreamFormat, 
                                     kAudioUnitScope_Input, 
                                     1, 
                                     &inputFormat, 
                                     &size ), 
               "Couldn't get the hardware input stream format");
	
	// Check the output stream format
	size = sizeof( AudioStreamBasicDescription );
	CheckError( AudioUnitGetProperty( inputUnit, 
                                     kAudioUnitProperty_StreamFormat, 
                                     kAudioUnitScope_Output, 
                                     1, 
                                     &outputFormat, 
                                     &size ), 
               "Couldn't get the hardware output stream format");
    
    // TODO: check this works on iOS!
    inputFormat.mSampleRate = 44100.0;
    outputFormat.mSampleRate = 44100.0;
    self.samplingRate = inputFormat.mSampleRate;
    self.numBytesPerSample = inputFormat.mBitsPerChannel / 8;
    
    size = sizeof(AudioStreamBasicDescription);
	CheckError(AudioUnitSetProperty(inputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Output,
									kInputBus,
									&outputFormat,
									size),
			   "Couldn't set the ASBD on the audio unit (after setting its sampling rate)");
    
    
# elif defined ( USING_OSX )
    
    UInt32 size = sizeof(AudioDeviceID);
    if(self.defaultInputDeviceID == kAudioDeviceUnknown)
    {  
        AudioDeviceID thisDeviceID;            
        UInt32 propsize = sizeof(AudioDeviceID);
        CheckError(AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice, &propsize, &thisDeviceID), "Could not get the default device");
        self.defaultInputDeviceID = thisDeviceID;
    }
    
    if (self.defaultOutputDeviceID == kAudioDeviceUnknown)
    {
        AudioDeviceID thisDeviceID;            
        UInt32 propsize = sizeof(AudioDeviceID);
        CheckError(AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &propsize, &thisDeviceID), "Could not get the default device");
        self.defaultOutputDeviceID = thisDeviceID;
        
    }
    
    
    // Set the current device to the default input unit.
    CheckError( AudioUnitSetProperty( inputUnit, 
                                     kAudioOutputUnitProperty_CurrentDevice, 
                                     kAudioUnitScope_Global, 
                                     kOutputBus, 
                                     &defaultInputDeviceID, 
                                     sizeof(AudioDeviceID) ), "Couldn't set the current input audio device");
    
    CheckError( AudioUnitSetProperty( outputUnit, 
                                     kAudioOutputUnitProperty_CurrentDevice, 
                                     kAudioUnitScope_Global, 
                                     kOutputBus, 
                                     &defaultOutputDeviceID, 
                                     sizeof(AudioDeviceID) ), "Couldn't set the current output audio device");
    
    
	UInt32 propertySize = sizeof(AudioStreamBasicDescription);
	CheckError(AudioUnitGetProperty(inputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Output,
									kInputBus,
									&outputFormat,
									&propertySize),
			   "Couldn't get ASBD from input unit");
    
    
	// 9/6/10 - check the input device's stream format
	CheckError(AudioUnitGetProperty(inputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Input,
									kInputBus,
									&inputFormat,
									&propertySize),
			   "Couldn't get ASBD from input unit");
    
    
    outputFormat.mSampleRate = inputFormat.mSampleRate;
//    outputFormat.mFormatFlags =  kAudioFormatFlagsCanonical;
    self.samplingRate = inputFormat.mSampleRate;
    self.numBytesPerSample = inputFormat.mBitsPerChannel / 8;
    
    self.numInputChannels = inputFormat.mChannelsPerFrame;
    self.numOutputChannels = outputFormat.mChannelsPerFrame;
    
    propertySize = sizeof(AudioStreamBasicDescription);
	CheckError(AudioUnitSetProperty(inputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Output,
									kInputBus,
									&outputFormat,
									propertySize),
			   "Couldn't set the ASBD on the audio unit (after setting its sampling rate)");
    
    
#endif
    
    
    
#if defined ( USING_IOS )
    UInt32 numFramesPerBuffer;
    size = sizeof(UInt32);
    CheckError(AudioUnitGetProperty(inputUnit, 
                                    kAudioUnitProperty_MaximumFramesPerSlice,
                                    kAudioUnitScope_Global, 
                                    kOutputBus, 
                                    &numFramesPerBuffer, 
                                    &size), 
               "Couldn't get the number of frames per callback");
    
    UInt32 bufferSizeBytes = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket * numFramesPerBuffer;
    
#elif defined ( USING_OSX )
	// Get the size of the IO buffer(s)
	UInt32 bufferSizeFrames = 0;
	size = sizeof(UInt32);
	CheckError (AudioUnitGetProperty(self.inputUnit,
									 kAudioDevicePropertyBufferFrameSize,
									 kAudioUnitScope_Global,
									 0,
									 &bufferSizeFrames,
									 &size),
				"Couldn't get buffer frame size from input unit");
	UInt32 bufferSizeBytes = bufferSizeFrames * sizeof(Float32);
#endif
    
    
    
	if (outputFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
        // The audio is non-interleaved
        printf("Not interleaved!\n");
        self.isInterleaved = NO;
        
        // allocate an AudioBufferList plus enough space for array of AudioBuffers
		UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * outputFormat.mChannelsPerFrame);
		
		//malloc buffer lists
		self.inputBuffer = (AudioBufferList *)malloc(propsize);
		self.inputBuffer->mNumberBuffers = outputFormat.mChannelsPerFrame;
		
		//pre-malloc buffers for AudioBufferLists
		for(UInt32 i =0; i< self.inputBuffer->mNumberBuffers ; i++) {
			self.inputBuffer->mBuffers[i].mNumberChannels = 1;
			self.inputBuffer->mBuffers[i].mDataByteSize = bufferSizeBytes;
			self.inputBuffer->mBuffers[i].mData = malloc(bufferSizeBytes);
            memset(self.inputBuffer->mBuffers[i].mData, 0, bufferSizeBytes);
		}
        
	} else {
		printf ("Format is interleaved\n");
        self.isInterleaved = YES;
        
		// allocate an AudioBufferList plus enough space for array of AudioBuffers
		UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * 1);
		
		//malloc buffer lists
		self.inputBuffer = (AudioBufferList *)malloc(propsize);
		self.inputBuffer->mNumberBuffers = 1;
		
		//pre-malloc buffers for AudioBufferLists
		self.inputBuffer->mBuffers[0].mNumberChannels = outputFormat.mChannelsPerFrame;
		self.inputBuffer->mBuffers[0].mDataByteSize = bufferSizeBytes;
		self.inputBuffer->mBuffers[0].mData = malloc(bufferSizeBytes);
        memset(self.inputBuffer->mBuffers[0].mData, 0, bufferSizeBytes);
        
	}
    
    
    // Slap a render callback on the unit
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = inputCallback;
    callbackStruct.inputProcRefCon = self;
    
    CheckError( AudioUnitSetProperty(inputUnit, 
                                     kAudioOutputUnitProperty_SetInputCallback, 
                                     kAudioUnitScope_Global,
                                     0, 
                                     &callbackStruct, 
                                     sizeof(callbackStruct)), "Couldn't set the callback on the input unit");
    
    
    callbackStruct.inputProc = renderCallback;
    callbackStruct.inputProcRefCon = self;
# if defined ( USING_OSX )    
    CheckError( AudioUnitSetProperty(outputUnit, 
                                     kAudioUnitProperty_SetRenderCallback, 
                                     kAudioUnitScope_Input,
                                     0,
                                     &callbackStruct, 
                                     sizeof(callbackStruct)), 
               "Couldn't set the render callback on the input unit");
    
#elif defined ( USING_IOS )
    CheckError( AudioUnitSetProperty(inputUnit, 
                                     kAudioUnitProperty_SetRenderCallback, 
                                     kAudioUnitScope_Input,
                                     0,
                                     &callbackStruct, 
                                     sizeof(callbackStruct)), 
               "Couldn't set the render callback on the input unit");    
#endif
    
    
    
    
	CheckError(AudioUnitInitialize(inputUnit), "Couldn't initialize the output unit");
#if defined ( USING_OSX )
    CheckError(AudioUnitInitialize(outputUnit), "Couldn't initialize the output unit");
#endif
    
        
	
}

#if defined (USING_OSX)
- (void)enumerateAudioDevices
{
    UInt32 propSize;
    
	UInt32 propsize = sizeof(AudioDeviceID);
	CheckError(AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice, &propsize, &defaultInputDeviceID), "Could not get the default device");
    
    AudioHardwareGetPropertyInfo( kAudioHardwarePropertyDevices, &propSize, NULL );
    uint32_t deviceCount = ( propSize / sizeof(AudioDeviceID) );
    
    // Allocate the device IDs
    self.deviceIDs = (AudioDeviceID *)calloc(deviceCount, sizeof(AudioDeviceID));
    [deviceNames removeAllObjects];
    
    // Get all the device IDs
    CheckError( AudioHardwareGetProperty( kAudioHardwarePropertyDevices, &propSize, self.deviceIDs ), "Could not get device IDs");
    
    // Get the names of all the device IDs
    for( int i = 0; i < deviceCount; i++ ) 
    {
        UInt32 size = sizeof(AudioDeviceID);
        CheckError( AudioDeviceGetPropertyInfo( self.deviceIDs[i], 0, true, kAudioDevicePropertyDeviceName, &size, NULL ), "Could not get device name length");
        
        char cStringOfDeviceName[size];
        CheckError( AudioDeviceGetProperty( self.deviceIDs[i], 0, true, kAudioDevicePropertyDeviceName, &size, cStringOfDeviceName ), "Could not get device name");
        NSString *thisDeviceName = [NSString stringWithCString:cStringOfDeviceName encoding:NSUTF8StringEncoding];
        
        NSLog(@"Device: %@, ID: %d", thisDeviceName, self.deviceIDs[i]);
        [deviceNames addObject:thisDeviceName];            
    }
    
}

#endif



- (void)pause {
	
	if (playing) {
        CheckError( AudioOutputUnitStop(inputUnit), "Couldn't stop the output unit");
#if defined ( USING_OSX )
		CheckError( AudioOutputUnitStop(outputUnit), "Couldn't stop the output unit");
#endif
		playing = NO;
	}
    
}

- (void)play {
	
	UInt32 isInputAvailable=0;
	UInt32 size = sizeof(isInputAvailable);
    
#if defined ( USING_IOS )
	CheckError( AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, 
                                        &size, 
                                        &isInputAvailable), "Couldn't check if input was available");
    
#elif defined ( USING_OSX )
    isInputAvailable = 1;
    
#endif
    
    
    self.inputAvailable = isInputAvailable;
    
	if ( self.inputAvailable ) {
		// Set the audio session category for simultaneous play and record
		if (!playing) {
			CheckError( AudioOutputUnitStart(inputUnit), "Couldn't start the output unit");
#if defined ( USING_OSX )
            CheckError( AudioOutputUnitStart(outputUnit), "Couldn't start the output unit");
#endif
            
            self.playing = YES;
            
		}
	}
    
}


#pragma mark - Render Methods
OSStatus inputCallback   (void						*inRefCon,
                          AudioUnitRenderActionFlags	* ioActionFlags,
                          const AudioTimeStamp 		* inTimeStamp,
                          UInt32						inOutputBusNumber,
                          UInt32						inNumberFrames,
                          AudioBufferList			* ioData)
{
    
    
	Novocaine *sm = (Novocaine *)inRefCon;
    
    if (!sm.playing)
        return noErr;
    if (sm.inputBlock == nil)
        return noErr;    
    
    
    // Check the current number of channels		
    // Let's actually grab the audio
    CheckError( AudioUnitRender(sm.inputUnit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, sm.inputBuffer), "Couldn't render the output unit");
    
    
    // Convert the audio in something manageable
    // For Float32s ... 
    if ( sm.numBytesPerSample == 4 ) // then we've already got flaots
    {
        
        float zero = 0.0f;
        if ( ! sm.isInterleaved ) { // if the data is in separate buffers, make it interleaved
            for (int i=0; i < sm.numInputChannels; ++i) {
                vDSP_vsadd((float *)sm.inputBuffer->mBuffers[i].mData, 1, &zero, sm.inData+i, 
                           sm.numInputChannels, inNumberFrames);
            }
        } 
        else { // if the data is already interleaved, copy it all in one happy block.
            // TODO: check mDataByteSize is proper 
            memcpy(sm.inData, (float *)sm.inputBuffer->mBuffers[0].mData, sm.inputBuffer->mBuffers[0].mDataByteSize);
        }
    }
    
    // For SInt16s ...
    else if ( sm.numBytesPerSample == 2 ) // then we're dealing with SInt16's
    {
        if ( ! sm.isInterleaved ) {
            for (int i=0; i < sm.numInputChannels; ++i) {
                vDSP_vflt16((SInt16 *)sm.inputBuffer->mBuffers[i].mData, 1, sm.inData+i, sm.numInputChannels, inNumberFrames);
            }            
        }
        else {
            vDSP_vflt16((SInt16 *)sm.inputBuffer->mBuffers[0].mData, 1, sm.inData, 1, inNumberFrames*sm.numInputChannels);
        }
        
        float scale = 1.0 / (float)INT16_MAX;
        vDSP_vsmul(sm.inData, 1, &scale, sm.inData, 1, inNumberFrames*sm.numInputChannels);
    }
    
    // Now do the processing! 
    sm.inputBlock(sm.inData, inNumberFrames, sm.numInputChannels);
    
    return noErr;
	
	
}

OSStatus renderCallback (void						*inRefCon,
                         AudioUnitRenderActionFlags	* ioActionFlags,
                         const AudioTimeStamp 		* inTimeStamp,
                         UInt32						inOutputBusNumber,
                         UInt32						inNumberFrames,
                         AudioBufferList				* ioData)
{
    
    
	Novocaine *sm = (Novocaine *)inRefCon;    
    float zero = 0.0;
    
    
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {        
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    if (!sm.playing)
        return noErr;
    if (!sm.outputBlock)
        return noErr;


    // Collect data to render from the callbacks
    sm.outputBlock(sm.outData, inNumberFrames, sm.numOutputChannels);
    
    
    // Put the rendered data into the output buffer
    // TODO: convert SInt16 ranges to float ranges.
    if ( sm.numBytesPerSample == 4 ) // then we've already got floats
    {
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {  
            
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                vDSP_vsadd(sm.outData+iChannel, sm.numOutputChannels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, inNumberFrames);
            }
        }
    }
    else if ( sm.numBytesPerSample == 2 ) // then we need to convert SInt16 -> Float (and also scale)
    {
        float scale = (float)INT16_MAX;
        vDSP_vsmul(sm.outData, 1, &scale, sm.outData, 1, inNumberFrames*sm.numOutputChannels);
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {  
            
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                vDSP_vfix16(sm.outData+iChannel, sm.numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, inNumberFrames);
            }
        }
        
    }

    return noErr;
    
}	

#pragma mark - Audio Session Listeners
#if defined (USING_IOS)
void sessionPropertyListener(void *                  inClientData,
							 AudioSessionPropertyID  inID,
							 UInt32                  inDataSize,
							 const void *            inData){
	
    
	if (inID == kAudioSessionProperty_AudioRouteChange)
    {
        Novocaine *sm = (Novocaine *)inClientData;
        [sm checkSessionProperties];
    }
    
}

- (void)checkAudioSource {
    // Check what the incoming audio route is.
    UInt32 propertySize = sizeof(CFStringRef);
    CFStringRef route;
    CheckError( AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route), "Couldn't check the audio route");
    self.inputRoute = (NSString *)route;
    NSLog(@"AudioRoute: %@", self.inputRoute);
    
    
    // Check if there's input available.
    // TODO: check if checking for available input is redundant.
    //          Possibly there's a different property ID change?
    UInt32 isInputAvailable = 0;
    UInt32 size = sizeof(isInputAvailable);
    CheckError( AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, 
                                        &size, 
                                        &isInputAvailable), "Couldn't check if input is available");
    self.inputAvailable = (BOOL)isInputAvailable;
    NSLog(@"Input available? %d", self.inputAvailable);
    
}


// To be run ONCE per session property change and once on initialization.
- (void)checkSessionProperties
{	
    
    // Check if there is input, and from where
    [self checkAudioSource];
    
    // Check the number of input channels.
    // Find the number of channels
    UInt32 size = sizeof(self.numInputChannels);
    UInt32 newNumChannels;
    CheckError( AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &newNumChannels), "Checking number of input channels");
    self.numInputChannels = newNumChannels;
    //    self.numInputChannels = 1;
    NSLog(@"We've got %lu input channels", self.numInputChannels);
    
    
    // Check the number of input channels.
    // Find the number of channels
    CheckError( AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputNumberChannels, &size, &newNumChannels), "Checking number of output channels");
    self.numOutputChannels = newNumChannels;
    //    self.numOutputChannels = 1;
    NSLog(@"We've got %lu output channels", self.numOutputChannels);
    
    
    // Get the hardware sampling rate. This is settable, but here we're only reading.
    Float64 currentSamplingRate;
    size = sizeof(currentSamplingRate);
    CheckError( AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &currentSamplingRate), "Checking hardware sampling rate");
    self.samplingRate = currentSamplingRate;
    NSLog(@"Current sampling rate: %f", self.samplingRate);
	
}

void sessionInterruptionListener(void *inClientData, UInt32 inInterruption) {
    
	Novocaine *sm = (Novocaine *)inClientData;
    
	if (inInterruption == kAudioSessionBeginInterruption) {
		NSLog(@"Begin interuption");
		sm.inputAvailable = NO;
	}
	else if (inInterruption == kAudioSessionEndInterruption) {
		NSLog(@"End interuption");	
		sm.inputAvailable = YES;
		[sm play];
	}
	
}

#endif




#if defined ( USING_OSX )

// Checks the number of channels and sampling rate of the connected device.
- (void)checkDeviceProperties
{
    
}

- (void)selectAudioDevice:(AudioDeviceID)deviceID
{
    
}

#endif


#pragma mark - Convenience Methods
- (NSString *)applicationDocumentsDirectory {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}


@end









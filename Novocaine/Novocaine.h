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

#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>

#if defined __MAC_OS_X_VERSION_MAX_ALLOWED
    #define USING_OSX 
    #include <CoreAudio/CoreAudio.h>
#else
    #define USING_IOS
    #include <AVFoundation/AVFoundation.h>
#endif

#include <Block.h>


#ifdef __cplusplus
extern "C" {
#endif
	
static void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;
	
	char str[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(str, "%d", (int)error);
    
	fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
	exit(1);
}


OSStatus inputCallback (void						*inRefCon,
						AudioUnitRenderActionFlags	* ioActionFlags,
						const AudioTimeStamp 		* inTimeStamp,
						UInt32						inOutputBusNumber,
						UInt32						inNumberFrames,
						AudioBufferList				* ioData);

OSStatus renderCallback (void						*inRefCon,
                         AudioUnitRenderActionFlags	* ioActionFlags,
                         const AudioTimeStamp 		* inTimeStamp,
                         UInt32						inOutputBusNumber,
                         UInt32						inNumberFrames,
                         AudioBufferList				* ioData);


#if defined (USING_IOS)
void sessionPropertyListener(void *                  inClientData,
							 AudioSessionPropertyID  inID,
							 UInt32                  inDataSize,
							 const void *            inData);

#endif


void sessionInterruptionListener(void *inClientData, UInt32 inInterruption);

#ifdef __cplusplus
}
#endif

typedef void (^NovocaineOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);
typedef void (^NovocaineInputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

#if defined (USING_IOS)
@interface Novocaine : NSObject <UIAlertViewDelegate>
#elif defined (USING_OSX)
@interface Novocaine : NSObject
#endif

// ------ These properties/methods are used for configuration -------

@property (nonatomic, copy)     NSString *inputRoute;

// TODO: Not yet implemented. No effect right now.
//@property (nonatomic, assign)   BOOL inputEnabled;

#ifdef USING_IOS
@property (nonatomic, assign)   BOOL forceOutputToSpeaker;
#endif

// Explicitly declaring the block setters will create the correct block signature for auto-complete.
// These will map to the setters for the block properties below.
- (void)setInputBlock:(NovocaineInputBlock)block;
- (void)setOutputBlock:(NovocaineOutputBlock)block;

@property (nonatomic, copy) NovocaineOutputBlock outputBlock;
@property (nonatomic, copy) NovocaineInputBlock inputBlock;

// ------------------------------------------------------------------

// these should be readonly in public interface - no need for public write access
@property (nonatomic, assign, readonly) AudioUnit inputUnit;
@property (nonatomic, assign, readonly) AudioUnit outputUnit;
@property (nonatomic, assign, readonly) AudioBufferList *inputBuffer;
@property (nonatomic, assign, readonly) BOOL inputAvailable;
@property (nonatomic, assign, readonly) UInt32 numInputChannels;
@property (nonatomic, assign, readonly) UInt32 numOutputChannels;
@property (nonatomic, assign, readonly) Float64 samplingRate;
@property (nonatomic, assign, readonly) BOOL isInterleaved;
@property (nonatomic, assign, readonly) UInt32 numBytesPerSample;
@property (nonatomic, assign, readonly) AudioStreamBasicDescription inputFormat;
@property (nonatomic, assign, readonly) AudioStreamBasicDescription outputFormat;
@property (nonatomic, assign, readonly) BOOL playing;

// @property BOOL playThroughEnabled;


// Singleton methods
+ (Novocaine *) audioManager;

// Audio Unit methods
- (void)play;
- (void)pause;

#if defined ( USING_IOS )
- (void)checkSessionProperties;
- (void)checkAudioSource;
#endif


@end

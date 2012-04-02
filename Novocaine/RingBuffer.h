/*
 *  RingBuffer.h
 *  oScope
 *
 *  Created by Alex Wiltschko on 7/8/10.
 *  Copyright 2010 Alex Wiltschko. All rights reserved.
 *
 */

// TODO: Error throwing if things go wrong.
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>

#define kMaxNumChannels 4

class RingBuffer {
public:	
	RingBuffer() {};
	RingBuffer(SInt64 bufferLength, SInt64 numChannels);
	~RingBuffer() {};
	
	void AddNewSInt16AudioBuffer(const AudioBuffer aBuffer);
	void AddNewSInt16Data(const SInt16 *newData, const SInt64 numFrames, const SInt64 whichChannel);
	void AddNewFloatData(const float *newData, const SInt64 numFrames, const SInt64 whichChannel = 0);
	void AddNewDoubleData(const double *newData, const SInt64 numFrames, const SInt64 whichChannel = 0);
	void AddNewInterleavedFloatData(const float *newData, const SInt64 numFrames, const SInt64 numChannelsHere);
    void FetchInterleavedData(float *outData, SInt64 numFrames, SInt64 numChannels);
	void FetchFreshData(float *outData, SInt64 numFrames, SInt64 whichChannel, SInt64 stride);
    void FetchData(float *outData, SInt64 numFrames, SInt64 whichChannel, SInt64 stride);
	SInt64 NumNewFrames(SInt64 lastReadFrame, int iChannel = 0);
    SInt64 NumUnreadFrames(int iChannel = 0) {return mNumUnreadFrames[iChannel]; }
	
	SInt64 WriteHeadPosition(int aChannel = 0) { return mLastWrittenIndex[aChannel]; }
	SInt64 ReadHeadPosition(int aChannel = 0) { return mLastReadIndex[aChannel]; }
    
    void SeekWriteHeadPosition(SInt64 offset, int iChannel=0);
    void SeekReadHeadPosition(SInt64 offset, int iChannel=0);
	SInt64 NumChannels() {return mNumChannels; }
	
	void Clear();
	
	// Analytics
	float Mean(const SInt64 whichChannel = 0);
	float Max(const SInt64 whichChannel = 0);
	float Min(const SInt64 whichChannel = 0);
	
private:
	SInt64 mLastWrittenIndex[kMaxNumChannels];
	SInt64 mLastReadIndex[kMaxNumChannels];
    SInt64 mNumUnreadFrames[kMaxNumChannels];
	SInt64 mSizeOfBuffer;
	SInt64 mNumChannels;
	float **mData;
	bool mAllocated;
	
};
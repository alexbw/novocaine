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

// TODO: Error throwing if things go wrong.
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>

#define kMaxNumChannels 4

class RingBuffer {
    
public:	
	RingBuffer() {};
	RingBuffer(SInt64 bufferLength, SInt64 numChannels);
	~RingBuffer();
	
	void AddNewSInt16AudioBuffer(const AudioBuffer aBuffer);
	void AddNewSInt16Data(const SInt16 *newData, const SInt64 numFrames, const SInt64 whichChannel);
	void AddNewFloatData(const float *newData, const SInt64 numFrames, const SInt64 whichChannel = 0);
	void AddNewDoubleData(const double *newData, const SInt64 numFrames, const SInt64 whichChannel = 0);
	void AddNewInterleavedFloatData(const float *newData, const SInt64 numFrames, const SInt64 numChannelsHere);
    void FetchInterleavedData(float *outData, SInt64 numFrames, SInt64 numChannels);
	void FetchFreshData(float *outData, SInt64 numFrames, SInt64 whichChannel, SInt64 stride);
	void FetchFreshData2(float *outData, SInt64 numFrames, SInt64 whichChannel, SInt64 stride);
    
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
	
protected:
	int64_t mLastWrittenIndex[kMaxNumChannels];
	int64_t mLastReadIndex[kMaxNumChannels];
    int64_t mNumUnreadFrames[kMaxNumChannels];
	int64_t mSizeOfBuffer;
	int64_t mNumChannels;
	float **mData;
	bool mAllocated;

private:
    void UpdateFrameCount(int numFrames, int channel);
	
};
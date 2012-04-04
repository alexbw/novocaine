## An analgesic for high-performance audio on the iPhone, iPad and Mac OS X.

Really fast audio in iOS and Mac OS X using Audio Units is hard, and will leave you scarred and bloody. What used to take days can now be done with just a few lines of code.

### Getting Audio
	Novocaine *audioManager = [Novocaine audioManager];
	[audioManager setInputBlock^(float *newAudio, UInt32 numSamples, UInt32 numChannels) {
		// Now you're getting audio from the microphone every 20 milliseconds or so. How's that for easy?
		// Audio comes in interleaved, so, 
		// if numChannels = 2, newAudio[0] is channel 1, newAudio[1] is channel 2, newAudio[2] is channel 1, etc. 
	}];

### Playing Audio
	Novocaine *audioManager = [Novocaine audioManager];
	[audioManager setOutputBlock^(float *audioToPlay, UInt32 numSamples, UInt32 numChannels) {
		// All you have to do is put your audio into "audioToPlay". 
	}];

### Does anybody actually use it?
Yep. Novocaine is result of three years of work on the audio engine of Octave, Fourier and oScope, a powerful suite of audio analysis apps.

### A thing to note: 
Change all the files that use Novocaine from MyClass.m to MyClass.mm. Novocaine uses some C++ to make things extra zippy,  
so the classes that use it will have to be Objective-C++. 
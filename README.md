## An analgesic for high-performance audio on iOS and OSX.

Really fast audio in iOS and Mac OS X using Audio Units is hard, and will leave you scarred and bloody. What used to take days can now be done with just a few lines of code.

### Getting Audio
``` objective-c
Novocaine *audioManager = [Novocaine audioManager];
[audioManager setInputBlock:^(float *newAudio, UInt32 numSamples, UInt32 numChannels) {
	// Now you're getting audio from the microphone every 20 milliseconds or so. How's that for easy?
	// Audio comes in interleaved, so,
	// if numChannels = 2, newAudio[0] is channel 1, newAudio[1] is channel 2, newAudio[2] is channel 1, etc.
}];
[audioManager play];
```

### Playing Audio
``` objective-c
Novocaine *audioManager = [Novocaine audioManager];
[audioManager setOutputBlock:^(float *audioToPlay, UInt32 numSamples, UInt32 numChannels) {
	// All you have to do is put your audio into "audioToPlay".
}];
[audioManager play];
```

### Does anybody actually use it?
Yep. Novocaine is result of three years of work on the audio engine of [Octave](https://itunes.apple.com/us/app/octave-an-rta-for-the-iphone/id386083594?mt=8), [Fourier](https://itunes.apple.com/us/app/fourier/id386084557?mt=8) and [oScope](https://itunes.apple.com/us/app/oscope/id344345859?mt=8), a powerful suite of audio analysis apps. Please do check them out!

### A thing to note: 
The RingBuffer class is written in C++ to make things extra zippy, so the classes that use it will have to be Objective-C++. Change all the files that use RingBuffer from MyClass.m to MyClass.mm.

### Want some examples?  
Inside of ViewController.mm are a bunch of tiny little examples I wrote. Uncomment one and see how it sounds.  
Do note, however, for examples involving play-through, that you should be using headphones. Having the  
mic and speaker close to each other will produce some gnarly feedback.  

### Want to learn the nitty-gritty of Core Audio?
If you want to get down and dirty, if you want to get brave and get close to the hardware, I can only point you to the places where I learned how to do this stuff. Chris Adamson and Michael Tyson are two giants in the field of iOS audio, and they each wrote indispensable blog posts ([this is Chris's](http://www.subfurther.com/blog/2009/04/28/an-iphone-core-audio-brain-dump/), [this is Michael's](http://atastypixel.com/blog/using-remoteio-audio-unit/)). Also, Chris Adamson now has a [whole gosh-darned BOOK on Core Audio](http://www.amazon.com/gp/product/0321636848/ref=as_li_ss_tl?ie=UTF8&tag=tico07-20&linkCode=as2&camp=1789&creative=390957&creativeASIN=0321636848
). I would have done unspeakable things to get my hands on this when I was first starting.

[![Analytics](https://ga-beacon.appspot.com/UA-17672588-2/novocaine/readme)](https://github.com/igrigorik/ga-beacon)


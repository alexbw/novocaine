//
//  AppDelegate.h
//  NovocaineExamples Mac
//
//  Created by Alex Wiltschko on 4/2/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Novocaine.h"
#import "RingBuffer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    RingBuffer *ringBuffer;
    Novocaine *audioManager;
}

@property (assign) IBOutlet NSWindow *window;

@end

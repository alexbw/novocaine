//
//  ViewController.h
//  NovocaineExamples
//
//  Created by Alex Wiltschko on 4/2/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Novocaine.h"
#import "RingBuffer.h"

@interface ViewController : UIViewController
{
    RingBuffer *ringBuffer;
    Novocaine *audioManager;
}
@end

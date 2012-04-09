//
//  SPL.m
//  Novocaine
//
//  Created by Alex Wiltschko on 4/7/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "SPL.h"

@implementation SPL
@synthesize volume;



// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    self.backgroundColor = [UIColor clearColor];
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* red = [UIColor colorWithRed: 1 green: 0 blue: 0 alpha: 1];
    
    //// Gradient Declarations
    NSArray* redGradientColors = [NSArray arrayWithObjects: 
                                  (id)red.CGColor, 
                                  (id)[UIColor yellowColor].CGColor, nil];
    CGFloat redGradientLocations[] = {0, 1};
    CGGradientRef redGradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)redGradientColors, redGradientLocations);
    
    
    //// Rounded Rectangle Drawing
    int numBarsToDraw = (int)(volume * (float)kMaxNumBars);
    for (int i=0; i < numBarsToDraw; ++i) {
    
        float yPos = self.frame.size.height - (float)i*10.0 - 20.0;
        UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: CGRectMake(0, yPos, 74, 6) cornerRadius: 3];
        CGContextSaveGState(context);
        [roundedRectanglePath addClip];
        CGContextDrawLinearGradient(context, redGradient, CGPointMake(75.5, 34.5), CGPointMake(75.5, 40.5), 0);
        CGContextRestoreGState(context);
        
        [[UIColor blackColor] setStroke];
        roundedRectanglePath.lineWidth = 1;
        [roundedRectanglePath stroke];
        
    }

    //// Cleanup
    CGGradientRelease(redGradient);
    CGColorSpaceRelease(colorSpace);
}


@end

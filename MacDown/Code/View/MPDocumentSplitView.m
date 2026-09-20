//
//  MPDocumentSplitView.m
//  MacDown
//
//  Created by Tzu-ping Chung on 13/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPDocumentSplitView.h"


@implementation NSColor (Equality)

- (BOOL)isEqualToColor:(NSColor *)color
{
    NSColor *rgb1 = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    NSColor *rgb2 = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    return rgb1 && rgb2 && [rgb1 isEqual:rgb2];
}

@end


@implementation MPDocumentSplitView

@synthesize dividerColor = _dividerColor;

- (NSColor *)dividerColor
{
    if (_dividerColor)
        return _dividerColor;
    return [super dividerColor];
}

- (void)setDividerColor:(NSColor *)color
{
    if ([color isEqualToColor:_dividerColor])
        return;
    _dividerColor = color;
    [self setNeedsDisplay:YES];
}

- (CGFloat)dividerLocation
{
    NSArray *parts = self.subviews;
    NSAssert1(parts.count == 2, @"%@ should only be used on two-item splits.",
              NSStringFromSelector(_cmd));

    CGFloat totalWidth = self.frame.size.width - self.dividerThickness;
    CGFloat leftWidth = [parts[0] frame].size.width;
    if ([parts[0] isHidden] || leftWidth <= 0.0) return 0.0;
    if ([parts[1] isHidden] || [parts[1] frame].size.width <= 0.0) return 1.0;
    return totalWidth > 0.0 ? leftWidth / totalWidth : 0.5;
}

- (void)setDividerLocation:(CGFloat)ratio
{
    NSArray *parts = self.subviews;
    NSAssert1(parts.count == 2, @"%@ should only be used on two-item splits.",
              NSStringFromSelector(_cmd));
    ratio = isfinite(ratio) ? MIN(1.0, MAX(0.0, ratio)) : 0.5;
    NSView *left = parts[0];
    NSView *right = parts[1];
    left.hidden = NO;
    right.hidden = NO;

    CGFloat width = NSWidth(self.bounds);
    CGFloat height = NSHeight(self.bounds);
    CGFloat divider = self.dividerThickness;
    CGFloat available = MAX(0.0, width - divider);
    CGFloat leftWidth = available * ratio;
    // Restore real frames before asking AppKit to position a collapsed divider.
    left.frame = NSMakeRect(0.0, 0.0, leftWidth, height);
    right.frame = NSMakeRect(leftWidth + divider, 0.0, available - leftWidth, height);
    [self adjustSubviews];
    [self setPosition:leftWidth ofDividerAtIndex:0];
    if (ratio == 0.0 || ratio == 1.0)
    {
        left.hidden = ratio == 0.0;
        right.hidden = ratio == 1.0;
        left.frame = NSMakeRect(0.0, 0.0, ratio == 0.0 ? 0.0 : width, height);
        right.frame = NSMakeRect(ratio == 0.0 ? 0.0 : width, 0.0,
                                 ratio == 1.0 ? 0.0 : width, height);
    }
    [self setNeedsDisplay:YES];

}

- (void)swapViews
{
    NSArray *parts = self.subviews;
    NSView *left = parts[0];
    NSView *right = parts[1];
    self.subviews = @[right, left];
}


@end

//
//  MatrixView.m
//  Matrix
//
//  Created by Yousef Jawdat on 26/12/2025.
//

#import "MatrixView.h"

@implementation MatrixView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/30.0];

        _matrixFont = [NSFont monospacedSystemFontOfSize:isPreview ? 10.0 : 14.0 weight:NSFontWeightRegular];

        NSDictionary *sizingAttributes = @{ NSFontAttributeName : _matrixFont };
        _characterWidth = [@"0" sizeWithAttributes:sizingAttributes].width + 1.0;
        _characterHeight = _matrixFont.capHeight + 6.0;

        NSColor *primaryGreen = [NSColor colorWithCalibratedRed:0.0 green:0.9 blue:0.5 alpha:0.9];
        NSColor *trailGreen = [NSColor colorWithCalibratedRed:0.0 green:0.7 blue:0.3 alpha:0.6];

        _glyphAttributes = @{ NSFontAttributeName : _matrixFont,
                              NSForegroundColorAttributeName : trailGreen };

        _headAttributes = @{ NSFontAttributeName : _matrixFont,
                             NSForegroundColorAttributeName : primaryGreen };

        _glyphSet = @[ @"ｱ", @"ｲ", @"ｳ", @"ｴ", @"ｵ", @"ｶ", @"ｷ", @"ｸ", @"ｹ", @"ｺ",
                       @"ｻ", @"ｼ", @"ｽ", @"ｾ", @"ｿ", @"ﾀ", @"ﾁ", @"ﾂ", @"ﾃ", @"ﾄ",
                       @"ﾅ", @"ﾆ", @"ﾇ", @"ﾈ", @"ﾉ", @"ﾊ", @"ﾋ", @"ﾌ", @"ﾍ", @"ﾎ",
                       @"ﾏ", @"ﾐ", @"ﾑ", @"ﾒ", @"ﾓ", @"ﾔ", @"ﾕ", @"ﾖ", @"ﾗ", @"ﾘ",
                       @"ﾙ", @"ﾚ", @"ﾛ", @"ﾜ", @"ﾝ", @"0", @"1", @"2", @"3", @"4",
                       @"5", @"6", @"7", @"8", @"9", @"A", @"B", @"C", @"D", @"E",
                       @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O",
                       @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z" ];

        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.blackColor.CGColor;
        [self resetColumns];
    }
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
    [self resetColumns];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];

    NSInteger expectedColumns = MAX(1, (NSInteger)(self.bounds.size.width / self.characterWidth));
    if (expectedColumns != self.columnCount) {
        [self resetColumns];
    }

    [[NSColor blackColor] set];
    NSRectFill(rect);

    for (NSInteger columnIndex = 0; columnIndex < self.columns.count; columnIndex++) {
        NSMutableDictionary *column = self.columns[columnIndex];
        NSMutableArray<NSString *> *glyphs = column[@"glyphs"];
        CGFloat offset = [column[@"offset"] doubleValue];
        CGFloat speed = [column[@"speed"] doubleValue];

        NSInteger rows = glyphs.count;
        CGFloat x = columnIndex * self.characterWidth;

        for (NSInteger row = 0; row < rows; row++) {
            CGFloat y = self.bounds.size.height - ((row + 1) * self.characterHeight) + offset;

            if (y < -self.characterHeight || y > self.bounds.size.height + self.characterHeight) {
                continue;
            }

            NSString *glyph = glyphs[row];
            NSDictionary *attributes = (row == 0) ? self.headAttributes : self.glyphAttributes;
            [glyph drawAtPoint:NSMakePoint(x, y) withAttributes:attributes];
        }

        offset += speed;

        if (offset >= self.characterHeight) {
            offset -= self.characterHeight;
            [glyphs insertObject:[self randomGlyph] atIndex:0];
            [glyphs removeLastObject];
        }

        column[@"offset"] = @(offset);
    }
}

- (void)animateOneFrame
{
    [self setNeedsDisplay:YES];
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow*)configureSheet
{
    return nil;
}

- (void)resetColumns
{
    CGFloat width = self.bounds.size.width;
    self.columnCount = MAX(1, (NSInteger)(width / self.characterWidth));

    NSInteger rows = (NSInteger)(self.bounds.size.height / self.characterHeight) + 2;

    self.columns = [NSMutableArray arrayWithCapacity:self.columnCount];

    for (NSInteger columnIndex = 0; columnIndex < self.columnCount; columnIndex++) {
        NSMutableArray<NSString *> *glyphs = [NSMutableArray arrayWithCapacity:rows];
        for (NSInteger rowIndex = 0; rowIndex < rows; rowIndex++) {
            [glyphs addObject:[self randomGlyph]];
        }

        CGFloat baseSpeed = SSRandomFloatBetween(1.5, 3.5);

        NSMutableDictionary *column = [@{
            @"glyphs" : glyphs,
            @"offset" : @(SSRandomFloatBetween(0, self.characterHeight)),
            @"speed" : @(baseSpeed)
        } mutableCopy];

        [self.columns addObject:column];
    }
}

- (NSString *)randomGlyph
{
    NSUInteger index = arc4random_uniform((uint32_t)self.glyphSet.count);
    return self.glyphSet[index];
}

@end

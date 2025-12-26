//
//  MatrixView.m
//  Matrix
//
//  Created by Yousef Jawdat on 26/12/2025.
//

#import "MatrixView.h"
#import <math.h>

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

        _fadeLength = isPreview ? 10 : 18;

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
        self.lastWidth = frame.size.width;
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

    CGFloat widthDelta = fabs(self.bounds.size.width - self.lastWidth);
    NSInteger expectedColumns = MAX(1, (NSInteger)(self.bounds.size.width / self.characterWidth));
    if (expectedColumns != self.columnCount || widthDelta > self.characterWidth) {
        [self resetColumns];
    }

    NSColor *backgroundTint = [NSColor colorWithCalibratedRed:0.02 green:0.08 blue:0.05 alpha:1.0];
    [backgroundTint set];
    NSRectFill(rect);

    NSColor *haze = [NSColor colorWithCalibratedRed:0.0 green:0.22 blue:0.13 alpha:0.08];
    [haze set];
    NSRectFill(rect);

    for (NSInteger columnIndex = 0; columnIndex < self.columns.count; columnIndex++) {
        NSMutableDictionary *column = self.columns[columnIndex];
        NSMutableArray<NSString *> *glyphs = column[@"glyphs"];
        CGFloat offset = [column[@"offset"] doubleValue];
        CGFloat speed = [column[@"speed"] doubleValue];

        NSInteger rows = glyphs.count;
        CGFloat x = [column[@"x"] doubleValue];
        BOOL thick = [column[@"thick"] boolValue];
        CGFloat jitter = [column[@"xJitter"] doubleValue];

        jitter = MIN(MAX(jitter + SSRandomFloatBetween(-0.1, 0.1), -1.25), 1.25);
        column[@"xJitter"] = @(jitter);

        for (NSInteger row = 0; row < rows; row++) {
            CGFloat y = self.bounds.size.height - ((row + 1) * self.characterHeight) + offset;

            if (y < -self.characterHeight || y > self.bounds.size.height + self.characterHeight) {
                continue;
            }

            NSString *glyph = glyphs[row];
            NSDictionary *attributes = [self attributesForRow:row];

            if (row == 0) {
                [self drawHeadGlyph:glyph atPoint:NSMakePoint(x + jitter, y) withAttributes:attributes];
                if (thick) {
                    CGFloat altX = x + jitter + SSRandomFloatBetween(-2.0, 2.0);
                    [self drawHeadGlyph:glyph atPoint:NSMakePoint(altX, y) withAttributes:attributes];
                }
            } else {
                [glyph drawAtPoint:NSMakePoint(x + jitter, y) withAttributes:attributes];
                if (thick) {
                    CGFloat altX = x + jitter + SSRandomFloatBetween(-2.0, 2.0);
                    [glyph drawAtPoint:NSMakePoint(altX, y) withAttributes:attributes];
                }
            }
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
    self.lastWidth = width;

    CGFloat minGap = self.characterWidth * 0.55;
    CGFloat maxGap = self.characterWidth * 1.45;

    CGFloat startX = SSRandomFloatBetween(self.characterWidth * 0.2, self.characterWidth * 1.5);
    NSMutableArray<NSNumber *> *positions = [NSMutableArray array];
    while (startX < width - self.characterWidth) {
        [positions addObject:@(startX)];
        startX += SSRandomFloatBetween(minGap, maxGap);
    }

    self.columnCount = positions.count;

    NSInteger rows = (NSInteger)(self.bounds.size.height / self.characterHeight) + self.fadeLength + 4;

    self.columns = [NSMutableArray arrayWithCapacity:self.columnCount];

    for (NSInteger columnIndex = 0; columnIndex < self.columnCount; columnIndex++) {
        NSMutableArray<NSString *> *glyphs = [NSMutableArray arrayWithCapacity:rows];
        for (NSInteger rowIndex = 0; rowIndex < rows; rowIndex++) {
            [glyphs addObject:[self randomGlyph]];
        }

        CGFloat baseSpeed = SSRandomFloatBetween(2.0, 6.0) * (self.characterHeight / 18.0);

        NSMutableDictionary *column = [@{
            @"glyphs" : glyphs,
            @"offset" : @(SSRandomFloatBetween(0, self.characterHeight)),
            @"speed" : @(baseSpeed),
            @"x" : positions[columnIndex],
            @"thick" : @(SSRandomIntBetween(0, 4) == 0),
            @"xJitter" : @(SSRandomFloatBetween(-0.8, 0.8))
        } mutableCopy];

        [self.columns addObject:column];
    }
}

- (NSString *)randomGlyph
{
    NSUInteger index = arc4random_uniform((uint32_t)self.glyphSet.count);
    return self.glyphSet[index];
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesForRow:(NSInteger)row
{
    if (row == 0) {
        return self.headAttributes;
    }

    NSMutableDictionary<NSAttributedStringKey, id> *attributes = [self.glyphAttributes mutableCopy];

    NSColor *baseTrailColor = self.glyphAttributes[NSForegroundColorAttributeName];
    CGFloat relativeFadeIndex = MAX(0, row - 1);
    CGFloat fadeProgress = MIN(1.0, relativeFadeIndex / (CGFloat)self.fadeLength);
    CGFloat alphaFactor = pow((1.0 - fadeProgress), 2.2) * 0.9 + 0.05;

    attributes[NSForegroundColorAttributeName] = [baseTrailColor colorWithAlphaComponent:(baseTrailColor.alphaComponent * alphaFactor)];

    return attributes;
}

- (void)drawHeadGlyph:(NSString *)glyph atPoint:(NSPoint)point withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    NSColor *headColor = attributes[NSForegroundColorAttributeName];

    [NSGraphicsContext saveGraphicsState];
    NSShadow *glow = [[NSShadow alloc] init];
    glow.shadowBlurRadius = 14.0;
    glow.shadowOffset = NSZeroSize;
    glow.shadowColor = [headColor colorWithAlphaComponent:0.85];
    [glow set];
    [glyph drawAtPoint:point withAttributes:attributes];
    [NSGraphicsContext restoreGraphicsState];

    NSDictionary *punchAttributes = @{
        NSFontAttributeName : attributes[NSFontAttributeName],
        NSForegroundColorAttributeName : [headColor colorWithAlphaComponent:0.65]
    };

    [glyph drawAtPoint:point withAttributes:punchAttributes];
}

@end

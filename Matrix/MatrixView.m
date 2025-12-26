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
        _characterHeight = _matrixFont.ascender - _matrixFont.descender + _matrixFont.leading;

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

        self.lastWidth = frame.size.width;
        self.lastFrameTimestamp = 0;
        self.wantsLayer = YES;
        [self updateBackingScaleFactor];
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

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self updateBackingScaleFactor];
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
        
        NSInteger rows = glyphs.count;
        CGFloat x = [column[@"x"] doubleValue];
        BOOL thick = [column[@"thick"] boolValue];
        CGFloat jitter = [column[@"xJitter"] doubleValue];

        for (NSInteger row = 0; row < rows; row++) {
            CGFloat y = self.bounds.size.height - ((row + 1) * self.characterHeight) + offset;

            if (y > self.bounds.size.height + self.characterHeight) {
                continue;
            }

            if (y < -self.characterHeight) {
                break;
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

        column[@"xJitter"] = @(jitter);
    }
}

- (void)animateOneFrame
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval delta = self.lastFrameTimestamp > 0 ? now - self.lastFrameTimestamp : 1.0 / 30.0;
    self.lastFrameTimestamp = now;

    [self updateColumnsWithDeltaTime:delta];

    [super animateOneFrame];
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
    self.columnPositions = positions;

    self.rowsPerColumn = (NSInteger)(self.bounds.size.height / self.characterHeight) + self.fadeLength + 4;

    self.columns = [NSMutableArray arrayWithCapacity:self.columnCount];
    self.nextColumnIndex = 0;
    self.columnSpawnAccumulator = 0;
    self.columnSpawnDelay = [self randomColumnSpawnDelay];

    if (self.columnCount > 0) {
        [self addNextColumn];
    }

    [self rebuildFadeAttributes];
}

- (NSString *)randomGlyph
{
    NSUInteger index = arc4random_uniform((uint32_t)self.glyphSet.count);
    return self.glyphSet[index];
}

- (NSTimeInterval)randomColumnSpawnDelay
{
    return SSRandomFloatBetween(0.05, 0.22);
}

- (NSMutableDictionary *)buildColumnAtX:(CGFloat)x
{
    NSMutableArray<NSString *> *glyphs = [NSMutableArray arrayWithCapacity:self.rowsPerColumn];
    for (NSInteger rowIndex = 0; rowIndex < self.rowsPerColumn; rowIndex++) {
        [glyphs addObject:[self randomGlyph]];
    }

    CGFloat baseSpeed = SSRandomFloatBetween(60.0, 180.0) * (self.characterHeight / 18.0);

    NSMutableDictionary *column = [@{
        @"glyphs" : glyphs,
        @"offset" : @(SSRandomFloatBetween(0, self.characterHeight)),
        @"speed" : @(baseSpeed),
        @"x" : @(x),
        @"thick" : @(SSRandomIntBetween(0, 4) == 0),
        @"xJitter" : @(SSRandomFloatBetween(-0.8, 0.8))
    } mutableCopy];

    return column;
}

- (void)addNextColumn
{
    if (self.nextColumnIndex >= self.columnPositions.count) {
        return;
    }

    CGFloat x = [self.columnPositions[self.nextColumnIndex] doubleValue];
    [self.columns addObject:[self buildColumnAtX:x]];
    self.nextColumnIndex += 1;
}

- (void)spawnColumnsWithDeltaTime:(NSTimeInterval)delta
{
    if (self.nextColumnIndex >= self.columnPositions.count) {
        return;
    }

    self.columnSpawnAccumulator += delta;

    while (self.columnSpawnAccumulator >= self.columnSpawnDelay && self.nextColumnIndex < self.columnPositions.count) {
        self.columnSpawnAccumulator -= self.columnSpawnDelay;
        [self addNextColumn];
        self.columnSpawnDelay = [self randomColumnSpawnDelay];
    }
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesForRow:(NSInteger)row
{
    if (row == 0) {
        return self.headAttributes;
    }

    NSInteger index = MIN((NSInteger)self.fadeAttributes.count - 1, MAX(0, row - 1));
    return self.fadeAttributes[index];
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

- (void)updateColumnsWithDeltaTime:(NSTimeInterval)delta
{
    if (delta <= 0) {
        return;
    }

    [self spawnColumnsWithDeltaTime:delta];

    for (NSMutableDictionary *column in self.columns) {
        CGFloat offset = [column[@"offset"] doubleValue];
        CGFloat speed = [column[@"speed"] doubleValue];
        NSMutableArray<NSString *> *glyphs = column[@"glyphs"];

        offset += speed * delta;

        while (offset >= self.characterHeight) {
            offset -= self.characterHeight;
            [glyphs insertObject:[self randomGlyph] atIndex:0];
            [glyphs removeLastObject];
        }

        CGFloat jitter = [column[@"xJitter"] doubleValue];
        jitter = MIN(MAX(jitter + SSRandomFloatBetween(-0.1, 0.1), -1.25), 1.25);

        column[@"offset"] = @(offset);
        column[@"xJitter"] = @(jitter);
    }
}

- (void)rebuildFadeAttributes
{
    NSMutableArray<NSDictionary<NSAttributedStringKey, id> *> *attributes = [NSMutableArray arrayWithCapacity:self.fadeLength + 1];
    NSColor *baseTrailColor = self.glyphAttributes[NSForegroundColorAttributeName];

    for (NSInteger fadeIndex = 0; fadeIndex <= self.fadeLength; fadeIndex++) {
        CGFloat fadeProgress = MIN(1.0, fadeIndex / (CGFloat)self.fadeLength);
        CGFloat alphaFactor = pow((1.0 - fadeProgress), 2.2) * 0.9 + 0.05;

        NSDictionary *entry = @{ NSFontAttributeName : self.matrixFont,
                                 NSForegroundColorAttributeName : [baseTrailColor colorWithAlphaComponent:(baseTrailColor.alphaComponent * alphaFactor)] };
        [attributes addObject:entry];
    }

    self.fadeAttributes = attributes;
}

- (void)updateBackingScaleFactor
{
    if (!self.wantsLayer) {
        return;
    }

    CGFloat scale = self.window.backingScaleFactor ?: NSScreen.mainScreen.backingScaleFactor;
    self.layer.contentsScale = scale;
}

@end

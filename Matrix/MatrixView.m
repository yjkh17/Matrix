//
//  MatrixView.m
//  Matrix
//
//  Created by Yousef Jawdat on 26/12/2025.
//

#import "MatrixView.h"
#import <math.h>

@interface MatrixView ()

@property (nonatomic, strong) NSFont *matrixFont;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *glyphAttributes;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *headAttributes;
@property (nonatomic, strong) NSArray<NSDictionary<NSAttributedStringKey, id> *> *fadeAttributes;

@property (nonatomic, assign) CGFloat characterWidth;
@property (nonatomic, assign) CGFloat characterHeight;
@property (nonatomic, assign) NSTimeInterval lastFrameTimestamp;
@property (nonatomic, assign) NSInteger rowsPerColumn;

@property (nonatomic, strong) NSArray<NSString *> *glyphSet;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *columns;
@property (nonatomic, strong) NSArray<NSNumber *> *columnPositions;
@property (nonatomic, assign) NSInteger nextColumnIndex;
@property (nonatomic, assign) NSTimeInterval columnSpawnAccumulator;
@property (nonatomic, assign) NSTimeInterval columnSpawnDelay;
@property (nonatomic, assign) NSInteger fadeLength;
@property (nonatomic, strong) NSShadow *headGlowShadow;
@property (nonatomic, strong) NSImage *frameBuffer;

- (void)resetColumns;
- (NSString *)randomGlyph;
- (NSArray<NSDictionary<NSAttributedStringKey, id> *> *)buildFadeAttributesWithLength:(NSInteger)length;
- (void)ensureFrameBuffer;
- (void)renderFrame;

@end

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

        NSColor *primaryGreen = [NSColor colorWithCalibratedRed:0.08 green:1.0 blue:0.62 alpha:0.95];
        NSColor *trailGreen = [NSColor colorWithCalibratedRed:0.04 green:0.94 blue:0.48 alpha:0.72];

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

        self.lastFrameTimestamp = 0;
        self.wantsLayer = YES;
        [self updateBackingScaleFactor];
        [self resetColumns];

        _headGlowShadow = [[NSShadow alloc] init];
        _headGlowShadow.shadowBlurRadius = 14.0;
        _headGlowShadow.shadowOffset = NSZeroSize;
    }
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
    [self ensureFrameBuffer];
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
    [self ensureFrameBuffer];

    if (self.frameBuffer) {
        [self.frameBuffer drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    } else {
        [[NSColor blackColor] set];
        NSRectFill(self.bounds);
    }
}

- (void)animateOneFrame
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval delta = self.lastFrameTimestamp > 0 ? now - self.lastFrameTimestamp : 1.0 / 30.0;
    self.lastFrameTimestamp = now;

    [self ensureFrameBuffer];
    if (!self.frameBuffer) {
        return;
    }

    [self updateColumnsWithDeltaTime:delta];

    [self renderFrame];

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
    CGFloat height = self.bounds.size.height;

    CGFloat minGap = self.characterWidth * 0.15;
    CGFloat maxGap = self.characterWidth * 1.1;

    CGFloat startX = SSRandomFloatBetween(self.characterWidth * 0.1, self.characterWidth * 1.0);
    NSMutableArray<NSNumber *> *positions = [NSMutableArray array];
    while (startX < width - self.characterWidth * 0.3) {
        [positions addObject:@(startX)];
        CGFloat gap = SSRandomFloatBetween(minGap, maxGap);

        if (SSRandomIntBetween(0, 7) == 0) {
            CGFloat overlapAdjustment = self.characterWidth * SSRandomFloatBetween(0.1, 0.65);
            gap = MAX(self.characterWidth * 0.08, gap - overlapAdjustment);
        }

        startX += gap;
    }

    NSInteger columnCount = positions.count;
    self.columnPositions = positions;

    NSInteger maxFadeLength = self.fadeLength + 8;
    self.rowsPerColumn = (NSInteger)(height / self.characterHeight) + maxFadeLength + 6;

    self.columns = [NSMutableArray arrayWithCapacity:columnCount];
    self.nextColumnIndex = 0;
    self.columnSpawnAccumulator = 0;
    self.columnSpawnDelay = [self randomColumnSpawnDelay];

    if (columnCount > 0) {
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
    return SSRandomFloatBetween(0.03, 0.16);
}

- (void)ensureFrameBuffer
{
    NSSize currentSize = self.bounds.size;
    if (currentSize.width <= 0 || currentSize.height <= 0) {
        self.frameBuffer = nil;
        return;
    }

    BOOL sizeChanged = !NSEqualSizes(self.frameBuffer.size, currentSize);

    if (!self.frameBuffer || sizeChanged) {
        self.frameBuffer = [[NSImage alloc] initWithSize:currentSize];
        [self.frameBuffer lockFocus];
        NSGradient *deepGreenGradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.01 green:0.1 blue:0.05 alpha:1.0]
                                                                      endingColor:[NSColor colorWithCalibratedRed:0.04 green:0.16 blue:0.08 alpha:1.0]];
        [deepGreenGradient drawInRect:NSMakeRect(0, 0, currentSize.width, currentSize.height) angle:270.0];
        [self.frameBuffer unlockFocus];
        [self resetColumns];
    }
}

- (NSMutableDictionary *)buildColumnAtX:(CGFloat)x
{
    NSMutableArray<NSString *> *glyphs = [NSMutableArray arrayWithCapacity:self.rowsPerColumn];
    for (NSInteger rowIndex = 0; rowIndex < self.rowsPerColumn; rowIndex++) {
        [glyphs addObject:[self randomGlyph]];
    }

    CGFloat baseSpeed = SSRandomFloatBetween(28.0, 260.0) * (self.characterHeight / 18.0);
    if (SSRandomIntBetween(0, 4) == 0) {
        baseSpeed *= SSRandomFloatBetween(0.45, 0.85);
    }

    NSInteger fadeLength = MAX(4, self.fadeLength + SSRandomIntBetween(-6, 8));
    NSArray<NSDictionary<NSAttributedStringKey, id> *> *fadeAttributes = [self buildFadeAttributesWithLength:fadeLength];

    NSMutableDictionary *column = [@{
        @"glyphs" : glyphs,
        @"offset" : @(SSRandomFloatBetween(0, self.characterHeight)),
        @"speed" : @(baseSpeed),
        @"x" : @(x),
        @"thick" : @(SSRandomIntBetween(0, 4) == 0),
        @"xJitter" : @(SSRandomFloatBetween(-0.8, 0.8)),
        @"altXOffset" : @(SSRandomFloatBetween(-2.0, 2.0)),
        @"fadeLength" : @(fadeLength),
        @"fadeAttributes" : fadeAttributes
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

- (void)renderFrame
{
    if (!self.frameBuffer) {
        return;
    }

    [self.frameBuffer lockFocus];

    NSRect imageRect = NSMakeRect(0, 0, self.frameBuffer.size.width, self.frameBuffer.size.height);

    [[NSColor colorWithCalibratedRed:0.02 green:0.1 blue:0.06 alpha:0.08] set];
    NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceOver);

    CGFloat bufferHeight = self.frameBuffer.size.height;

    for (NSInteger columnIndex = 0; columnIndex < self.columns.count; columnIndex++) {
        NSMutableDictionary *column = self.columns[columnIndex];
        NSMutableArray<NSString *> *glyphs = column[@"glyphs"];
        CGFloat offset = [column[@"offset"] doubleValue];

        NSInteger rows = glyphs.count;
        CGFloat x = [column[@"x"] doubleValue];
        BOOL thick = [column[@"thick"] boolValue];
        CGFloat jitter = [column[@"xJitter"] doubleValue];
        CGFloat altOffset = [column[@"altXOffset"] doubleValue];

        for (NSInteger row = 0; row < rows; row++) {
            CGFloat y = bufferHeight - ((row + 1) * self.characterHeight) + offset;

            if (y > bufferHeight + self.characterHeight) {
                continue;
            }

            if (y < -self.characterHeight) {
                break;
            }

            NSString *glyph = glyphs[row];
            NSDictionary *attributes = [self attributesForRow:row inColumn:column];

            if (!attributes) {
                continue;
            }

            if (row == 0) {
                [self drawHeadGlyph:glyph atPoint:NSMakePoint(x + jitter, y) withAttributes:attributes];
                if (thick) {
                    CGFloat altX = x + jitter + altOffset;
                    [self drawHeadGlyph:glyph atPoint:NSMakePoint(altX, y) withAttributes:attributes];
                }
            } else {
                [glyph drawAtPoint:NSMakePoint(x + jitter, y) withAttributes:attributes];
                if (thick) {
                    CGFloat altX = x + jitter + altOffset;
                    [glyph drawAtPoint:NSMakePoint(altX, y) withAttributes:attributes];
                }
            }
        }

    }

    [self.frameBuffer unlockFocus];
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

- (NSDictionary<NSAttributedStringKey, id> *)attributesForRow:(NSInteger)row inColumn:(NSDictionary *)column
{
    if (row == 0) {
        return self.headAttributes;
    }

    NSInteger fadeIndex = row - 1;

    NSInteger columnFadeLength = [column[@"fadeLength"] integerValue];
    NSArray<NSDictionary<NSAttributedStringKey, id> *> *columnFadeAttributes = column[@"fadeAttributes"] ?: self.fadeAttributes;

    if (fadeIndex > columnFadeLength) {
        return nil;
    }

    NSInteger clampedIndex = MIN((NSInteger)columnFadeAttributes.count - 1, MAX(0, fadeIndex));
    return columnFadeAttributes[clampedIndex];
}

- (void)drawHeadGlyph:(NSString *)glyph atPoint:(NSPoint)point withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    NSColor *headColor = attributes[NSForegroundColorAttributeName];

    CGFloat bufferHeight = self.frameBuffer.size.height;
    CGFloat freshness = 0.0;
    if (bufferHeight > 0) {
        CGFloat headOffset = point.y - (bufferHeight - self.characterHeight);
        headOffset = MAX(0.0, MIN(self.characterHeight, headOffset));
        freshness = 1.0 - (headOffset / self.characterHeight);
    }

    CGFloat pulse = MAX(0.0, (sin(self.lastFrameTimestamp * 10.0) + 1.0) * 0.5 * freshness);
    CGFloat glowAlpha = 0.35 + 0.35 * pulse;

    NSPoint glowCenter = NSMakePoint(point.x + self.characterWidth * 0.5, point.y + self.characterHeight * 0.5);
    CGFloat glowRadiusX = self.characterWidth * 2.1;
    CGFloat glowRadiusY = self.characterHeight * 2.1;
    NSRect glowRect = NSMakeRect(glowCenter.x - glowRadiusX * 0.5,
                                 glowCenter.y - glowRadiusY * 0.5,
                                 glowRadiusX,
                                 glowRadiusY);

    NSGradient *headGlow = [[NSGradient alloc] initWithStartingColor:[headColor colorWithAlphaComponent:glowAlpha]
                                                        endingColor:[headColor colorWithAlphaComponent:0.02]];
    [headGlow drawInRect:glowRect relativeCenterPosition:NSZeroPoint];

    CGFloat highlightAlpha = 0.12 + 0.28 * pulse;
    if (highlightAlpha > 0.0) {
        NSGradient *pulseGradient = [[NSGradient alloc] initWithStartingColor:[[NSColor whiteColor] colorWithAlphaComponent:highlightAlpha]
                                                                 endingColor:[headColor colorWithAlphaComponent:0.0]];
        [pulseGradient drawInRect:NSInsetRect(glowRect, -self.characterWidth * 0.2, -self.characterHeight * 0.2)
             relativeCenterPosition:NSZeroPoint];
    }

    NSFont *baseFont = attributes[NSFontAttributeName];
    NSFont *sizedFont = [baseFont fontWithSize:baseFont.pointSize * 1.05];
    NSFont *boldFont = [[NSFontManager sharedFontManager] convertFont:sizedFont toHaveTrait:NSBoldFontMask] ?: sizedFont;

    NSColor *emphasizedColor = [headColor blendedColorWithFraction:(0.18 + 0.3 * pulse) ofColor:[NSColor whiteColor]];

    NSMutableDictionary<NSAttributedStringKey, id> *emphasizedAttributes = [attributes mutableCopy];
    emphasizedAttributes[NSFontAttributeName] = boldFont;
    emphasizedAttributes[NSForegroundColorAttributeName] = emphasizedColor ?: headColor;

    [NSGraphicsContext saveGraphicsState];
    self.headGlowShadow.shadowColor = [headColor colorWithAlphaComponent:MIN(1.0, 0.85 + 0.3 * pulse)];
    [self.headGlowShadow set];
    [glyph drawAtPoint:NSMakePoint(point.x, point.y) withAttributes:emphasizedAttributes];
    [NSGraphicsContext restoreGraphicsState];

    NSDictionary *punchAttributes = @{
        NSFontAttributeName : boldFont,
        NSForegroundColorAttributeName : [headColor colorWithAlphaComponent:0.65 + 0.2 * pulse]
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
    self.fadeAttributes = [self buildFadeAttributesWithLength:self.fadeLength];
}

- (NSArray<NSDictionary<NSAttributedStringKey, id> *> *)buildFadeAttributesWithLength:(NSInteger)length
{
    NSMutableArray<NSDictionary<NSAttributedStringKey, id> *> *attributes = [NSMutableArray arrayWithCapacity:length + 1];
    NSColor *baseTrailColor = self.glyphAttributes[NSForegroundColorAttributeName];

    for (NSInteger fadeIndex = 0; fadeIndex <= length; fadeIndex++) {
        CGFloat fadeProgress = MIN(1.0, fadeIndex / (CGFloat)length);
        CGFloat alphaFactor = pow((1.0 - fadeProgress), 2.2) * 0.9 + 0.05;

        NSDictionary *entry = @{ NSFontAttributeName : self.matrixFont,
                                 NSForegroundColorAttributeName : [baseTrailColor colorWithAlphaComponent:(baseTrailColor.alphaComponent * alphaFactor)] };
        [attributes addObject:entry];
    }

    return attributes;
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

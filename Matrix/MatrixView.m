//
//  MatrixView.m
//  Matrix
//
//  Created by Yousef Jawdat on 26/12/2025.
//

#import "MatrixView.h"
#import <math.h>

static const NSTimeInterval kGlyphFadeDuration = 2.25;
static const CGFloat kMinimumVisibleOpacity = 0.02;

@interface MatrixView ()

@property (nonatomic, strong) NSFont *matrixFont;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *glyphAttributes;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *headAttributes;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *tailGlowAttributes;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *tailDimAttributes;

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
@property (nonatomic, strong) NSImage *frameBuffer;

- (void)resetColumns;
- (NSString *)randomGlyph;
- (NSArray<NSString *> *)buildWeightedGlyphSet;
- (NSTimeInterval)randomGlyphDwellTime;
- (NSTimeInterval)randomHeadGlyphDwellTime;
- (NSTimeInterval)randomRowGlyphDwellTime;
- (NSTimeInterval)fadeDurationForBaseSpeed:(CGFloat)baseSpeed;
- (void)ensureFrameBuffer;
- (void)renderFrame;
- (NSMutableDictionary *)rowStateWithGlyph:(NSString *)glyph opacity:(CGFloat)opacity age:(NSTimeInterval)age;
- (void)spawnGlyphInColumn:(NSMutableDictionary *)column;

@end

@implementation MatrixView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/30.0];

        _matrixFont = [NSFont monospacedSystemFontOfSize:isPreview ? 18.0 : 26.0 weight:NSFontWeightRegular];

        NSDictionary *sizingAttributes = @{ NSFontAttributeName : _matrixFont };
        _characterWidth = [@"0" sizeWithAttributes:sizingAttributes].width + 1.0;
        _characterHeight = _matrixFont.ascender - _matrixFont.descender + _matrixFont.leading;

        NSColor *primaryGreen = [NSColor colorWithCalibratedRed:0.65 green:1.0 blue:0.45 alpha:1.0];
        NSColor *trailGreen = [NSColor colorWithCalibratedRed:0.0 green:0.95 blue:0.45 alpha:1.0];
        NSColor *tailGlow = [NSColor colorWithCalibratedRed:0.85 green:1.0 blue:0.85 alpha:1.0];
        NSColor *tailDim = [NSColor colorWithCalibratedRed:0.55 green:0.9 blue:0.55 alpha:1.0];

        _glyphAttributes = @{ NSFontAttributeName : _matrixFont,
                              NSForegroundColorAttributeName : trailGreen };

        NSShadow *headGlow = [[NSShadow alloc] init];
        headGlow.shadowColor = [primaryGreen colorWithAlphaComponent:0.85];
        headGlow.shadowBlurRadius = 8.0;
        headGlow.shadowOffset = NSZeroSize;

        _headAttributes = @{ NSFontAttributeName : _matrixFont,
                             NSForegroundColorAttributeName : primaryGreen,
                             NSShadowAttributeName : headGlow };

        NSShadow *brightTailGlow = [[NSShadow alloc] init];
        brightTailGlow.shadowColor = [tailGlow colorWithAlphaComponent:0.75];
        brightTailGlow.shadowBlurRadius = 10.0;
        brightTailGlow.shadowOffset = NSZeroSize;

        _tailGlowAttributes = @{ NSFontAttributeName : _matrixFont,
                                 NSForegroundColorAttributeName : tailGlow,
                                 NSShadowAttributeName : brightTailGlow };

        NSShadow *dimTailGlow = [[NSShadow alloc] init];
        dimTailGlow.shadowColor = [tailDim colorWithAlphaComponent:0.6];
        dimTailGlow.shadowBlurRadius = 6.0;
        dimTailGlow.shadowOffset = NSZeroSize;

        _tailDimAttributes = @{ NSFontAttributeName : _matrixFont,
                                NSForegroundColorAttributeName : tailDim,
                                NSShadowAttributeName : dimTailGlow };

        _glyphSet = [self buildWeightedGlyphSet];

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

    CGFloat spacing = self.characterWidth * 1.1;
    NSInteger columnCount = MAX(1, (NSInteger)floor(width / spacing));
    CGFloat totalWidth = (columnCount - 1) * spacing;
    CGFloat xStart = (width - totalWidth) * 0.5;

    NSMutableArray<NSNumber *> *positions = [NSMutableArray arrayWithCapacity:columnCount];
    for (NSInteger columnIndex = 0; columnIndex < columnCount; columnIndex++) {
        CGFloat x = xStart + (spacing * columnIndex);
        x = MIN(MAX(self.characterWidth * 0.5, x), width - self.characterWidth * 1.5);
        [positions addObject:@(x)];
    }

    for (NSInteger index = positions.count - 1; index > 0; index--) {
        NSUInteger swapIndex = arc4random_uniform((uint32_t)(index + 1));
        [positions exchangeObjectAtIndex:index withObjectAtIndex:swapIndex];
    }

    self.columnPositions = positions;

    self.rowsPerColumn = (NSInteger)ceil(height / self.characterHeight) + 4;

    self.columns = [NSMutableArray arrayWithCapacity:columnCount];
    self.nextColumnIndex = 0;
    self.columnSpawnAccumulator = 0;
    self.columnSpawnDelay = [self randomColumnSpawnDelay];

    if (columnCount > 0) {
        [self addNextColumn];
    }
}

- (NSString *)randomGlyph
{
    if (self.glyphSet.count == 0) {
        return @"";
    }

    NSUInteger index = arc4random_uniform((uint32_t)self.glyphSet.count);
    return self.glyphSet[index];
}

- (NSArray<NSString *> *)buildWeightedGlyphSet
{
    NSArray<NSString *> *primaryKatakana = @[ @"ｱ", @"ｲ", @"ｳ", @"ｴ", @"ｵ", @"ｶ", @"ｷ", @"ｸ", @"ｹ", @"ｺ",
                                              @"ｻ", @"ｼ", @"ｽ", @"ｾ", @"ｿ", @"ﾀ", @"ﾁ", @"ﾂ", @"ﾃ", @"ﾄ",
                                              @"ﾅ", @"ﾆ", @"ﾇ", @"ﾈ", @"ﾉ", @"ﾊ", @"ﾋ", @"ﾌ", @"ﾍ", @"ﾎ",
                                              @"ﾏ", @"ﾐ", @"ﾑ", @"ﾒ", @"ﾓ", @"ﾔ", @"ﾕ", @"ﾖ", @"ﾗ", @"ﾘ",
                                              @"ﾙ", @"ﾚ", @"ﾛ", @"ﾜ", @"ﾝ" ];

    NSArray<NSString *> *smallKatakana = @[ @"ｧ", @"ｨ", @"ｩ", @"ｪ", @"ｫ", @"ｯ", @"ｰ" ];
    NSArray<NSString *> *numerals = @[ @"0", @"1", @"2", @"3", @"4", @"5", @"7", @"8", @"9" ];
    NSArray<NSString *> *punctuation = @[ @"＋", @"－", @"＝", @"＊", @"／", @"・", @"･", @"◎", @"◇", @"◆", @"○", @"●", @"|", @"¦" ];

    NSMutableArray<NSString *> *weightedGlyphs = [NSMutableArray array];

    void (^appendGlyphs)(NSArray<NSString *> *, NSInteger) = ^(NSArray<NSString *> *glyphs, NSInteger weight) {
        if (weight <= 0) {
            return;
        }

        for (NSString *glyph in glyphs) {
            for (NSInteger index = 0; index < weight; index++) {
                [weightedGlyphs addObject:glyph];
            }
        }
    };

    // The weights below mirror the observed frequency of glyph families in the source material.
    appendGlyphs(primaryKatakana, 6);   // Dominant katakana stream characters.
    appendGlyphs(smallKatakana, 3);     // Less frequent small kana and prolonged sound mark.
    appendGlyphs(@[ @"日" ], 5);       // Standout kanji seen regularly in the rain.
    appendGlyphs(@[ @"Z" ], 2);        // Occasional Latin glyphs.
    appendGlyphs(numerals, 4);          // Numerals (notably excluding 6).
    appendGlyphs(punctuation, 1);       // Sparse punctuation and symbols.

    return weightedGlyphs;
}

- (NSTimeInterval)randomColumnSpawnDelay
{
    return SSRandomFloatBetween(0.12, 0.38);
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
        [[NSColor colorWithCalibratedRed:0.01 green:0.03 blue:0.015 alpha:1.0] set];
        NSRectFill(NSMakeRect(0, 0, currentSize.width, currentSize.height));
        [self.frameBuffer unlockFocus];
        [self resetColumns];
    }
}

- (NSMutableDictionary *)buildColumnAtX:(CGFloat)x
{
    CGFloat baseSpeed = SSRandomFloatBetween(50.0, 120.0) * (self.characterHeight / 18.0);
    NSTimeInterval fadeDuration = [self fadeDurationForBaseSpeed:baseSpeed];
    NSTimeInterval spawnInterval = MAX(0.03, self.characterHeight / baseSpeed);

    NSMutableArray<NSMutableDictionary *> *rows = [NSMutableArray arrayWithCapacity:self.rowsPerColumn];
    for (NSInteger rowIndex = 0; rowIndex < self.rowsPerColumn; rowIndex++) {
        [rows addObject:[self rowStateWithGlyph:[self randomGlyph] opacity:0 age:fadeDuration]];
    }

    NSMutableDictionary *column = [@{
        @"rows" : rows,
        @"headIndex" : @(-1),
        @"spawnAccumulator" : @(SSRandomFloatBetween(0, spawnInterval)),
        @"spawnInterval" : @(spawnInterval),
        @"headGlyphDwell" : @([self randomHeadGlyphDwellTime]),
        @"headGlyphDwellAccumulator" : @(0),
        @"baseSpeed" : @(baseSpeed),
        @"fadeDuration" : @(fadeDuration),
        @"x" : @(x)
    } mutableCopy];

    NSInteger warmupSteps = arc4random_uniform((uint32_t)MIN(self.rowsPerColumn, 6));
    for (NSInteger step = 0; step < warmupSteps; step++) {
        [self spawnGlyphInColumn:column];
    }

    return column;
}

- (NSMutableDictionary *)rowStateWithGlyph:(NSString *)glyph opacity:(CGFloat)opacity age:(NSTimeInterval)age
{
    return [@{ @"glyph" : glyph ?: @"",
               @"opacity" : @(opacity),
               @"age" : @(age),
               @"dwellAccumulator" : @(0),
               @"dwellDuration" : @([self randomRowGlyphDwellTime]) } mutableCopy];
}

- (void)spawnGlyphInColumn:(NSMutableDictionary *)column
{
    if (!column) {
        return;
    }

    NSMutableArray<NSMutableDictionary *> *rows = column[@"rows"];
    if (rows.count == 0) {
        return;
    }

    NSInteger headIndex = [column[@"headIndex"] integerValue];
    headIndex = (headIndex + 1) % rows.count;

    NSMutableDictionary *rowState = rows[headIndex];
    rowState[@"glyph"] = [self randomGlyph];
    rowState[@"age"] = @(0);
    rowState[@"opacity"] = @(1.0);
    rowState[@"dwellAccumulator"] = @(0);
    rowState[@"dwellDuration"] = @([self randomRowGlyphDwellTime]);

    column[@"headIndex"] = @(headIndex);
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

    [[NSColor blackColor] set];
    NSRectFill(imageRect);

    CGFloat bufferHeight = self.frameBuffer.size.height;

    for (NSInteger columnIndex = 0; columnIndex < self.columns.count; columnIndex++) {
        NSMutableDictionary *column = self.columns[columnIndex];
        NSArray<NSMutableDictionary *> *rows = column[@"rows"];
        NSInteger headIndex = [column[@"headIndex"] integerValue];
        CGFloat x = [column[@"x"] doubleValue];

        NSMutableArray<NSDictionary *> *visibleRows = [NSMutableArray array];

        for (NSInteger row = 0; row < rows.count; row++) {
            NSMutableDictionary *rowState = rows[row];
            CGFloat opacity = [rowState[@"opacity"] doubleValue];

            if (opacity < kMinimumVisibleOpacity) {
                continue;
            }

            CGFloat y = bufferHeight - self.characterHeight - (row * self.characterHeight);

            if (y > bufferHeight + self.characterHeight) {
                continue;
            }

            if (y < -self.characterHeight) {
                break;
            }

            [visibleRows addObject:@{ @"row" : @(row), @"opacity" : @(opacity), @"y" : @(y) }];
        }

        NSInteger glowRowIndex = -1;
        NSInteger dimGlowRowIndex = -1;

        if (visibleRows.count > 0) {
            glowRowIndex = [visibleRows.lastObject[@"row"] integerValue];
        }

        if (visibleRows.count > 1) {
            dimGlowRowIndex = [visibleRows[visibleRows.count - 2][@"row"] integerValue];
        }

        for (NSDictionary *rowInfo in visibleRows) {
            NSInteger row = [rowInfo[@"row"] integerValue];
            CGFloat opacity = [rowInfo[@"opacity"] doubleValue];
            CGFloat y = [rowInfo[@"y"] doubleValue];
            NSMutableDictionary *rowState = rows[row];

            NSString *glyph = rowState[@"glyph"];
            BOOL isHead = (row == headIndex);
            BOOL isGlow = (!isHead && row == glowRowIndex);
            BOOL isDimGlow = (!isHead && row == dimGlowRowIndex);
            NSDictionary *attributes = [self attributesForRow:row opacity:opacity isHead:isHead isGlow:isGlow isDimGlow:isDimGlow];

            if (!attributes) {
                continue;
            }

            if (isHead) {
                [self drawHeadGlyph:glyph atPoint:NSMakePoint(x, y) withAttributes:attributes];
            } else {
                [glyph drawAtPoint:NSMakePoint(x, y) withAttributes:attributes];
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

- (NSDictionary<NSAttributedStringKey, id> *)attributesForRow:(NSInteger)row opacity:(CGFloat)opacity isHead:(BOOL)isHead isGlow:(BOOL)isGlow isDimGlow:(BOOL)isDimGlow
{
    NSDictionary *baseAttributes = self.glyphAttributes;

    if (isHead) {
        baseAttributes = self.headAttributes;
    } else if (isGlow) {
        baseAttributes = self.tailGlowAttributes;
    } else if (isDimGlow) {
        baseAttributes = self.tailDimAttributes;
    }
    NSMutableDictionary *attributes = [baseAttributes mutableCopy];

    NSColor *color = baseAttributes[NSForegroundColorAttributeName];
    if (color) {
        attributes[NSForegroundColorAttributeName] = [color colorWithAlphaComponent:opacity * color.alphaComponent];
    }

    NSShadow *shadow = baseAttributes[NSShadowAttributeName];
    if (shadow) {
        NSShadow *shadowCopy = [shadow copy];
        shadowCopy.shadowColor = [shadow.shadowColor colorWithAlphaComponent:opacity];
        attributes[NSShadowAttributeName] = shadowCopy;
    }

    return attributes;
}

- (void)drawHeadGlyph:(NSString *)glyph atPoint:(NSPoint)point withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    [glyph drawAtPoint:point withAttributes:attributes];
}

- (void)updateColumnsWithDeltaTime:(NSTimeInterval)delta
{
    if (delta <= 0) {
        return;
    }

    [self spawnColumnsWithDeltaTime:delta];

    for (NSInteger columnIndex = 0; columnIndex < self.columns.count; columnIndex++) {
        NSMutableDictionary *column = self.columns[columnIndex];
        NSMutableArray<NSMutableDictionary *> *rows = column[@"rows"];
        NSTimeInterval spawnInterval = [column[@"spawnInterval"] doubleValue];
        NSTimeInterval spawnAccumulator = [column[@"spawnAccumulator"] doubleValue] + delta;
        NSTimeInterval headGlyphDwell = [column[@"headGlyphDwell"] doubleValue];
        NSTimeInterval headGlyphDwellAccumulator = [column[@"headGlyphDwellAccumulator"] doubleValue] + delta;
        NSInteger headIndex = [column[@"headIndex"] integerValue];
        NSTimeInterval fadeDuration = [column[@"fadeDuration"] doubleValue];
        if (fadeDuration <= 0) {
            fadeDuration = kGlyphFadeDuration;
        }

        while (spawnAccumulator >= spawnInterval) {
            spawnAccumulator -= spawnInterval;
            [self spawnGlyphInColumn:column];
            spawnInterval = MAX(0.02, (spawnInterval + [self randomGlyphDwellTime]) * 0.5);
            headIndex = [column[@"headIndex"] integerValue];
        }

        if (headIndex >= 0 && headIndex < rows.count) {
            while (headGlyphDwellAccumulator >= headGlyphDwell) {
                headGlyphDwellAccumulator -= headGlyphDwell;
                rows[headIndex][@"glyph"] = [self randomGlyph];
                headGlyphDwell = [self randomHeadGlyphDwellTime];
            }
        }

        for (NSMutableDictionary *rowState in rows) {
            NSTimeInterval age = [rowState[@"age"] doubleValue];
            CGFloat opacity = [rowState[@"opacity"] doubleValue];
            NSTimeInterval dwellAccumulator = [rowState[@"dwellAccumulator"] doubleValue] + delta;
            NSTimeInterval dwellDuration = [rowState[@"dwellDuration"] doubleValue];

            while (dwellAccumulator >= dwellDuration) {
                dwellAccumulator -= dwellDuration;
                rowState[@"glyph"] = [self randomGlyph];
                dwellDuration = [self randomRowGlyphDwellTime];
            }

            rowState[@"dwellAccumulator"] = @(dwellAccumulator);
            rowState[@"dwellDuration"] = @(dwellDuration);

            if (opacity <= 0.0) {
                rowState[@"age"] = @(MIN(age + delta, fadeDuration));
                continue;
            }

            age += delta;
            opacity = MAX(0.0, 1.0 - (age / fadeDuration));
            rowState[@"age"] = @(age);
            rowState[@"opacity"] = @(opacity);
        }

        column[@"spawnAccumulator"] = @(spawnAccumulator);
        column[@"spawnInterval"] = @(spawnInterval);
        column[@"headGlyphDwell"] = @(headGlyphDwell);
        column[@"headGlyphDwellAccumulator"] = @(headGlyphDwellAccumulator);
    }
}

- (NSTimeInterval)randomGlyphDwellTime
{
    return SSRandomFloatBetween(0.05, 0.16);
}

- (NSTimeInterval)randomHeadGlyphDwellTime
{
    return SSRandomFloatBetween(0.025, 0.08);
}

- (NSTimeInterval)randomRowGlyphDwellTime
{
    return SSRandomFloatBetween(1.0, 2.0);
}

- (NSTimeInterval)fadeDurationForBaseSpeed:(CGFloat)baseSpeed
{
    if (baseSpeed <= 0) {
        return kGlyphFadeDuration;
    }

    CGFloat referenceSpeed = 85.0 * (self.characterHeight / 18.0);
    NSTimeInterval scaledFade = kGlyphFadeDuration * (referenceSpeed / baseSpeed);

    return MAX(0.9, MIN(scaledFade, kGlyphFadeDuration * 1.6));
}

- (void)updateBackingScaleFactor
{
    if (!self.wantsLayer) {
        return;
    }

    CGFloat scale = 1.0;
    if (self.window) {
        scale = self.window.backingScaleFactor ?: scale;
    } else if (NSScreen.mainScreen) {
        scale = NSScreen.mainScreen.backingScaleFactor ?: scale;
    }

    // Some preview contexts provide no backing scale factor; fall back to a sane default
    // so the layer still renders instead of ending up with a zero contentsScale.
    self.layer.contentsScale = MAX(1.0, scale);
}

@end

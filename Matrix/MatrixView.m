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
@property (nonatomic, strong) NSImage *frameBuffer;

- (void)resetColumns;
- (NSString *)randomGlyph;
- (NSArray<NSDictionary<NSAttributedStringKey, id> *> *)buildFadeAttributesWithLength:(NSInteger)length;
- (void)ensureFrameBuffer;
- (void)renderFrame;
- (NSFont *)boldHeadFont;

@end

@implementation MatrixView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/30.0];

        _matrixFont = [NSFont monospacedSystemFontOfSize:isPreview ? 16.0 : 22.0 weight:NSFontWeightRegular];

        NSDictionary *sizingAttributes = @{ NSFontAttributeName : _matrixFont };
        _characterWidth = [@"0" sizeWithAttributes:sizingAttributes].width;
        _characterHeight = _matrixFont.ascender - _matrixFont.descender + _matrixFont.leading;

        _fadeLength = isPreview ? 10 : 18;

        NSColor *primaryGreen = [NSColor colorWithCalibratedRed:0.08 green:1.0 blue:0.6 alpha:1.0];
        NSColor *trailGreen = [NSColor colorWithCalibratedRed:0.04 green:0.9 blue:0.55 alpha:1.0];

        _glyphAttributes = @{ NSFontAttributeName : _matrixFont,
                              NSForegroundColorAttributeName : trailGreen };

        _headAttributes = @{ NSFontAttributeName : _matrixFont,
                             NSForegroundColorAttributeName : primaryGreen };

        _glyphSet = @[ @"ｱ", @"ｲ", @"ｳ", @"ｴ", @"ｵ", @"ｶ", @"ｷ", @"ｸ", @"ｹ", @"ｺ",
                       @"ｻ", @"ｼ", @"ｽ", @"ｾ", @"ｿ", @"ﾀ", @"ﾁ", @"ﾂ", @"ﾃ", @"ﾄ",
                       @"ﾅ", @"ﾆ", @"ﾇ", @"ﾈ", @"ﾉ", @"ﾊ", @"ﾋ", @"ﾌ", @"ﾍ", @"ﾎ",
                       @"ﾏ", @"ﾐ", @"ﾑ", @"ﾒ", @"ﾓ", @"ﾔ", @"ﾕ", @"ﾖ", @"ﾗ", @"ﾘ",
                       @"ﾙ", @"ﾚ", @"ﾛ", @"ﾜ", @"ﾝ", @"ｧ", @"ｨ", @"ｩ", @"ｪ", @"ｫ",
                       @"ｯ", @"ｰ", @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7",
                       @"8", @"9", @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7",
                       @"8", @"9", @"＋", @"－", @"＝", @"＊", @"／", @"・", @"･", @"◎",
                       @"◇", @"◆", @"○", @"●", @"|", @"¦" ];

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

    NSInteger columnCount = 1;
    CGFloat centerX = (width - self.characterWidth) * 0.5;

    NSMutableArray<NSNumber *> *positions = [NSMutableArray arrayWithObject:@(centerX)];

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
        [[NSColor colorWithCalibratedRed:0.01 green:0.03 blue:0.015 alpha:1.0] set];
        NSRectFill(NSMakeRect(0, 0, currentSize.width, currentSize.height));
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

    CGFloat baseSpeed = SSRandomFloatBetween(42.0, 160.0) * (self.characterHeight / 22.0);

    NSInteger fadeLength = MAX(4, self.fadeLength + SSRandomIntBetween(-6, 8));
    NSArray<NSDictionary<NSAttributedStringKey, id> *> *fadeAttributes = [self buildFadeAttributesWithLength:fadeLength];

    CGFloat initialOffset = SSRandomFloatBetween(0, self.characterHeight);

    NSMutableDictionary *column = [@{
        @"glyphs" : glyphs,
        @"offset" : @(initialOffset),
        @"processedRows" : @(floor(initialOffset / self.characterHeight)),
        @"speed" : @(baseSpeed),
        @"x" : @(x),
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

    [[NSColor colorWithCalibratedRed:0.0 green:0.05 blue:0.02 alpha:0.08] set];
    NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceOver);

    CGFloat bufferHeight = self.frameBuffer.size.height;

    for (NSInteger columnIndex = 0; columnIndex < self.columns.count; columnIndex++) {
        NSMutableDictionary *column = self.columns[columnIndex];
        NSMutableArray<NSString *> *glyphs = column[@"glyphs"];
        CGFloat offset = [column[@"offset"] doubleValue];

        NSInteger rows = glyphs.count;
        CGFloat x = [column[@"x"] doubleValue];

        CGFloat headY = bufferHeight - self.characterHeight - offset;

        for (NSInteger row = 0; row < rows; row++) {
            CGFloat y = headY + (row * self.characterHeight);

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
    NSMutableDictionary<NSAttributedStringKey, id> *strongAttributes = [attributes mutableCopy];
    strongAttributes[NSFontAttributeName] = [self boldHeadFont];
    [glyph drawAtPoint:point withAttributes:strongAttributes];
}

- (NSFont *)boldHeadFont
{
    NSFont *boldFont = [[NSFontManager sharedFontManager] convertFont:self.matrixFont toHaveTrait:NSBoldFontMask];
    if (!boldFont) {
        boldFont = [NSFont monospacedSystemFontOfSize:self.matrixFont.pointSize weight:NSFontWeightSemibold];
    }
    return boldFont;
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
        NSInteger processedRows = [column[@"processedRows"] integerValue];
        NSMutableArray<NSString *> *glyphs = column[@"glyphs"];

        offset += speed * delta;

        NSInteger completedRows = (NSInteger)floor(offset / self.characterHeight);
        NSInteger rowsToProcess = MAX(0, completedRows - processedRows);

        for (NSInteger step = 0; step < rowsToProcess; step++) {
            [glyphs insertObject:[self randomGlyph] atIndex:0];
            [glyphs removeLastObject];
        }

        column[@"offset"] = @(offset);
        column[@"processedRows"] = @(completedRows);
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
        CGFloat alphaFactor = pow((1.0 - fadeProgress), 1.8) * 0.9 + 0.05;

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

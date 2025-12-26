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
- (NSTimeInterval)randomGlyphDwellTime;
- (void)ensureFrameBuffer;
- (void)renderFrame;

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
    NSUInteger index = arc4random_uniform((uint32_t)self.glyphSet.count);
    return self.glyphSet[index];
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
    NSMutableArray<NSString *> *glyphs = [NSMutableArray arrayWithCapacity:self.rowsPerColumn];
    for (NSInteger rowIndex = 0; rowIndex < self.rowsPerColumn; rowIndex++) {
        [glyphs addObject:[self randomGlyph]];
    }

    CGFloat baseSpeed = SSRandomFloatBetween(50.0, 120.0) * (self.characterHeight / 18.0);

    CGFloat initialOffset = SSRandomFloatBetween(0, self.characterHeight * 0.6);

    NSMutableDictionary *column = [@{
        @"glyphs" : glyphs,
        @"offset" : @(initialOffset),
        @"processedRows" : @(floor(initialOffset / self.characterHeight)),
        @"speed" : @(baseSpeed),
        @"glyphDwell" : @([self randomGlyphDwellTime]),
        @"glyphDwellAccumulator" : @(0),
        @"x" : @(x)
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

    [[NSColor blackColor] set];
    NSRectFill(imageRect);

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

    return self.glyphAttributes;
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

    for (NSMutableDictionary *column in self.columns) {
        CGFloat offset = [column[@"offset"] doubleValue];
        CGFloat speed = [column[@"speed"] doubleValue];
        NSInteger processedRows = [column[@"processedRows"] integerValue];
        NSTimeInterval glyphDwell = [column[@"glyphDwell"] doubleValue];
        NSTimeInterval glyphDwellAccumulator = [column[@"glyphDwellAccumulator"] doubleValue] + delta;
        NSMutableArray<NSString *> *glyphs = column[@"glyphs"];

        offset += speed * delta;

        NSInteger completedRows = (NSInteger)floor(offset / self.characterHeight);
        NSInteger rowsToProcess = MAX(0, completedRows - processedRows);
        NSInteger processedThisFrame = 0;

        while (rowsToProcess > 0 && glyphDwellAccumulator >= glyphDwell) {
            glyphDwellAccumulator -= glyphDwell;
            [glyphs insertObject:[self randomGlyph] atIndex:0];
            [glyphs removeLastObject];
            processedThisFrame += 1;
            rowsToProcess -= 1;
            glyphDwell = [self randomGlyphDwellTime];
        }

        column[@"offset"] = @(offset);
        column[@"processedRows"] = @(processedRows + processedThisFrame);
        column[@"glyphDwell"] = @(glyphDwell);
        column[@"glyphDwellAccumulator"] = @(glyphDwellAccumulator);
    }
}

- (NSTimeInterval)randomGlyphDwellTime
{
    return SSRandomFloatBetween(0.05, 0.16);
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

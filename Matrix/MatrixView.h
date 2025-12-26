//
//  MatrixView.h
//  Matrix
//
//  Created by Yousef Jawdat on 26/12/2025.
//

#import <ScreenSaver/ScreenSaver.h>

@interface MatrixView : ScreenSaverView

@property (nonatomic, strong) NSFont *matrixFont;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *glyphAttributes;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *headAttributes;

@property (nonatomic, assign) CGFloat characterWidth;
@property (nonatomic, assign) CGFloat characterHeight;
@property (nonatomic, assign) NSInteger columnCount;

@property (nonatomic, strong) NSArray<NSString *> *glyphSet;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *columns;
@property (nonatomic, assign) NSInteger fadeLength;

- (void)resetColumns;
- (NSString *)randomGlyph;

@end

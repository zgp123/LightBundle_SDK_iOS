/*
 * Copyright 2012 LBZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import <Foundation/Foundation.h>
/**
 * Enumeration for DataMatrix symbol shape hint. It can be used to force square or rectangular
 * symbols.
 */
typedef enum {
  LBZXDataMatrixSymbolShapeHintForceNone,
  LBZXDataMatrixSymbolShapeHintForceSquare,
  LBZXDataMatrixSymbolShapeHintForceRectangle
} LBZXDataMatrixSymbolShapeHint;

typedef enum {
  LBZXPDF417CompactionAuto,
  LBZXPDF417CompactionText,
  LBZXPDF417CompactionByte,
  LBZXPDF417CompactionNumeric
} LBZXPDF417Compaction;

@class LBZXDimension, LBZXPDF417Dimensions, LBZXQRCodeErrorCorrectionLevel;

/**
 * These are a set of hints that you may pass to Writers to specify their behavior.
 */
@interface LBZXEncodeHints : NSObject

+ (id)hints;

/**
 * Specifies what character encoding to use where applicable.
 */
@property (nonatomic, assign) NSStringEncoding encoding;

/**
 * Specifies the matrix shape for Data Matrix.
 */
@property (nonatomic, assign) LBZXDataMatrixSymbolShapeHint dataMatrixShape;

/**
 * Specifies a minimum barcode size. Only applicable to Data Matrix now.
 */
@property (nonatomic, strong) LBZXDimension *minSize;

/**
 * Specifies a maximum barcode size. Only applicable to Data Matrix now.
 */
@property (nonatomic, strong) LBZXDimension *maxSize;

/**
 * Specifies what degree of error correction to use, for example in QR Codes.
 * For Aztec it represents the minimal percentage of error correction words.
 * Note: an Aztec symbol should have a minimum of 25% EC words.
 */
@property (nonatomic, strong) LBZXQRCodeErrorCorrectionLevel *errorCorrectionLevel;

/**
 * Specifies what percent of error correction to use.
 * For Aztec it represents the minimal percentage of error correction words.
 * Note: an Aztec symbol should have a minimum of 25% EC words.
 */
@property (nonatomic, strong) NSNumber *errorCorrectionPercent;

/**
 * Specifies margin, in pixels, to use when generating the barcode. The meaning can vary
 * by format; for example it controls margin before and after the barcode horizontally for
 * most 1D formats.
 */
@property (nonatomic, strong) NSNumber *margin;

/**
 * Specifies whether to use compact mode for PDF417.
 */
@property (nonatomic, assign) BOOL pdf417Compact;

/**
 * Specifies what compaction mode to use for PDF417.
 */
@property (nonatomic, assign) LBZXPDF417Compaction pdf417Compaction;

/**
 * Specifies the minimum and maximum number of rows and columns for PDF417.
 */
@property (nonatomic, strong) LBZXPDF417Dimensions *pdf417Dimensions;

/**
 * Specifies the required number of layers for an Aztec code:
 *   a negative number (-1, -2, -3, -4) specifies a compact Aztec code
 *   0 indicates to use the minimum number of layers (the default)
 *   a positive number (1, 2, .. 32) specifies a normaol (non-compact) Aztec code
 */
@property (nonatomic, strong) NSNumber *aztecLayers;

@end

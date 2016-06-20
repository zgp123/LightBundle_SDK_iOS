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

#import "LBZXBarcodeFormat.h"
#import "LBZXBinaryBitmap.h"
#import "LBZXBitMatrix.h"
#import "LBZXDecodeHints.h"
#import "LBZXDecoderResult.h"
#import "LBZXDetectorResult.h"
#import "LBZXErrors.h"
#import "LBZXIntArray.h"
#import "LBZXQRCodeDecoder.h"
#import "LBZXQRCodeDecoderMetaData.h"
#import "LBZXQRCodeDetector.h"
#import "LBZXQRCodeReader.h"
#import "LBZXResult.h"

@implementation LBZXQRCodeReader

- (id)init {
  if (self = [super init]) {
    _decoder = [[LBZXQRCodeDecoder alloc] init];
  }

  return self;
}

/**
 * Locates and decodes a QR code in an image.
 *
 * @return a String representing the content encoded by the QR code
 * @throws NotFoundException if a QR code cannot be found
 * @throws FormatException if a QR code cannot be decoded
 * @throws ChecksumException if error correction fails
 */
- (LBZXResult *)decode:(LBZXBinaryBitmap *)image error:(NSError **)error {
  return [self decode:image hints:nil error:error];
}

- (LBZXResult *)decode:(LBZXBinaryBitmap *)image hints:(LBZXDecodeHints *)hints error:(NSError **)error {
  LBZXDecoderResult *decoderResult;
  NSMutableArray *points;
  LBZXBitMatrix *matrix = [image blackMatrixWithError:error];
  if (!matrix) {
    return nil;
  }
  if (hints != nil && hints.pureBarcode) {
    LBZXBitMatrix *bits = [self extractPureBits:matrix];
    if (!bits) {
      if (error) *error = LBZXNotFoundErrorInstance();
      return nil;
    }
    decoderResult = [self.decoder decodeMatrix:bits hints:hints error:error];
    if (!decoderResult) {
      return nil;
    }
    points = [NSMutableArray array];
  } else {
    LBZXDetectorResult *detectorResult = [[[LBZXQRCodeDetector alloc] initWithImage:matrix] detect:hints error:error];
    if (!detectorResult) {
      return nil;
    }
    decoderResult = [self.decoder decodeMatrix:[detectorResult bits] hints:hints error:error];
    if (!decoderResult) {
      return nil;
    }
    points = [[detectorResult points] mutableCopy];
  }

  // If the code was mirrored: swap the bottom-left and the top-right points.
  if ([decoderResult.other isKindOfClass:[LBZXQRCodeDecoderMetaData class]]) {
    [(LBZXQRCodeDecoderMetaData *)decoderResult.other applyMirroredCorrection:points];
  }

  LBZXResult *result = [LBZXResult resultWithText:decoderResult.text
                                     rawBytes:decoderResult.rawBytes
                                 resultPoints:points
                                       format:kBarcodeFormatQRCode];
  NSMutableArray *byteSegments = decoderResult.byteSegments;
  if (byteSegments != nil) {
    [result putMetadata:kResultMetadataTypeByteSegments value:byteSegments];
  }
  NSString *ecLevel = decoderResult.ecLevel;
  if (ecLevel != nil) {
    [result putMetadata:kResultMetadataTypeErrorCorrectionLevel value:ecLevel];
  }
  if ([decoderResult hasStructuredAppend]) {
    [result putMetadata:kResultMetadataTypeStructuredAppendSequence
                  value:@(decoderResult.structuredAppendSequenceNumber)];
    [result putMetadata:kResultMetadataTypeStructuredAppendParity
                  value:@(decoderResult.structuredAppendParity)];
  }
  return result;
}

- (void)reset {
  // do nothing
}

/**
 * This method detects a code in a "pure" image -- that is, pure monochrome image
 * which contains only an unrotated, unskewed, image of a code, with some white border
 * around it. This is a specialized method that works exceptionally fast in this special
 * case.
 */
- (LBZXBitMatrix *)extractPureBits:(LBZXBitMatrix *)image {
  LBZXIntArray *leftTopBlack = image.topLeftOnBit;
  LBZXIntArray *rightBottomBlack = image.bottomRightOnBit;
  if (leftTopBlack == nil || rightBottomBlack == nil) {
    return nil;
  }

  float moduleSize = [self moduleSize:leftTopBlack image:image];
  if (moduleSize == -1) {
    return nil;
  }

  int top = leftTopBlack.array[1];
  int bottom = rightBottomBlack.array[1];
  int left = leftTopBlack.array[0];
  int right = rightBottomBlack.array[0];

  // Sanity check!
  if (left >= right || top >= bottom) {
    return nil;
  }

  if (bottom - top != right - left) {
    // Special case, where bottom-right module wasn't black so we found something else in the last row
    // Assume it's a square, so use height as the width
    right = left + (bottom - top);
  }

  int matrixWidth = round((right - left + 1) / moduleSize);
  int matrixHeight = round((bottom - top + 1) / moduleSize);
  if (matrixWidth <= 0 || matrixHeight <= 0) {
    return nil;
  }
  if (matrixHeight != matrixWidth) {
    return nil;
  }

  int nudge = (int) (moduleSize / 2.0f);
  top += nudge;
  left += nudge;

  // But careful that this does not sample off the edge
  int nudgedTooFarRight = left + (int) ((matrixWidth - 1) * moduleSize) - (right - 1);
  if (nudgedTooFarRight > 0) {
    if (nudgedTooFarRight > nudge) {
      // Neither way fits; abort
      return nil;
    }
    left -= nudgedTooFarRight;
  }
  int nudgedTooFarDown = top + (int) ((matrixHeight - 1) * moduleSize) - (bottom - 1);
  if (nudgedTooFarDown > 0) {
    if (nudgedTooFarDown > nudge) {
      // Neither way fits; abort
      return nil;
    }
    top -= nudgedTooFarDown;
  }

  // Now just read off the bits
  LBZXBitMatrix *bits = [[LBZXBitMatrix alloc] initWithWidth:matrixWidth height:matrixHeight];
  for (int y = 0; y < matrixHeight; y++) {
    int iOffset = top + (int) (y * moduleSize);
    for (int x = 0; x < matrixWidth; x++) {
      if ([image getX:left + (int) (x * moduleSize) y:iOffset]) {
        [bits setX:x y:y];
      }
    }
  }
  return bits;
}

- (float)moduleSize:(LBZXIntArray *)leftTopBlack image:(LBZXBitMatrix *)image {
  int height = image.height;
  int width = image.width;
  int x = leftTopBlack.array[0];
  int y = leftTopBlack.array[1];
  BOOL inBlack = YES;
  int transitions = 0;
  while (x < width && y < height) {
    if (inBlack != [image getX:x y:y]) {
      if (++transitions == 5) {
        break;
      }
      inBlack = !inBlack;
    }
    x++;
    y++;
  }
  if (x == width || y == height) {
    return -1;
  }

  return (x - leftTopBlack.array[0]) / 7.0f;
}

@end

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

#import "LBZXBitArray.h"
#import "LBZXByteArray.h"
#import "LBZXByteMatrix.h"
#import "LBZXCharacterSetECI.h"
#import "LBZXEncodeHints.h"
#import "LBZXErrors.h"
#import "LBZXGenericGF.h"
#import "LBZXIntArray.h"
#import "LBZXQRCode.h"
#import "LBZXQRCodeBlockPair.h"
#import "LBZXQRCodeEncoder.h"
#import "LBZXQRCodeErrorCorrectionLevel.h"
#import "LBZXQRCodeMaskUtil.h"
#import "LBZXQRCodeMatrixUtil.h"
#import "LBZXQRCodeMode.h"
#import "LBZXQRCodeVersion.h"
#import "LBZXReedSolomonEncoder.h"

// The original table is defined in the table 5 of JISX0510:2004 (p.19).
const int LBZX_ALPHANUMERIC_TABLE[] = {
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  // 0x00-0x0f
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  // 0x10-0x1f
  36, -1, -1, -1, 37, 38, -1, -1, -1, -1, 39, 40, -1, 41, 42, 43,  // 0x20-0x2f
  0,   1,  2,  3,  4,  5,  6,  7,  8,  9, 44, -1, -1, -1, -1, -1,  // 0x30-0x3f
  -1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,  // 0x40-0x4f
  25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, -1, -1, -1, -1, -1,  // 0x50-0x5f
};

const NSStringEncoding LBZX_DEFAULT_BYTE_MODE_ENCODING = NSISOLatin1StringEncoding;

@implementation LBZXQRCodeEncoder

// The mask penalty calculation is complicated.  See Table 21 of JISX0510:2004 (p.45) for details.
// Basically it applies four rules and summate all penalties.
+ (int)calculateMaskPenalty:(LBZXByteMatrix *)matrix {
  return [LBZXQRCodeMaskUtil applyMaskPenaltyRule1:matrix]
    + [LBZXQRCodeMaskUtil applyMaskPenaltyRule2:matrix]
    + [LBZXQRCodeMaskUtil applyMaskPenaltyRule3:matrix]
    + [LBZXQRCodeMaskUtil applyMaskPenaltyRule4:matrix];
}

+ (LBZXQRCode *)encode:(NSString *)content ecLevel:(LBZXQRCodeErrorCorrectionLevel *)ecLevel error:(NSError **)error {
  return [self encode:content ecLevel:ecLevel hints:nil error:error];
}

+ (LBZXQRCode *)encode:(NSString *)content ecLevel:(LBZXQRCodeErrorCorrectionLevel *)ecLevel hints:(LBZXEncodeHints *)hints error:(NSError **)error {
  // Determine what character encoding has been specified by the caller, if any
  NSStringEncoding encoding = hints == nil ? 0 : hints.encoding;
  if (encoding == 0) {
    encoding = LBZX_DEFAULT_BYTE_MODE_ENCODING;
  }

  // Pick an encoding mode appropriate for the content. Note that this will not attempt to use
  // multiple modes / segments even if that were more efficient. Twould be nice.
  LBZXQRCodeMode *mode = [self chooseMode:content encoding:encoding];

  // This will store the header information, like mode and
  // length, as well as "header" segments like an ECI segment.
  LBZXBitArray *headerBits = [[LBZXBitArray alloc] init];

  // Append ECI segment if applicable
  if ([mode isEqual:[LBZXQRCodeMode byteMode]] && LBZX_DEFAULT_BYTE_MODE_ENCODING != encoding) {
    LBZXCharacterSetECI *eci = [LBZXCharacterSetECI characterSetECIByEncoding:encoding];
    if (eci != nil) {
      [self appendECI:eci bits:headerBits];
    }
  }

  // (With ECI in place,) Write the mode marker
  [self appendModeInfo:mode bits:headerBits];

  // Collect data within the main segment, separately, to count its size if needed. Don't add it to
  // main payload yet.
  LBZXBitArray *dataBits = [[LBZXBitArray alloc] init];
  if (![self appendBytes:content mode:mode bits:dataBits encoding:encoding error:error]) {
    return nil;
  }

  // Hard part: need to know version to know how many bits length takes. But need to know how many
  // bits it takes to know version. First we take a guess at version by assuming version will be
  // the minimum, 1:

  int provisionalBitsNeeded = headerBits.size
    + [mode characterCountBits:[LBZXQRCodeVersion versionForNumber:1]]
    + dataBits.size;
  LBZXQRCodeVersion *provisionalVersion = [self chooseVersion:provisionalBitsNeeded ecLevel:ecLevel error:error];
  if (!provisionalVersion) {
    return nil;
  }

  // Use that guess to calculate the right version. I am still not sure this works in 100% of cases.

  int bitsNeeded = headerBits.size
    + [mode characterCountBits:provisionalVersion]
    + dataBits.size;
  LBZXQRCodeVersion *version = [self chooseVersion:bitsNeeded ecLevel:ecLevel error:error];
  if (!version) {
    return nil;
  }

  LBZXBitArray *headerAndDataBits = [[LBZXBitArray alloc] init];
  [headerAndDataBits appendBitArray:headerBits];
  // Find "length" of main segment and write it
  int numLetters = [mode isEqual:[LBZXQRCodeMode byteMode]] ? [dataBits sizeInBytes] : (int)[content length];
  if (![self appendLengthInfo:numLetters version:version mode:mode bits:headerAndDataBits error:error]) {
    return nil;
  }
  // Put data together into the overall payload
  [headerAndDataBits appendBitArray:dataBits];

  LBZXQRCodeECBlocks *ecBlocks = [version ecBlocksForLevel:ecLevel];
  int numDataBytes = version.totalCodewords - ecBlocks.totalECCodewords;

  // Terminate the bits properly.
  if (![self terminateBits:numDataBytes bits:headerAndDataBits error:error]) {
    return nil;
  }

  // Interleave data bits with error correction code.
  LBZXBitArray *finalBits = [self interleaveWithECBytes:headerAndDataBits numTotalBytes:version.totalCodewords numDataBytes:numDataBytes
                                          numRSBlocks:ecBlocks.numBlocks error:error];
  if (!finalBits) {
    return nil;
  }

  LBZXQRCode *qrCode = [[LBZXQRCode alloc] init];

  qrCode.ecLevel = ecLevel;
  qrCode.mode = mode;
  qrCode.version = version;

  // Choose the mask pattern and set to "qrCode".
  int dimension = version.dimensionForVersion;
  LBZXByteMatrix *matrix = [[LBZXByteMatrix alloc] initWithWidth:dimension height:dimension];
  int maskPattern = [self chooseMaskPattern:finalBits ecLevel:[qrCode ecLevel] version:[qrCode version] matrix:matrix error:error];
  if (maskPattern == -1) {
    return nil;
  }
  [qrCode setMaskPattern:maskPattern];

  // Build the matrix and set it to "qrCode".
  if (![LBZXQRCodeMatrixUtil buildMatrix:finalBits ecLevel:ecLevel version:version maskPattern:maskPattern matrix:matrix error:error]) {
    return nil;
  }
  [qrCode setMatrix:matrix];

  return qrCode;
}

+ (int)alphanumericCode:(int)code {
  if (code < sizeof(LBZX_ALPHANUMERIC_TABLE) / sizeof(int)) {
    return LBZX_ALPHANUMERIC_TABLE[code];
  }
  return -1;
}

+ (LBZXQRCodeMode *)chooseMode:(NSString *)content {
  return [self chooseMode:content encoding:-1];
}

/**
 * Choose the best mode by examining the content. Note that 'encoding' is used as a hint;
 * if it is Shift_JIS, and the input is only double-byte Kanji, then we return {@link Mode#KANJI}.
 */
+ (LBZXQRCodeMode *)chooseMode:(NSString *)content encoding:(NSStringEncoding)encoding {
  if (NSShiftJISStringEncoding == encoding) {
    return [self isOnlyDoubleByteKanji:content] ? [LBZXQRCodeMode kanjiMode] : [LBZXQRCodeMode byteMode];
  }
  BOOL hasNumeric = NO;
  BOOL hasAlphanumeric = NO;
  for (int i = 0; i < [content length]; ++i) {
    unichar c = [content characterAtIndex:i];
    if (c >= '0' && c <= '9') {
      hasNumeric = YES;
    } else if ([self alphanumericCode:c] != -1) {
      hasAlphanumeric = YES;
    } else {
      return [LBZXQRCodeMode byteMode];
    }
  }
  if (hasAlphanumeric) {
    return [LBZXQRCodeMode alphanumericMode];
  }
  if (hasNumeric) {
    return [LBZXQRCodeMode numericMode];
  }
  return [LBZXQRCodeMode byteMode];
}

+ (BOOL)isOnlyDoubleByteKanji:(NSString *)content {
  NSData *data = [content dataUsingEncoding:NSShiftJISStringEncoding];
  int8_t *bytes = (int8_t *)[data bytes];
  NSUInteger length = [data length];
  if (length % 2 != 0) {
    return NO;
  }
  for (int i = 0; i < length; i += 2) {
    int byte1 = bytes[i] & 0xFF;
    if ((byte1 < 0x81 || byte1 > 0x9F) && (byte1 < 0xE0 || byte1 > 0xEB)) {
      return NO;
    }
  }
  return YES;
}

+ (int)chooseMaskPattern:(LBZXBitArray *)bits ecLevel:(LBZXQRCodeErrorCorrectionLevel *)ecLevel version:(LBZXQRCodeVersion *)version matrix:(LBZXByteMatrix *)matrix error:(NSError **)error {
  int minPenalty = INT_MAX;
  int bestMaskPattern = -1;

  for (int maskPattern = 0; maskPattern < LBZX_NUM_MASK_PATTERNS; maskPattern++) {
    if (![LBZXQRCodeMatrixUtil buildMatrix:bits ecLevel:ecLevel version:version maskPattern:maskPattern matrix:matrix error:error]) {
      return -1;
    }
    int penalty = [self calculateMaskPenalty:matrix];
    if (penalty < minPenalty) {
      minPenalty = penalty;
      bestMaskPattern = maskPattern;
    }
  }
  return bestMaskPattern;
}

+ (LBZXQRCodeVersion *)chooseVersion:(int)numInputBits ecLevel:(LBZXQRCodeErrorCorrectionLevel *)ecLevel error:(NSError **)error {
  // In the following comments, we use numbers of Version 7-H.
  for (int versionNum = 1; versionNum <= 40; versionNum++) {
    LBZXQRCodeVersion *version = [LBZXQRCodeVersion versionForNumber:versionNum];
    // numBytes = 196
    int numBytes = version.totalCodewords;
    // getNumECBytes = 130
    LBZXQRCodeECBlocks *ecBlocks = [version ecBlocksForLevel:ecLevel];
    int numEcBytes = ecBlocks.totalECCodewords;
    // getNumDataBytes = 196 - 130 = 66
    int numDataBytes = numBytes - numEcBytes;
    int totalInputBytes = (numInputBits + 7) / 8;
    if (numDataBytes >= totalInputBytes) {
      return version;
    }
  }

  NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Data too big"};

  if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
  return nil;
}

+ (int)totalInputBytes:(int)numInputBits version:(LBZXQRCodeVersion *)version mode:(LBZXQRCodeMode *)mode {
  int modeInfoBits = 4;
  int charCountBits = [mode characterCountBits:version];
  int headerBits = modeInfoBits + charCountBits;
  int totalBits = numInputBits + headerBits;

  return (totalBits + 7) / 8;
}

+ (BOOL)terminateBits:(int)numDataBytes bits:(LBZXBitArray *)bits error:(NSError **)error {
  int capacity = numDataBytes << 3;
  if ([bits size] > capacity) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"data bits cannot fit in the QR Code %d > %d", [bits size], capacity]};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return NO;
  }
  for (int i = 0; i < 4 && [bits size] < capacity; ++i) {
    [bits appendBit:NO];
  }
  int numBitsInLastByte = [bits size] & 0x07;
  if (numBitsInLastByte > 0) {
    for (int i = numBitsInLastByte; i < 8; i++) {
      [bits appendBit:NO];
    }
  }
  int numPaddingBytes = numDataBytes - [bits sizeInBytes];
  for (int i = 0; i < numPaddingBytes; ++i) {
    [bits appendBits:(i & 0x01) == 0 ? 0xEC : 0x11 numBits:8];
  }
  if ([bits size] != capacity) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Bits size does not equal capacity"};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return NO;
  }
  return YES;
}

+ (BOOL)numDataBytesAndNumECBytesForBlockID:(int)numTotalBytes numDataBytes:(int)numDataBytes numRSBlocks:(int)numRSBlocks blockID:(int)blockID numDataBytesInBlock:(int[])numDataBytesInBlock numECBytesInBlock:(int[])numECBytesInBlock error:(NSError **)error {
  if (blockID >= numRSBlocks) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Block ID too large"};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return NO;
  }
  int numRsBlocksInGroup2 = numTotalBytes % numRSBlocks;
  int numRsBlocksInGroup1 = numRSBlocks - numRsBlocksInGroup2;
  int numTotalBytesInGroup1 = numTotalBytes / numRSBlocks;
  int numTotalBytesInGroup2 = numTotalBytesInGroup1 + 1;
  int numDataBytesInGroup1 = numDataBytes / numRSBlocks;
  int numDataBytesInGroup2 = numDataBytesInGroup1 + 1;
  int numEcBytesInGroup1 = numTotalBytesInGroup1 - numDataBytesInGroup1;
  int numEcBytesInGroup2 = numTotalBytesInGroup2 - numDataBytesInGroup2;
  if (numEcBytesInGroup1 != numEcBytesInGroup2) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"EC bytes mismatch"};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return NO;
  }
  if (numRSBlocks != numRsBlocksInGroup1 + numRsBlocksInGroup2) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"RS blocks mismatch"};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return NO;
  }
  if (numTotalBytes != ((numDataBytesInGroup1 + numEcBytesInGroup1) * numRsBlocksInGroup1) + ((numDataBytesInGroup2 + numEcBytesInGroup2) * numRsBlocksInGroup2)) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Total bytes mismatch"};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return NO;
  }
  if (blockID < numRsBlocksInGroup1) {
    numDataBytesInBlock[0] = numDataBytesInGroup1;
    numECBytesInBlock[0] = numEcBytesInGroup1;
  } else {
    numDataBytesInBlock[0] = numDataBytesInGroup2;
    numECBytesInBlock[0] = numEcBytesInGroup2;
  }
  return YES;
}

+ (LBZXBitArray *)interleaveWithECBytes:(LBZXBitArray *)bits numTotalBytes:(int)numTotalBytes numDataBytes:(int)numDataBytes numRSBlocks:(int)numRSBlocks error:(NSError **)error {
  // "bits" must have "getNumDataBytes" bytes of data.
  if ([bits sizeInBytes] != numDataBytes) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Number of bits and data bytes does not match"};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return nil;
  }

  // Step 1.  Divide data bytes into blocks and generate error correction bytes for them. We'll
  // store the divided data bytes blocks and error correction bytes blocks into "blocks".
  int dataBytesOffset = 0;
  int maxNumDataBytes = 0;
  int maxNumEcBytes = 0;

  // Since, we know the number of reedsolmon blocks, we can initialize the vector with the number.
  NSMutableArray *blocks = [NSMutableArray arrayWithCapacity:numRSBlocks];

  for (int i = 0; i < numRSBlocks; ++i) {
    int numDataBytesInBlock[1];
    int numEcBytesInBlock[1];
    if (![self numDataBytesAndNumECBytesForBlockID:numTotalBytes numDataBytes:numDataBytes numRSBlocks:numRSBlocks
                                         blockID:i numDataBytesInBlock:numDataBytesInBlock
                                 numECBytesInBlock:numEcBytesInBlock error:error]) {
      return nil;
    }

    int size = numDataBytesInBlock[0];
    LBZXByteArray *dataBytes = [[LBZXByteArray alloc] initWithLength:size];
    [bits toBytes:8 * dataBytesOffset array:dataBytes offset:0 numBytes:size];
    LBZXByteArray *ecBytes = [self generateECBytes:dataBytes numEcBytesInBlock:numEcBytesInBlock[0]];
    [blocks addObject:[[LBZXQRCodeBlockPair alloc] initWithData:dataBytes errorCorrection:ecBytes]];

    maxNumDataBytes = MAX(maxNumDataBytes, size);
    maxNumEcBytes = MAX(maxNumEcBytes, numEcBytesInBlock[0]);
    dataBytesOffset += numDataBytesInBlock[0];
  }
  if (numDataBytes != dataBytesOffset) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Data bytes does not match offset"};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return nil;
  }

  LBZXBitArray *result = [[LBZXBitArray alloc] init];

  // First, place data blocks.
  for (int i = 0; i < maxNumDataBytes; ++i) {
    for (LBZXQRCodeBlockPair *block in blocks) {
      LBZXByteArray *dataBytes = block.dataBytes;
      NSUInteger length = dataBytes.length;
      if (i < length) {
        [result appendBits:dataBytes.array[i] numBits:8];
      }
    }
  }
  // Then, place error correction blocks.
  for (int i = 0; i < maxNumEcBytes; ++i) {
    for (LBZXQRCodeBlockPair *block in blocks) {
      LBZXByteArray *ecBytes = block.errorCorrectionBytes;
      int length = ecBytes.length;
      if (i < length) {
        [result appendBits:ecBytes.array[i] numBits:8];
      }
    }
  }
  if (numTotalBytes != [result sizeInBytes]) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Interleaving error: %d and %d differ.", numTotalBytes, [result sizeInBytes]]};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return nil;
  }

  return result;
}

+ (LBZXByteArray *)generateECBytes:(LBZXByteArray *)dataBytes numEcBytesInBlock:(int)numEcBytesInBlock {
  int numDataBytes = dataBytes.length;
  LBZXIntArray *toEncode = [[LBZXIntArray alloc] initWithLength:numDataBytes + numEcBytesInBlock];
  for (int i = 0; i < numDataBytes; i++) {
    toEncode.array[i] = dataBytes.array[i] & 0xFF;
  }
  [[[LBZXReedSolomonEncoder alloc] initWithField:[LBZXGenericGF QrCodeField256]] encode:toEncode ecBytes:numEcBytesInBlock];

  LBZXByteArray *ecBytes = [[LBZXByteArray alloc] initWithLength:numEcBytesInBlock];
  for (int i = 0; i < numEcBytesInBlock; i++) {
    ecBytes.array[i] = (int8_t) toEncode.array[numDataBytes + i];
  }

  return ecBytes;
}

+ (void)appendModeInfo:(LBZXQRCodeMode *)mode bits:(LBZXBitArray *)bits {
  [bits appendBits:[mode bits] numBits:4];
}

/**
 * Append length info. On success, store the result in "bits".
 */
+ (BOOL)appendLengthInfo:(int)numLetters version:(LBZXQRCodeVersion *)version mode:(LBZXQRCodeMode *)mode bits:(LBZXBitArray *)bits error:(NSError **)error {
  int numBits = [mode characterCountBits:version];
  if (numLetters >= (1 << numBits)) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%d is bigger than %d", numLetters, ((1 << numBits) - 1)]};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return NO;
  }
  [bits appendBits:numLetters numBits:numBits];
  return YES;
}

+ (BOOL)appendBytes:(NSString *)content mode:(LBZXQRCodeMode *)mode bits:(LBZXBitArray *)bits encoding:(NSStringEncoding)encoding error:(NSError **)error {
  if ([mode isEqual:[LBZXQRCodeMode numericMode]]) {
    [self appendNumericBytes:content bits:bits];
  } else if ([mode isEqual:[LBZXQRCodeMode alphanumericMode]]) {
    if (![self appendAlphanumericBytes:content bits:bits error:error]) {
      return NO;
    }
  } else if ([mode isEqual:[LBZXQRCodeMode byteMode]]) {
    [self append8BitBytes:content bits:bits encoding:encoding];
  } else if ([mode isEqual:[LBZXQRCodeMode kanjiMode]]) {
    if (![self appendKanjiBytes:content bits:bits error:error]) {
      return NO;
    }
  } else {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid mode: %@", mode]};

    if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
    return NO;
  }
  return YES;
}

+ (void)appendNumericBytes:(NSString *)content bits:(LBZXBitArray *)bits {
  NSUInteger length = [content length];
  int i = 0;
  while (i < length) {
    int num1 = [content characterAtIndex:i] - '0';
    if (i + 2 < length) {
      int num2 = [content characterAtIndex:i + 1] - '0';
      int num3 = [content characterAtIndex:i + 2] - '0';
      [bits appendBits:num1 * 100 + num2 * 10 + num3 numBits:10];
      i += 3;
    } else if (i + 1 < length) {
      int num2 = [content characterAtIndex:i + 1] - '0';
      [bits appendBits:num1 * 10 + num2 numBits:7];
      i += 2;
    } else {
      [bits appendBits:num1 numBits:4];
      i++;
    }
  }
}

+ (BOOL)appendAlphanumericBytes:(NSString *)content bits:(LBZXBitArray *)bits error:(NSError **)error {
  NSUInteger length = [content length];
  int i = 0;

  while (i < length) {
    int code1 = [self alphanumericCode:[content characterAtIndex:i]];
    if (code1 == -1) {
      if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:nil];
      return NO;
    }
    if (i + 1 < length) {
      int code2 = [self alphanumericCode:[content characterAtIndex:i + 1]];
      if (code2 == -1) {
        if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:nil];
        return NO;
      }
      [bits appendBits:code1 * 45 + code2 numBits:11];
      i += 2;
    } else {
      [bits appendBits:code1 numBits:6];
      i++;
    }
  }
  return YES;
}

+ (void)append8BitBytes:(NSString *)content bits:(LBZXBitArray *)bits encoding:(NSStringEncoding)encoding {
  NSData *data = [content dataUsingEncoding:encoding];
  int8_t *bytes = (int8_t *)[data bytes];

  for (int i = 0; i < [data length]; ++i) {
    [bits appendBits:bytes[i] numBits:8];
  }
}

+ (BOOL)appendKanjiBytes:(NSString *)content bits:(LBZXBitArray *)bits error:(NSError **)error {
  NSData *data = [content dataUsingEncoding:NSShiftJISStringEncoding];
  int8_t *bytes = (int8_t *)[data bytes];
  for (int i = 0; i < [data length]; i += 2) {
    int byte1 = bytes[i] & 0xFF;
    int byte2 = bytes[i + 1] & 0xFF;
    int code = (byte1 << 8) | byte2;
    int subtracted = -1;
    if (code >= 0x8140 && code <= 0x9ffc) {
      subtracted = code - 0x8140;
    } else if (code >= 0xe040 && code <= 0xebbf) {
      subtracted = code - 0xc140;
    }
    if (subtracted == -1) {
      NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Invalid byte sequence"};

      if (error) *error = [[NSError alloc] initWithDomain:LBZXErrorDomain code:LBZXWriterError userInfo:userInfo];
      return NO;
    }
    int encoded = ((subtracted >> 8) * 0xc0) + (subtracted & 0xff);
    [bits appendBits:encoded numBits:13];
  }
  return YES;
}

+ (void)appendECI:(LBZXCharacterSetECI *)eci bits:(LBZXBitArray *)bits {
  [bits appendBits:[[LBZXQRCodeMode eciMode] bits] numBits:4];
  [bits appendBits:[eci value] numBits:8];
}

@end

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
#import "LBZXBoolArray.h"
#import "LBZXEAN13Reader.h"
#import "LBZXEAN13Writer.h"
#import "LBZXUPCEANReader.h"

const int LBZX_EAN13_CODE_WIDTH = 3 + // start guard
  (7 * 6) + // left bars
  5 + // middle guard
  (7 * 6) + // right bars
  3; // end guard

@implementation LBZXEAN13Writer

- (LBZXBitMatrix *)encode:(NSString *)contents format:(LBZXBarcodeFormat)format width:(int)width height:(int)height hints:(LBZXEncodeHints *)hints error:(NSError **)error {
  if (format != kBarcodeFormatEan13) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:[NSString stringWithFormat:@"Can only encode EAN_13, but got %d", format]
                                 userInfo:nil];
  }

  return [super encode:contents format:format width:width height:height hints:hints error:error];
}

- (LBZXBoolArray *)encode:(NSString *)contents {
  if ([contents length] != 13) {
    [NSException raise:NSInvalidArgumentException
                format:@"Requested contents should be 13 digits long, but got %d", (int)[contents length]];
  }

  if (![LBZXUPCEANReader checkStandardUPCEANChecksum:contents]) {
    [NSException raise:NSInvalidArgumentException
                format:@"Contents do not pass checksum"];
  }

  int firstDigit = [[contents substringToIndex:1] intValue];
  int parities = LBZX_EAN13_FIRST_DIGIT_ENCODINGS[firstDigit];
  LBZXBoolArray *result = [[LBZXBoolArray alloc] initWithLength:LBZX_EAN13_CODE_WIDTH];
  int pos = 0;

  pos += [self appendPattern:result pos:pos pattern:LBZX_UPC_EAN_START_END_PATTERN patternLen:LBZX_UPC_EAN_START_END_PATTERN_LEN startColor:YES];

  for (int i = 1; i <= 6; i++) {
    int digit = [[contents substringWithRange:NSMakeRange(i, 1)] intValue];
    if ((parities >> (6 - i) & 1) == 1) {
      digit += 10;
    }
    pos += [self appendPattern:result pos:pos pattern:LBZX_UPC_EAN_L_AND_G_PATTERNS[digit] patternLen:LBZX_UPC_EAN_L_PATTERNS_SUB_LEN startColor:FALSE];
  }

  pos += [self appendPattern:result pos:pos pattern:LBZX_UPC_EAN_MIDDLE_PATTERN patternLen:LBZX_UPC_EAN_MIDDLE_PATTERN_LEN startColor:FALSE];

  for (int i = 7; i <= 12; i++) {
    int digit = [[contents substringWithRange:NSMakeRange(i, 1)] intValue];
    pos += [self appendPattern:result pos:pos pattern:LBZX_UPC_EAN_L_PATTERNS[digit] patternLen:LBZX_UPC_EAN_L_PATTERNS_SUB_LEN startColor:YES];
  }
  [self appendPattern:result pos:pos pattern:LBZX_UPC_EAN_START_END_PATTERN patternLen:LBZX_UPC_EAN_START_END_PATTERN_LEN startColor:YES];

  return result;
}

@end

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
#import "LBZXBitArrayBuilder.h"
#import "LBZXRSSDataCharacter.h"
#import "LBZXRSSExpandedPair.h"

@implementation LBZXBitArrayBuilder

+ (LBZXBitArray *)buildBitArray:(NSArray *)pairs {
  int charNumber = ((int)[pairs count] << 1) - 1;
  if ([pairs[pairs.count - 1] rightChar] == nil) {
    charNumber -= 1;
  }

  int size = 12 * charNumber;

  LBZXBitArray *binary = [[LBZXBitArray alloc] initWithSize:size];
  int accPos = 0;

  LBZXRSSExpandedPair *firstPair = pairs[0];
  int firstValue = [[firstPair rightChar] value];
  for (int i = 11; i >= 0; --i) {
    if ((firstValue & (1 << i)) != 0) {
      [binary set:accPos];
    }
    accPos++;
  }

  for (int i = 1; i < [pairs count]; ++i) {
    LBZXRSSExpandedPair *currentPair = pairs[i];
    int leftValue = [[currentPair leftChar] value];

    for (int j = 11; j >= 0; --j) {
      if ((leftValue & (1 << j)) != 0) {
        [binary set:accPos];
      }
      accPos++;
    }

    if ([currentPair rightChar] != nil) {
      int rightValue = [[currentPair rightChar] value];

      for (int j = 11; j >= 0; --j) {
        if ((rightValue & (1 << j)) != 0) {
          [binary set:accPos];
        }
        accPos++;
      }
    }
  }

  return binary;
}

@end

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

#import "LBZXByteArray.h"
#import "LBZXDataMatrixDataBlock.h"
#import "LBZXDataMatrixVersion.h"

@implementation LBZXDataMatrixDataBlock

- (id)initWithNumDataCodewords:(int)numDataCodewords codewords:(LBZXByteArray *)codewords {
  if (self = [super init]) {
    _numDataCodewords = numDataCodewords;
    _codewords = codewords;
  }

  return self;
}

+ (NSArray *)dataBlocks:(LBZXByteArray *)rawCodewords version:(LBZXDataMatrixVersion *)version {
  // Figure out the number and size of data blocks used by this version
  LBZXDataMatrixECBlocks *ecBlocks = version.ecBlocks;

  // First count the total number of data blocks
  int totalBlocks = 0;
  NSArray *ecBlockArray = ecBlocks.ecBlocks;
  for (LBZXDataMatrixECB *ecBlock in ecBlockArray) {
    totalBlocks += ecBlock.count;
  }

  // Now establish DataBlocks of the appropriate size and number of data codewords
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:totalBlocks];
  for (LBZXDataMatrixECB *ecBlock in ecBlockArray) {
    for (int i = 0; i < ecBlock.count; i++) {
      int numDataCodewords = ecBlock.dataCodewords;
      int numBlockCodewords = ecBlocks.ecCodewords + numDataCodewords;
      [result addObject:[[LBZXDataMatrixDataBlock alloc] initWithNumDataCodewords:numDataCodewords codewords:[[LBZXByteArray alloc] initWithLength:numBlockCodewords]]];
    }
  }

  // All blocks have the same amount of data, except that the last n
  // (where n may be 0) have 1 less byte. Figure out where these start.
  // TODO(bbrown): There is only one case where there is a difference for Data Matrix for size 144
  int longerBlocksTotalCodewords = [[(LBZXDataMatrixDataBlock *)result[0] codewords] length];
  //int shorterBlocksTotalCodewords = longerBlocksTotalCodewords - 1;

  int longerBlocksNumDataCodewords = longerBlocksTotalCodewords - ecBlocks.ecCodewords;
  int shorterBlocksNumDataCodewords = longerBlocksNumDataCodewords - 1;
  // The last elements of result may be 1 element shorter for 144 matrix
  // first fill out as many elements as all of them have minus 1
  int rawCodewordsOffset = 0;
  for (int i = 0; i < shorterBlocksNumDataCodewords; i++) {
    for (LBZXDataMatrixDataBlock *block in result) {
      block.codewords.array[i] = rawCodewords.array[rawCodewordsOffset++];
    }
  }

  // Fill out the last data block in the longer ones
  BOOL specialVersion = version.versionNumber == 24;
  int numLongerBlocks = specialVersion ? 8 : (int)[result count];
  for (int j = 0; j < numLongerBlocks; j++) {
    [(LBZXDataMatrixDataBlock *)result[j] codewords].array[longerBlocksNumDataCodewords - 1] = rawCodewords.array[rawCodewordsOffset++];
  }

  NSUInteger max = [(LBZXDataMatrixDataBlock *)result[0] codewords].length;
  for (int i = longerBlocksNumDataCodewords; i < max; i++) {
    for (int j = 0; j < [result count]; j++) {
      int iOffset = specialVersion && j > 7 ? i - 1 : i;
      [(LBZXDataMatrixDataBlock *)result[j] codewords].array[iOffset] = rawCodewords.array[rawCodewordsOffset++];
    }
  }

  if (rawCodewordsOffset != rawCodewords.length) {
    [NSException raise:NSInvalidArgumentException format:@"Codewords size mismatch"];
  }
  return result;
}

@end

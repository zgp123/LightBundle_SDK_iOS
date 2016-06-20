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
 * Encapsulates a set of error-correction blocks in one symbol version. Most versions will
 * use blocks of differing sizes within one version, so, this encapsulates the parameters for
 * each set of blocks. It also holds the number of error-correction codewords per block since it
 * will be the same across all blocks within one version.
 */
@interface LBZXDataMatrixECBlocks : NSObject

@property (nonatomic, strong, readonly) NSArray *ecBlocks;
@property (nonatomic, assign, readonly) int ecCodewords;

@end

/**
 * Encapsualtes the parameters for one error-correction block in one symbol version.
 * This includes the number of data codewords, and the number of times a block with these
 * parameters is used consecutively in the Data Matrix code version's format.
 */
@interface LBZXDataMatrixECB : NSObject

@property (nonatomic, assign, readonly) int count;
@property (nonatomic, assign, readonly) int dataCodewords;

@end

/**
 * The Version object encapsulates attributes about a particular
 * size Data Matrix Code.
 */
@interface LBZXDataMatrixVersion : NSObject

@property (nonatomic, strong, readonly) LBZXDataMatrixECBlocks *ecBlocks;
@property (nonatomic, assign, readonly) int dataRegionSizeColumns;
@property (nonatomic, assign, readonly) int dataRegionSizeRows;
@property (nonatomic, assign, readonly) int symbolSizeColumns;
@property (nonatomic, assign, readonly) int symbolSizeRows;
@property (nonatomic, assign, readonly) int totalCodewords;
@property (nonatomic, assign, readonly) int versionNumber;

/**
 * <p>Deduces version information from Data Matrix dimensions.</p>
 *
 * @param numRows Number of rows in modules
 * @param numColumns Number of columns in modules
 * @return Version for a Data Matrix Code of those dimensions or nil
 *  if dimensions do correspond to a valid Data Matrix size
 */
+ (LBZXDataMatrixVersion *)versionForDimensions:(int)numRows numColumns:(int)numColumns;

@end

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

#import "LBZXReader.h"

@class LBZXDecodeHints;

/**
 * LBZXMultiFormatReader is a convenience class and the main entry point into the library for most uses.
 * By default it attempts to decode all barcode formats that the library supports. Optionally, you
 * can provide a hints object to request different behavior, for example only decoding QR codes.
 */
@interface LBZXMultiFormatReader : NSObject <LBZXReader>

@property (nonatomic, strong) LBZXDecodeHints *hints;

+ (id)reader;

/**
 * Decode an image using the state set up by calling setHints() previously. Continuous scan
 * clients will get a <b>large</b> speed increase by using this instead of decode().
 *
 * @param image The pixel data to decode
 * @return The contents of the image or nil if any errors occurred
 */
- (LBZXResult *)decodeWithState:(LBZXBinaryBitmap *)image error:(NSError **)error;

@end

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

#import "LBZXRSSExpandedDecodedChar.h"

unichar const LBZX_FNC1_CHAR = '$'; // It's not in Alphanumeric neither in ISO/IEC 646 charset

@implementation LBZXRSSExpandedDecodedChar

- (id)initWithNewPosition:(int)newPosition value:(unichar)value {
  if (self = [super initWithNewPosition:newPosition]) {
    _value = value;
  }

  return self;
}

- (BOOL)fnc1 {
  return self.value == LBZX_FNC1_CHAR;
}

@end

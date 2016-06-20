/*
 * Copyright 2014 LBZXing authors
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

#import "LBZXAztecHighLevelEncoder.h"
#import "LBZXAztecState.h"
#import "LBZXByteArray.h"

NSArray *LBZX_AZTEC_MODE_NAMES = nil;

const int LBZX_AZTEC_MODE_UPPER = 0; // 5 bits
const int LBZX_AZTEC_MODE_LOWER = 1; // 5 bits
const int LBZX_AZTEC_MODE_DIGIT = 2; // 4 bits
const int LBZX_AZTEC_MODE_MIXED = 3; // 5 bits
const int LBZX_AZTEC_MODE_PUNCT = 4; // 5 bits

// The Latch Table shows, for each pair of Modes, the optimal method for
// getting from one mode to another.  In the worst possible case, this can
// be up to 14 bits.  In the best possible case, we are already there!
// The high half-word of each entry gives the number of bits.
// The low half-word of each entry are the actual bits necessary to change
const int LBZX_AZTEC_LATCH_TABLE[][5] = {
  {
    0,
    (5 << 16) + 28,              // UPPER -> LOWER
    (5 << 16) + 30,              // UPPER -> DIGIT
    (5 << 16) + 29,              // UPPER -> MIXED
    (10 << 16) + (29 << 5) + 30, // UPPER -> MIXED -> PUNCT
  },
  {
    (9 << 16) + (30 << 4) + 14,  // LOWER -> DIGIT -> UPPER
    0,
    (5 << 16) + 30,              // LOWER -> DIGIT
    (5 << 16) + 29,              // LOWER -> MIXED
    (10 << 16) + (29 << 5) + 30, // LOWER -> MIXED -> PUNCT
  },
  {
    (4 << 16) + 14,              // DIGIT -> UPPER
    (9 << 16) + (14 << 5) + 28,  // DIGIT -> UPPER -> LOWER
    0,
    (9 << 16) + (14 << 5) + 29,  // DIGIT -> UPPER -> MIXED
    (14 << 16) + (14 << 10) + (29 << 5) + 30,
    // DIGIT -> UPPER -> MIXED -> PUNCT
  },
  {
    (5 << 16) + 29,              // MIXED -> UPPER
    (5 << 16) + 28,              // MIXED -> LOWER
    (10 << 16) + (29 << 5) + 30, // MIXED -> UPPER -> DIGIT
    0,
    (5 << 16) + 30,              // MIXED -> PUNCT
  },
  {
    (5 << 16) + 31,              // PUNCT -> UPPER
    (10 << 16) + (31 << 5) + 28, // PUNCT -> UPPER -> LOWER
    (10 << 16) + (31 << 5) + 30, // PUNCT -> UPPER -> DIGIT
    (10 << 16) + (31 << 5) + 29, // PUNCT -> UPPER -> MIXED
    0,
  },
};

// A reverse mapping from [mode][char] to the encoding for that character
// in that mode.  An entry of 0 indicates no mapping exists.
const int LBZX_AZTEC_CHAR_MAP_HEIGHT = 5;
const int LBZX_AZTEC_CHAR_MAP_WIDTH = 256;
static int LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_CHAR_MAP_HEIGHT][LBZX_AZTEC_CHAR_MAP_WIDTH];

// A map showing the available shift codes.  (The shifts to BINARY are not
// shown
int LBZX_AZTEC_SHIFT_TABLE[LBZX_AZTEC_SHIFT_TABLE_SIZE][LBZX_AZTEC_SHIFT_TABLE_SIZE];

@interface LBZXAztecHighLevelEncoder ()

@property (nonatomic, assign, readonly) LBZXByteArray *text;

@end

@implementation LBZXAztecHighLevelEncoder

+ (void)load {
  LBZX_AZTEC_MODE_NAMES = @[@"UPPER", @"LOWER", @"DIGIT", @"MIXED", @"PUNCT"];

  memset(LBZX_AZTEC_CHAR_MAP, 0, LBZX_AZTEC_CHAR_MAP_HEIGHT * LBZX_AZTEC_CHAR_MAP_WIDTH * sizeof(int));
  LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_UPPER][' '] = 1;
  for (int c = 'A'; c <= 'Z'; c++) {
    LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_UPPER][c] = c - 'A' + 2;
  }
  LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_LOWER][' '] = 1;
  for (int c = 'a'; c <= 'z'; c++) {
    LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_LOWER][c] = c - 'a' + 2;
  }
  LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_DIGIT][' '] = 1;
  for (int c = '0'; c <= '9'; c++) {
    LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_DIGIT][c] = c - '0' + 2;
  }
  LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_DIGIT][','] = 12;
  LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_DIGIT]['.'] = 13;

  const int mixedTable[] = {
    '\0', ' ', '\1', '\2', '\3', '\4', '\5', '\6', '\7', '\b', '\t', '\n',
    '\13', '\f', '\r', '\33', '\34', '\35', '\36', '\37', '@', '\\', '^',
    '_', '`', '|', '~', '\177'
  };
  for (int i = 0; i < sizeof(mixedTable) / sizeof(int); i++) {
    LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_MIXED][mixedTable[i]] = i;
  }

  const int punctTable[] = {
    '\0', '\r', '\0', '\0', '\0', '\0', '!', '\'', '#', '$', '%', '&', '\'',
    '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?',
    '[', ']', '{', '}'
  };
  for (int i = 0; i < sizeof(punctTable) / sizeof(int); i++) {
    if (punctTable[i] > 0) {
      LBZX_AZTEC_CHAR_MAP[LBZX_AZTEC_MODE_PUNCT][punctTable[i]] = i;
    }
  }

  memset(LBZX_AZTEC_SHIFT_TABLE, -1, LBZX_AZTEC_SHIFT_TABLE_SIZE * LBZX_AZTEC_SHIFT_TABLE_SIZE * sizeof(int));
  LBZX_AZTEC_SHIFT_TABLE[LBZX_AZTEC_MODE_UPPER][LBZX_AZTEC_MODE_PUNCT] = 0;

  LBZX_AZTEC_SHIFT_TABLE[LBZX_AZTEC_MODE_LOWER][LBZX_AZTEC_MODE_PUNCT] = 0;
  LBZX_AZTEC_SHIFT_TABLE[LBZX_AZTEC_MODE_LOWER][LBZX_AZTEC_MODE_UPPER] = 28;

  LBZX_AZTEC_SHIFT_TABLE[LBZX_AZTEC_MODE_MIXED][LBZX_AZTEC_MODE_PUNCT] = 0;

  LBZX_AZTEC_SHIFT_TABLE[LBZX_AZTEC_MODE_DIGIT][LBZX_AZTEC_MODE_PUNCT] = 0;
  LBZX_AZTEC_SHIFT_TABLE[LBZX_AZTEC_MODE_DIGIT][LBZX_AZTEC_MODE_UPPER] = 15;
}

- (id)initWithText:(LBZXByteArray *)text {
  if (self = [super init]) {
    _text = text;
  }

  return self;
}

- (LBZXBitArray *)encode {
  NSArray *states = @[[LBZXAztecState initialState]];
  for (int index = 0; index < self.text.length; index++) {
    int pairCode;
    int nextChar = index + 1 < self.text.length ? self.text.array[index + 1] : 0;
    switch (self.text.array[index]) {
      case '\r':
        pairCode = nextChar == '\n' ? 2 : 0;
        break;
      case '.' :
        pairCode = nextChar == ' '  ? 3 : 0;
        break;
      case ',' :
        pairCode = nextChar == ' ' ? 4 : 0;
        break;
      case ':' :
        pairCode = nextChar == ' ' ? 5 : 0;
        break;
      default:
        pairCode = 0;
    }
    if (pairCode > 0) {
      // We have one of the four special PUNCT pairs.  Treat them specially.
      // Get a new set of states for the two new characters.
      states = [self updateStateListForPair:states index:index pairCode:pairCode];
      index++;
    } else {
      // Get a new set of states for the new character.
      states = [self updateStateListForChar:states index:index];
    }
  }
  // We are left with a set of states.  Find the shortest one.
  LBZXAztecState *minState = [[states sortedArrayUsingComparator:^NSComparisonResult(LBZXAztecState *a, LBZXAztecState *b) {
    return a.bitCount - b.bitCount;
  }] firstObject];
  // Convert it to a bit array, and return.
  return [minState toBitArray:self.text];
}

// We update a set of states for a new character by updating each state
// for the new character, merging the results, and then removing the
// non-optimal states.
- (NSArray *)updateStateListForChar:(NSArray *)states index:(int)index {
  NSMutableArray *result = [NSMutableArray array];
  for (LBZXAztecState *state in states) {
    [self updateStateForChar:state index:index result:result];
  }
  return [self simplifyStates:result];
}

// Return a set of states that represent the possible ways of updating this
// state for the next character.  The resulting set of states are added to
// the "result" list.
- (void)updateStateForChar:(LBZXAztecState *)state index:(int)index result:(NSMutableArray *)result {
  unichar ch = (unichar) (self.text.array[index] & 0xFF);
  BOOL charInCurrentTable = LBZX_AZTEC_CHAR_MAP[state.mode][ch] > 0;
  LBZXAztecState *stateNoBinary = nil;
  for (int mode = 0; mode <= LBZX_AZTEC_MODE_PUNCT; mode++) {
    int charInMode = LBZX_AZTEC_CHAR_MAP[mode][ch];
    if (charInMode > 0) {
      if (!stateNoBinary) {
        // Only create stateNoBinary the first time it's required.
        stateNoBinary = [state endBinaryShift:index];
      }
      // Try generating the character by latching to its mode
      if (!charInCurrentTable || mode == state.mode || mode == LBZX_AZTEC_MODE_DIGIT) {
        // If the character is in the current table, we don't want to latch to
        // any other mode except possibly digit (which uses only 4 bits).  Any
        // other latch would be equally successful *after* this character, and
        // so wouldn't save any bits.
        LBZXAztecState *latch_state = [stateNoBinary latchAndAppend:mode value:charInMode];
        [result addObject:latch_state];
      }
      // Try generating the character by switching to its mode.
      if (!charInCurrentTable && LBZX_AZTEC_SHIFT_TABLE[state.mode][mode] >= 0) {
        // It never makes sense to temporarily shift to another mode if the
        // character exists in the current mode.  That can never save bits.
        LBZXAztecState *shift_state = [stateNoBinary shiftAndAppend:mode value:charInMode];
        [result addObject:shift_state];
      }
    }
  }
  if (state.binaryShiftByteCount > 0 || LBZX_AZTEC_CHAR_MAP[state.mode][ch] == 0) {
    // It's never worthwhile to go into binary shift mode if you're not already
    // in binary shift mode, and the character exists in your current mode.
    // That can never save bits over just outputting the char in the current mode.
    LBZXAztecState *binaryState = [state addBinaryShiftChar:index];
    [result addObject:binaryState];
  }
}

- (NSArray *)updateStateListForPair:(NSArray *)states index:(int)index pairCode:(int)pairCode {
  NSMutableArray *result = [NSMutableArray array];
  for (LBZXAztecState *state in states) {
    [self updateStateForPair:state index:index pairCode:pairCode result:result];
  }
  return [self simplifyStates:result];
}

- (void)updateStateForPair:(LBZXAztecState *)state index:(int)index pairCode:(int)pairCode result:(NSMutableArray *)result {
  LBZXAztecState *stateNoBinary = [state endBinaryShift:index];
  // Possibility 1.  Latch to LBZX_AZTEC_MODE_PUNCT, and then append this code
  [result addObject:[stateNoBinary latchAndAppend:LBZX_AZTEC_MODE_PUNCT value:pairCode]];
  if (state.mode != LBZX_AZTEC_MODE_PUNCT) {
    // Possibility 2.  Shift to LBZX_AZTEC_MODE_PUNCT, and then append this code.
    // Every state except LBZX_AZTEC_MODE_PUNCT (handled above) can shift
    [result addObject:[stateNoBinary shiftAndAppend:LBZX_AZTEC_MODE_PUNCT value:pairCode]];
  }
  if (pairCode == 3 || pairCode == 4) {
    // both characters are in DIGITS.  Sometimes better to just add two digits
    LBZXAztecState *digit_state = [[stateNoBinary
                             latchAndAppend:LBZX_AZTEC_MODE_DIGIT value:16 - pairCode]  // period or comma in DIGIT
                            latchAndAppend:LBZX_AZTEC_MODE_DIGIT value:1];             // space in DIGIT
    [result addObject:digit_state];
  }
  if (state.binaryShiftByteCount > 0) {
    // It only makes sense to do the characters as binary if we're already
    // in binary mode.
    LBZXAztecState *binaryState = [[state addBinaryShiftChar:index] addBinaryShiftChar:index + 1];
    [result addObject:binaryState];
  }
}

- (NSArray *)simplifyStates:(NSArray *)states {
  NSMutableArray *result = [NSMutableArray array];
  for (LBZXAztecState *newState in states) {
    BOOL add = YES;
    NSArray *resultCopy = [NSArray arrayWithArray:result];
    for (LBZXAztecState *oldState in resultCopy) {
      if ([oldState isBetterThanOrEqualTo:newState]) {
        add = NO;
        break;
      }
      if ([newState isBetterThanOrEqualTo:oldState]) {
        [result removeObject:oldState];
      }
    }
    if (add) {
      [result addObject:newState];
    }
  }
  return result;
}

@end

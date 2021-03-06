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

#import "LBZXIntArray.h"
#import "LBZXModulusGF.h"
#import "LBZXModulusPoly.h"

@interface LBZXModulusPoly ()

@property (nonatomic, strong, readonly) LBZXIntArray *coefficients;
@property (nonatomic, weak, readonly) LBZXModulusGF *field;

@end

@implementation LBZXModulusPoly

- (id)initWithField:(LBZXModulusGF *)field coefficients:(LBZXIntArray *)coefficients {
  if (self = [super init]) {
    if (coefficients.length == 0) {
      @throw [NSException exceptionWithName:@"IllegalArgumentException"
                                     reason:@"coefficients must have at least one element"
                                   userInfo:nil];
    }
    _field = field;
    int coefficientsLength = coefficients.length;
    if (coefficientsLength > 1 && coefficients.array[0] == 0) {
      // Leading term must be non-zero for anything except the constant polynomial "0"
      int firstNonZero = 1;
      while (firstNonZero < coefficientsLength && coefficients.array[firstNonZero] == 0) {
        firstNonZero++;
      }
      if (firstNonZero == coefficientsLength) {
        _coefficients = field.zero.coefficients;
      } else {
        _coefficients = [[LBZXIntArray alloc] initWithLength:coefficientsLength - firstNonZero];
        for (int i = 0; i < _coefficients.length; i++) {
          _coefficients.array[i] = coefficients.array[firstNonZero + i];
        }
      }
    } else {
      _coefficients = coefficients;
    }
  }

  return self;
}

/**
 * @return degree of this polynomial
 */
- (int)degree {
  return self.coefficients.length - 1;
}

/**
 * @return true iff this polynomial is the monomial "0"
 */
- (BOOL)zero {
  return self.coefficients.array[0] == 0;
}

/**
 * @return coefficient of x^degree term in this polynomial
 */
- (int)coefficient:(int)degree {
  return self.coefficients.array[self.coefficients.length - 1 - degree];
}

/**
 * @return evaluation of this polynomial at a given point
 */
- (int)evaluateAt:(int)a {
  if (a == 0) {
    return [self coefficient:0];
  }
  int size = self.coefficients.length;
  if (a == 1) {
    // Just the sum of the coefficients
    int result = 0;
    for (int i = 0; i < size; i++) {
      result = [self.field add:result b:self.coefficients.array[i]];
    }
    return result;
  }
  int result = self.coefficients.array[0];
  for (int i = 1; i < size; i++) {
    result = [self.field add:[self.field multiply:a b:result] b:self.coefficients.array[i]];
  }
  return result;
}

- (LBZXModulusPoly *)add:(LBZXModulusPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"LBZXModulusPolys do not have same LBZXModulusGF field"];
  }
  if (self.zero) {
    return other;
  }
  if (other.zero) {
    return self;
  }

  LBZXIntArray *smallerCoefficients = self.coefficients;
  LBZXIntArray *largerCoefficients = other.coefficients;
  if (smallerCoefficients.length > largerCoefficients.length) {
    LBZXIntArray *temp = smallerCoefficients;
    smallerCoefficients = largerCoefficients;
    largerCoefficients = temp;
  }
  LBZXIntArray *sumDiff = [[LBZXIntArray alloc] initWithLength:largerCoefficients.length];
  int lengthDiff = largerCoefficients.length - smallerCoefficients.length;
  // Copy high-order terms only found in higher-degree polynomial's coefficients
  memcpy(sumDiff.array, largerCoefficients.array, lengthDiff * sizeof(int32_t));

  for (int i = lengthDiff; i < largerCoefficients.length; i++) {
    sumDiff.array[i] = [self.field add:smallerCoefficients.array[i - lengthDiff] b:largerCoefficients.array[i]];
  }

  return [[LBZXModulusPoly alloc] initWithField:self.field coefficients:sumDiff];
}

- (LBZXModulusPoly *)subtract:(LBZXModulusPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"LBZXModulusPolys do not have same LBZXModulusGF field"];
  }
  if (self.zero) {
    return self;
  }
  return [self add:[other negative]];
}

- (LBZXModulusPoly *)multiply:(LBZXModulusPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"LBZXModulusPolys do not have same LBZXModulusGF field"];
  }
  if (self.zero || other.zero) {
    return self.field.zero;
  }
  LBZXIntArray *aCoefficients = self.coefficients;
  int aLength = aCoefficients.length;
  LBZXIntArray *bCoefficients = other.coefficients;
  int bLength = bCoefficients.length;
  LBZXIntArray *product = [[LBZXIntArray alloc] initWithLength:aLength + bLength - 1];
  for (int i = 0; i < aLength; i++) {
    int aCoeff = aCoefficients.array[i];
    for (int j = 0; j < bLength; j++) {
      product.array[i + j] = [self.field add:product.array[i + j]
                                     b:[self.field multiply:aCoeff b:bCoefficients.array[j]]];
    }
  }
  return [[LBZXModulusPoly alloc] initWithField:self.field coefficients:product];
}

- (LBZXModulusPoly *)negative {
  int size = self.coefficients.length;
  LBZXIntArray *negativeCoefficients = [[LBZXIntArray alloc] initWithLength:size];
  for (int i = 0; i < size; i++) {
    negativeCoefficients.array[i] = [self.field subtract:0 b:self.coefficients.array[i]];
  }
  return [[LBZXModulusPoly alloc] initWithField:self.field coefficients:negativeCoefficients];
}

- (LBZXModulusPoly *)multiplyScalar:(int)scalar {
  if (scalar == 0) {
    return self.field.zero;
  }
  if (scalar == 1) {
    return self;
  }
  int size = self.coefficients.length;
  LBZXIntArray *product = [[LBZXIntArray alloc] initWithLength:size];
  for (int i = 0; i < size; i++) {
    product.array[i] = [self.field multiply:self.coefficients.array[i] b:scalar];
  }
  return [[LBZXModulusPoly alloc] initWithField:self.field coefficients:product];
}

- (LBZXModulusPoly *)multiplyByMonomial:(int)degree coefficient:(int)coefficient {
  if (degree < 0) {
    [NSException raise:NSInvalidArgumentException format:@"Degree must be greater than 0."];
  }
  if (coefficient == 0) {
    return self.field.zero;
  }
  int size = self.coefficients.length;
  LBZXIntArray *product = [[LBZXIntArray alloc] initWithLength:size + degree];
  for (int i = 0; i < size; i++) {
    product.array[i] = [self.field multiply:self.coefficients.array[i] b:coefficient];
  }

  return [[LBZXModulusPoly alloc] initWithField:self.field coefficients:product];
}

- (NSArray *)divide:(LBZXModulusPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"LBZXModulusPolys do not have same LBZXModulusGF field"];
  }
  if (other.zero) {
    [NSException raise:NSInvalidArgumentException format:@"Divide by 0"];
  }

  LBZXModulusPoly *quotient = self.field.zero;
  LBZXModulusPoly *remainder = self;

  int denominatorLeadingTerm = [other coefficient:other.degree];
  int inverseDenominatorLeadingTerm = [self.field inverse:denominatorLeadingTerm];

  while ([remainder degree] >= other.degree && !remainder.zero) {
    int degreeDifference = remainder.degree - other.degree;
    int scale = [self.field multiply:[remainder coefficient:remainder.degree] b:inverseDenominatorLeadingTerm];
    LBZXModulusPoly *term = [other multiplyByMonomial:degreeDifference coefficient:scale];
    LBZXModulusPoly *iterationQuotient = [self.field buildMonomial:degreeDifference coefficient:scale];
    quotient = [quotient add:iterationQuotient];
    remainder = [remainder subtract:term];
  }

  return @[quotient, remainder];
}

- (NSString *)description {
  NSMutableString *result = [NSMutableString stringWithCapacity:8 * [self degree]];
  for (int degree = [self degree]; degree >= 0; degree--) {
    int coefficient = [self coefficient:degree];
    if (coefficient != 0) {
      if (coefficient < 0) {
        [result appendString:@" - "];
        coefficient = -coefficient;
      } else {
        if ([result length] > 0) {
          [result appendString:@" + "];
        }
      }
      if (degree == 0 || coefficient != 1) {
        [result appendFormat:@"%d", coefficient];
      }
      if (degree != 0) {
        if (degree == 1) {
          [result appendString:@"x"];
        } else {
          [result appendString:@"x^"];
          [result appendFormat:@"%d", degree];
        }
      }
    }
  }

  return result;
}

@end

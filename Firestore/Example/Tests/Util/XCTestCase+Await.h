/*
 * Copyright 2017 Google
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

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Force the linker to see these extensions even if compiled without -ObjC.
 */
void LoadXCTestCaseAwait();

/**
 * FSTVoidErrorBlock is a block that gets an error, if one occurred.
 *
 * @param error The error if it occurred, or nil.
 */
typedef void (^FSTVoidErrorBlock)(NSError *_Nullable error);

@interface XCTestCase (Await)

/**
 * Await all outstanding expectations with a reasonable timeout, and if any of them fail, XCTFail
 * the test.
 */
- (void)awaitExpectations;

/**
 * Await a specific expectation with a reasonable timeout. If the expectation fails, XCTFail the
 * test.
 */
- (void)awaitExpectation:(XCTestExpectation *)expectation;

/**
 * Returns a reasonable timeout for testing against Firestore.
 */
- (double)defaultExpectationWaitSeconds;

/**
 * Returns a completion block that fulfills a newly-created expectation with the specified
 * name.
 */
- (FSTVoidErrorBlock)completionForExpectationWithName:(NSString *)expectationName;

/**
 * Returns a completion block that fulfills the given expectation.
 */
- (FSTVoidErrorBlock)completionForExpectation:(XCTestExpectation *)expectation;

@end

NS_ASSUME_NONNULL_END

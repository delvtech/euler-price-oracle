// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {LibPRNG} from "@solady/utils/LibPRNG.sol";
import {AggregatorFunctionsHarness} from "test/utils/AggregatorFunctionsHarness.sol";
import {Aggregator} from "src/strategy/aggregator/Aggregator.sol";

contract AggregatorFunctionsTest is Test {
    uint256 private constant SHUFFLE_ITERATIONS = 10;
    AggregatorFunctionsHarness private immutable algorithms;

    constructor() {
        algorithms = new AggregatorFunctionsHarness();
    }

    function test_Max_Concrete(LibPRNG.PRNG memory prng) public {
        uint256[] memory quotes = new uint256[](3);
        quotes[0] = 0;
        quotes[1] = 2;
        quotes[2] = 1;

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 result = algorithms.max(quotes);
            assertEq(result, 2);
        }
    }

    function test_Max_Integrity(LibPRNG.PRNG memory prng, uint256[] memory quotes, uint256 k) public {
        vm.assume(quotes.length > 0);
        vm.assume(k < quotes.length);

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 result = algorithms.max(quotes);
            assertGe(result, quotes[k]);
        }
    }

    function test_Mean_Concrete(LibPRNG.PRNG memory prng) public {
        uint256[] memory quotes = new uint256[](3);
        quotes[0] = 0;
        quotes[1] = 2;
        quotes[2] = 1;

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 result = algorithms.mean(quotes);
            assertEq(result, 1);
        }
    }

    function test_Median_Concrete(LibPRNG.PRNG memory prng) public {
        uint256[] memory quotes = new uint256[](3);
        quotes[0] = 0;
        quotes[1] = 2;
        quotes[2] = 1;

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 result = algorithms.median(quotes);
            assertEq(result, 1);
        }
    }

    function test_Min_Concrete(LibPRNG.PRNG memory prng) public {
        uint256[] memory quotes = new uint256[](3);
        quotes[0] = 0;
        quotes[1] = 2;
        quotes[2] = 1;

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 result = algorithms.min(quotes);
            assertEq(result, 0);
        }
    }

    function test_Min_Integrity(LibPRNG.PRNG memory prng, uint256[] memory quotes, uint256 k) public {
        vm.assume(quotes.length > 0);
        vm.assume(k < quotes.length);

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 result = algorithms.min(quotes);
            assertLe(result, quotes[k]);
        }
    }

    function test_StatisticalIntegrity(uint256[] memory quotes) public {
        vm.assume(quotes.length != 0);
        _noSumOverflow(quotes);

        uint256 min = algorithms.min(quotes);
        uint256 mean = algorithms.mean(quotes);
        uint256 median = algorithms.median(quotes);
        uint256 max = algorithms.max(quotes);
        assertLe(min, max, "min <= max");
        assertLe(min, mean, "min <= mean");
        assertLe(min, median, "min <= median");
        assertLe(mean, max, "mean <= max");
        assertLe(median, max, "median <= max");
    }

    function test_StableUnderPermutation(uint256[] memory quotes, LibPRNG.PRNG memory prng) public {
        vm.assume(quotes.length != 0);
        _noSumOverflow(quotes);

        uint256 min = algorithms.min(quotes);
        uint256 mean = algorithms.mean(quotes);
        uint256 median = algorithms.median(quotes);
        uint256 max = algorithms.max(quotes);

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 _min = algorithms.min(quotes);
            uint256 _mean = algorithms.mean(quotes);
            uint256 _median = algorithms.median(quotes);
            uint256 _max = algorithms.max(quotes);

            assertLe(min, _min);
            assertLe(mean, _mean);
            assertLe(median, _median);
            assertLe(max, _max);
        }
    }

    function _noSumOverflow(uint256[] memory arr) private view {
        for (uint256 i = 0; i < arr.length; ++i) {
            arr[i] = bound(arr[i], 0, 2 ** 248);
        }
    }
}
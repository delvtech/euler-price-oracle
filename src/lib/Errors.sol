// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Stores common errors in Oracles.
/// @dev Collected here to reduce clutter in oracle contracts.
library Errors {
    error Chainlink_CallReverted(bytes reason);
    error Chainlink_InvalidAnswer(int256 answer);
    error Chainlink_RoundIncomplete();
    error EOracle_NotSupported(address base, address quote);
    error EOracle_Overflow();
    error EOracle_TooStale(uint256 staleness, uint256 maxStaleness);
    error Governance_AlreadyInitialized();
    error Governance_CallerNotGovernor();
    error Pyth_InvalidConfidenceInterval(int64 price, uint64 conf);
    error Pyth_InvalidExponent(int32 expo);
    error Pyth_InvalidPrice(int64 price);
    error UniswapV3_ObservationsNotInitialized(uint256 availableAtBlock);
    error UniswapV3_TwapWindowTooLong(uint32 twapWindow, uint32 maxTwapWindow);
}

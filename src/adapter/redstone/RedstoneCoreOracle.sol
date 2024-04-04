// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {console2} from "forge-std/console2.sol";
import {RedstoneDefaultsLib} from "@redstone/evm-connector/core/RedstoneDefaultsLib.sol";
import {PrimaryProdDataServiceConsumerBase} from
    "@redstone/evm-connector/data-services/PrimaryProdDataServiceConsumerBase.sol";
import {BaseAdapter, Errors} from "src/adapter/BaseAdapter.sol";
import {ScaleUtils, Scale} from "src/lib/ScaleUtils.sol";

/// @title RedstoneCoreOracle
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Adapter for Redstone pull-based price feeds.
contract RedstoneCoreOracle is PrimaryProdDataServiceConsumerBase, BaseAdapter {
    /// @notice The address of the base asset corresponding to the feed.
    address public immutable base;
    /// @notice The address of the quote asset corresponding to the feed.
    address public immutable quote;
    /// @notice The identifier of the price feed.
    /// @dev See https://app.redstone.finance/#/app/data-services/redstone-primary-prod
    bytes32 public immutable feedId;
    /// @notice The decimals of the Redstone price feed.
    /// @dev Redstone price feeds have 8 decimals by default, however certain exceptions exist.
    uint8 public immutable feedDecimals;
    /// @notice The maximum allowed age of the Redstone price.
    /// @dev Compares `block.timestamp` against the timestamp of the Redstone data package in `updatePrice`.
    uint256 public immutable maxPriceStaleness;
    /// @notice The maximum allowed age of the cached price.
    /// @dev Compares `block.timestamp` against the timestamp of the cached price `_getQuote`.
    uint256 public immutable maxCacheStaleness;
    /// @notice The scale factors used for decimal conversions.
    Scale internal immutable scale;
    /// @notice The last updated price.
    /// @dev This gets updated after calling `updatePrice`.
    uint208 public cachedPrice;
    /// @notice The timestamp of the last update.
    /// @dev Gets updated to `block.timestamp` after calling `updatePrice`.
    uint48 public cacheUpdatedAt;

    /// @notice Deploy a RedstoneCoreOracle.
    /// @param _base The address of the base asset corresponding to the feed.
    /// @param _quote The address of the quote asset corresponding to the feed.
    /// @param _feedId The identifier of the price feed.
    /// @param _feedDecimals The decimals of the price feed.
    /// @param _maxPriceStaleness The maximum allowed age of the Redstone price in `updatePrice`.
    /// @param _maxCacheStaleness The maximum allowed age of the cached price in `_getQuote`.
    /// @dev Base and quote are not required to correspond to the feed assets.
    /// Note: Since the signed Redstone price is verified locally, callers are theoretically
    /// able to use any Redstone price between `now - maxPriceStaleness` and `now`.
    /// On the other hand, `maxStaleness` effectively imposes a deadline on the transaction,
    /// so choosing an acceptance that is too short increases the change that the transaction is dropped,
    /// especially during chain congestion.
    constructor(
        address _base,
        address _quote,
        bytes32 _feedId,
        uint8 _feedDecimals,
        uint256 _maxPriceStaleness,
        uint256 _maxCacheStaleness
    ) {
        base = _base;
        quote = _quote;
        feedId = _feedId;
        feedDecimals = _feedDecimals;
        maxPriceStaleness = _maxPriceStaleness;
        maxCacheStaleness = _maxCacheStaleness;
        uint8 baseDecimals = _getDecimals(base);
        uint8 quoteDecimals = _getDecimals(quote);
        scale = ScaleUtils.calcScale(baseDecimals, quoteDecimals, _feedDecimals);
    }

    /// @notice Ingest a signed update message and cache it on the contract.
    /// @dev Validation logic inherited from PrimaryProdDataServiceConsumerBase.
    function updatePrice() external {
        // Use the cache if it has not expired.
        if (block.timestamp < uint256(cacheUpdatedAt) + maxCacheStaleness) return;
        uint256 price = getOracleNumericValueFromTxMsg(feedId);
        if (price > type(uint208).max) revert Errors.PriceOracle_Overflow();
        cachedPrice = uint208(price);
        cacheUpdatedAt = uint48(block.timestamp);
    }

    /// @notice Validate the timestamp of a Redstone signed price data package.
    /// @param timestampMillis Data package timestamp in milliseconds.
    /// @dev This function will be called in `getOracleNumericValueFromTxMsg` in `getQuote`,
    /// overriding the accepted range to `[now - 1 minute, now + maxPriceStaleness]`.
    /// Notably there are cases where the data timestamp is ahead of `block.timestamp`.
    /// This is an artifact of the Redstone system and we don't override this behavior.
    function validateTimestamp(uint256 timestampMillis) public view virtual override {
        uint256 timestamp = timestampMillis / 1000;
        if (block.timestamp > timestamp && block.timestamp - timestamp > maxPriceStaleness) {
            revert Errors.PriceOracle_InvalidAnswer();
        } else if (
            block.timestamp < timestamp
                && timestamp - block.timestamp > RedstoneDefaultsLib.DEFAULT_MAX_DATA_TIMESTAMP_AHEAD_SECONDS
        ) {
            revert Errors.PriceOracle_InvalidAnswer();
        }
    }

    /// @notice Get the quote from the Redstone feed.
    /// @param inAmount The amount of `base` to convert.
    /// @param _base The token that is being priced.
    /// @param _quote The token that is the unit of account.
    /// @return The converted amount using the Redstone feed.
    function _getQuote(uint256 inAmount, address _base, address _quote) internal view override returns (uint256) {
        bool inverse = ScaleUtils.getDirectionOrRevert(_base, base, _quote, quote);

        uint256 cacheStaleness = block.timestamp - cacheUpdatedAt;
        if (cacheStaleness > maxCacheStaleness) revert Errors.PriceOracle_TooStale(cacheStaleness, maxCacheStaleness);

        return ScaleUtils.calcOutAmount(inAmount, cachedPrice, scale, inverse);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {HyperdriveMultiToken} from "@hyperdrive/src/internal/HyperdriveMultiToken.sol";
import {AssetId} from "@hyperdrive/src/libraries/AssetId.sol";
import {YieldSpaceMath} from "@hyperdrive/src/libraries/YieldSpaceMath.sol";
import {BaseAdapter, Errors, IPriceOracle} from "../BaseAdapter.sol";
import {ScaleUtils, Scale} from "../../lib/ScaleUtils.sol";

/// @title HyperdriveOracle
/// @author Mihai Cosma (https://www.delv.tech/)
/// @notice Adapter for Hyperdrive ERC1155 Oracle with built-in helper functions
contract HyperdriveOracle is BaseAdapter {
    /// @inheritdoc IPriceOracle
    string public constant name = "HyperdriveOracle";

    /// @notice The address of the Hyperdrive MultiToken contract
    address public immutable hyperdriveToken;

    /// @notice The scale factors used for decimal conversions
    Scale internal immutable scale;

    /// @notice Deploy a HyperdriveOracle
    /// @param _hyperdriveToken The address of the Hyperdrive MultiToken contract
    constructor(address _hyperdriveToken) {
        if (_hyperdriveToken == address(0)) {
            revert Errors.PriceOracle_InvalidConfiguration();
        }

        hyperdriveToken = _hyperdriveToken;
        // Note: ERC1155 doesn't have a standard decimals() function
        // We'll need to implement proper scaling based on Hyperdrive's token implementation
        uint8 baseDecimals = 18; // TODO: Get from Hyperdrive implementation
        uint8 quoteDecimals = 18; // TODO: Get from Hyperdrive implementation
        scale = ScaleUtils.calcScale(baseDecimals, quoteDecimals, 18);
    }

    /// @notice Convenience function to get quote directly with Hyperdrive parameters
    /// @param inAmount The amount of base to convert
    /// @param assetType The type of position (LP, Long, Short, WithdrawalShare)
    /// @param maturityTimestamp The maturity timestamp for the position
    /// @param quote The token that is the unit of account
    /// @return The converted amount using the Hyperdrive pricing mechanism
    function getHyperdriveQuote(
        uint256 inAmount,
        AssetId.AssetIdPrefix assetType,
        uint256 maturityTimestamp,
        address quote
    ) external view returns (uint256) {
        address encodedBase = _encodeAssetAddress(assetType, maturityTimestamp);
        return this.getQuote(inAmount, encodedBase, quote);
    }

    /// @notice Convert Hyperdrive token parameters into an address for oracle queries
    /// @param assetType The type of position (LP, Long, Short, WithdrawalShare)
    /// @param maturityTimestamp The maturity timestamp for the position
    /// @return The encoded address to use with the oracle
    function _encodeAssetAddress(
        AssetId.AssetIdPrefix assetType,
        uint256 maturityTimestamp
    ) internal pure returns (address) {
        // Get the token ID using Hyperdrive's library
        uint256 tokenId = AssetId.encodeAssetId(assetType, maturityTimestamp);

        // Convert token ID to address - keep only the timestamp part and add the prefix in the high bits
        return address(uint160(tokenId & type(uint160).max) | (uint160(uint8(assetType)) << 156));
    }

    /// @notice Get a quote for Hyperdrive ERC1155 tokens
    /// @param inAmount The amount of `base` to convert
    /// @param _base The token that is being priced (encoded with position type and maturity)
    /// @param _quote The token that is the unit of account
    /// @return The converted amount using the Hyperdrive pricing mechanism
    function _getQuote(uint256 inAmount, address _base, address _quote) internal view override returns (uint256) {
        // Extract asset ID from the encoded base address
        (AssetId.AssetIdPrefix prefix, uint256 maturityTimestamp) = _decodeAssetId(_base);

        // Get price based on position type
        uint256 price;
        if (prefix == AssetId.AssetIdPrefix.LP) {
            // TODO: Implement LP token pricing
            price = 1e18; // Placeholder
        } else if (prefix == AssetId.AssetIdPrefix.Long) {
            // TODO: Implement long position pricing using YieldSpaceMath
            price = 1e18; // Placeholder
        } else if (prefix == AssetId.AssetIdPrefix.Short) {
            // TODO: Implement short position pricing using YieldSpaceMath
            price = 1e18; // Placeholder
        } else if (prefix == AssetId.AssetIdPrefix.WithdrawalShare) {
            // TODO: Implement withdrawal share pricing
            price = 1e18; // Placeholder
        } else {
            revert Errors.PriceOracle_InvalidConfiguration();
        }

        // Apply scaling and return quote
        return ScaleUtils.calcOutAmount(inAmount, price, scale, true);
    }

    /// @dev Decode the asset ID from an encoded address
    /// @param encodedAddress The address containing encoded position information
    /// @return prefix The position type
    /// @return timestamp The maturity timestamp
    function _decodeAssetId(address encodedAddress) internal pure returns (AssetId.AssetIdPrefix prefix, uint256 timestamp) {
        // Extract prefix from high bits and timestamp from low bits
        prefix = AssetId.AssetIdPrefix(uint8(uint160(encodedAddress) >> 156));
        timestamp = uint256(uint160(encodedAddress) & ((1 << 156) - 1));
    }

    /// @dev Exposed version of _decodeAssetId for testing
    function exposed_decodeAssetId(address encodedAddress) public pure returns (AssetId.AssetIdPrefix prefix, uint256 timestamp) {
        return _decodeAssetId(encodedAddress);
    }

    /// @dev Exposed version of _encodeAssetAddress for testing
    function exposed_encodeAssetAddress(
        AssetId.AssetIdPrefix assetType,
        uint256 maturityTimestamp
    ) public pure returns (address) {
        return _encodeAssetAddress(assetType, maturityTimestamp);
    }
}

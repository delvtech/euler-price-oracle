// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IPyth} from "@pyth/IPyth.sol";
import {PythStructs} from "@pyth/PythStructs.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";
import {IEOracle} from "src/interfaces/IEOracle.sol";
import {Errors} from "src/lib/Errors.sol";
import {OracleDescription} from "src/lib/OracleDescription.sol";

/// @title PythOracle
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EOracle adapter for Pyth pull-based price feeds.
/// @dev Supports bid-ask pricing with the 95% confidence interval from Pyth.
contract PythOracle is IEOracle {
    /// @dev The confidence interval can be at most 10% wide.
    uint256 internal constant MAX_CONF_WIDTH_BPS = 500;
    /// @notice The address of the Pyth oracle proxy.
    IPyth public immutable pyth;
    /// @notice The address of the base asset corresponding to the feed.
    address public immutable base;
    /// @notice The address of the quote asset corresponding to the feed.
    address public immutable quote;
    /// @notice The id of the feed in the Pyth network.
    /// @dev See https://pyth.network/developers/price-feed-ids.
    bytes32 public immutable feedId;
    /// @notice The maximum allowed age of the latest price update.
    uint256 public immutable maxStaleness;
    /// @notice Whether the feed returns the price of base/quote or quote/base.
    bool public immutable inverse;
    /// @dev Used for correcting for the decimals of base and quote.
    int8 internal immutable scaleExponent;

    /// @notice Deploy a PythOracle.
    /// @param _pyth The address of the Pyth oracle proxy.
    /// @param _base The address of the base asset corresponding to the feed.
    /// @param _quote The address of the quote asset corresponding to the feed.
    /// @param _feedId The id of the feed in the Pyth network.
    /// @param _maxStaleness The maximum allowed age of the latest price update.
    /// @param _inverse Whether the feed returns the price of base/quote or quote/base.
    constructor(address _pyth, address _base, address _quote, bytes32 _feedId, uint256 _maxStaleness, bool _inverse) {
        pyth = IPyth(_pyth);
        base = _base;
        quote = _quote;
        feedId = _feedId;
        maxStaleness = _maxStaleness;
        inverse = _inverse;
        uint8 baseDecimals = ERC20(_base).decimals();
        uint8 quoteDecimals = ERC20(_quote).decimals();
        scaleExponent = inverse ? int8(baseDecimals) - int8(quoteDecimals) : int8(quoteDecimals) - int8(baseDecimals);
    }

    /// @notice Update the price of the Pyth feed.
    /// @param updateData Price update data. Must be fetched off-chain.
    /// @dev The required fee can be computed by calling `getUpdateFee` on Pyth with the length of the `updateData` array.
    function updatePrice(bytes[] calldata updateData) external payable {
        IPyth(pyth).updatePriceFeeds{value: msg.value}(updateData);
    }

    /// @inheritdoc IEOracle
    function getQuote(uint256 inAmount, address _base, address _quote) external view returns (uint256) {
        PythStructs.Price memory priceStruct = _fetchPriceStruct(_base, _quote);
        uint64 midPrice = uint64(priceStruct.price);
        int32 exponent = priceStruct.expo + scaleExponent;

        if (inverse) {
            return _calcOutAmountInverse(inAmount, midPrice, exponent);
        } else {
            return _calcOutAmount(inAmount, midPrice, exponent);
        }
    }

    /// @inheritdoc IEOracle
    /// @dev Supports bid-ask pricing with the 95% confidence interval from Pyth.
    function getQuotes(uint256 inAmount, address _base, address _quote) external view returns (uint256, uint256) {
        PythStructs.Price memory priceStruct = _fetchPriceStruct(_base, _quote);
        uint256 bidPrice = uint256(int256(priceStruct.price) - int64(priceStruct.conf));
        uint256 askPrice = uint256(int256(priceStruct.price) + int64(priceStruct.conf));
        int32 exponent = priceStruct.expo + scaleExponent;

        if (inverse) {
            return (
                _calcOutAmountInverse(inAmount, askPrice, exponent), _calcOutAmountInverse(inAmount, bidPrice, exponent)
            );
        } else {
            return (_calcOutAmount(inAmount, bidPrice, exponent), _calcOutAmount(inAmount, askPrice, exponent));
        }
    }

    /// @inheritdoc IEOracle
    function description() external view returns (OracleDescription.Description memory) {
        return OracleDescription.PythOracle(maxStaleness);
    }

    /// @notice Get the latest Pyth price and perform sanity checks.
    /// @param _base The address of the base asset corresponding to the feed.
    /// @param _quote The address of the quote asset corresponding to the feed.
    /// @dev Reverts if base/quote mistamch, price is non-positive, confidence is too wide, or exponent is too large.
    function _fetchPriceStruct(address _base, address _quote) internal view returns (PythStructs.Price memory) {
        if (_base != base || _quote != quote) revert Errors.EOracle_NotSupported(_base, _quote);
        PythStructs.Price memory p = pyth.getPriceNoOlderThan(feedId, maxStaleness);
        if (p.price <= 0) {
            revert Errors.Pyth_InvalidPrice(p.price);
        }

        if (p.conf > uint64(p.price) * MAX_CONF_WIDTH_BPS / 10_000) {
            revert Errors.Pyth_InvalidConfidenceInterval(p.price, p.conf);
        }

        if (p.expo > 16 || p.expo < -16) {
            revert Errors.Pyth_InvalidExponent(p.expo);
        }
        return p;
    }

    /// @dev Calculate the `outAmount` for an inverted feed given price and exponent.
    /// @param inAmount The input amount.
    /// @param price The price returned by Pyth.
    /// @param exponent The exponent returned by Pyth plus the scaling exponent.
    /// Formula: inAmount / (price * 10^exponent).
    function _calcOutAmountInverse(uint256 inAmount, uint256 price, int32 exponent) internal pure returns (uint256) {
        if (exponent > 0) {
            return (inAmount / (price * 10 ** uint32(exponent)));
        } else {
            return (inAmount * 10 ** uint32(-exponent) / price);
        }
    }

    /// @dev Calculate the `outAmount` for a feed given price and exponent.
    /// @param inAmount The input amount.
    /// @param price The price returned by Pyth.
    /// @param exponent The exponent returned by Pyth plus the scaling exponent.
    /// Formula: inAmount * price * 10^exponent.
    function _calcOutAmount(uint256 inAmount, uint256 price, int32 exponent) internal pure returns (uint256) {
        if (exponent > 0) {
            return (inAmount * price * 10 ** uint32(exponent));
        } else {
            return (inAmount * price / 10 ** uint32(-exponent));
        }
    }
}

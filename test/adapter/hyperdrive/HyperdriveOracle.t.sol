// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {AssetId} from "@hyperdrive/src/libraries/AssetId.sol";
import {HyperdriveOracle} from "../../../src/adapter/hyperdrive/HyperdriveOracle.sol";

contract HyperdriveOracleTest is Test {
    HyperdriveOracle oracle;
    address constant MOCK_TOKEN = address(0x123);
    uint256 constant MOCK_TIMESTAMP = 1703000000; // Some future timestamp

    function setUp() public {
        oracle = new HyperdriveOracle(MOCK_TOKEN);
    }

    function test_encodeDecode() public {
        // Test each asset type
        AssetId.AssetIdPrefix[] memory types = new AssetId.AssetIdPrefix[](4);
        types[0] = AssetId.AssetIdPrefix.LP;
        types[1] = AssetId.AssetIdPrefix.Long;
        types[2] = AssetId.AssetIdPrefix.Short;
        types[3] = AssetId.AssetIdPrefix.WithdrawalShare;

        for (uint i = 0; i < types.length; i++) {
            // Get encoded address
            address encoded = oracle.getHyperdriveQuote(1e18, types[i], MOCK_TIMESTAMP, address(0));

            // Decode and log
            (AssetId.AssetIdPrefix decodedType, uint256 decodedTime) = oracle.exposed_decodeAssetId(encoded);

            console2.log("Asset Type:", uint8(types[i]));
            console2.log("Encoded Address:", encoded);
            console2.log("Decoded Type:", uint8(decodedType));
            console2.log("Decoded Time:", decodedTime);
            console2.log("---");

            // Verify
            assertEq(uint8(decodedType), uint8(types[i]), "Type mismatch");
            assertEq(decodedTime, MOCK_TIMESTAMP, "Timestamp mismatch");
        }
    }
}

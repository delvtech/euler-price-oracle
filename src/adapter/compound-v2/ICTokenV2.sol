// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

interface ICTokenV2 {
    function exchangeRateStored() external view returns (uint256);
    function underlying() external view returns (address);
}

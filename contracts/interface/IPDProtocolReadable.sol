// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { ID4AProtocolReadable } from "./ID4AProtocolReadable.sol";

interface IPDProtocolReadable is ID4AProtocolReadable {
    // protocol related functions
    function getNFTTokenCanvas(bytes32 daoId, uint256 tokenId) external view returns (bytes32);

    function getLastestDaoIndex() external view returns (uint256);

    function getDaoId(uint256 daoIndex) external view returns (bytes32);
}
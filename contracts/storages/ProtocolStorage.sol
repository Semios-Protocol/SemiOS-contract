// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library ProtocolStorage {
    struct LokcedInfo {
        uint256 duration;
        uint256 lockStartBlock;
    }

    struct Layout {
        mapping(bytes32 => bytes32) nftHashToCanvasId;
        mapping(bytes32 => bool) uriExists;
        uint256[256] lastestDaoIndexes;
        uint256 d4aDaoIndexBitMap;
        uint256 basicDaoIndexBitMap;
        mapping(uint256 daoIndex => bytes32 daoId)[256] daoIndexToIds;
        //1.5 add-----------------------------------------
        mapping(bytes32 nftHash => LokcedInfo) lockedInfo;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("D4Av2.contracts.storage.ProtocolStorage");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

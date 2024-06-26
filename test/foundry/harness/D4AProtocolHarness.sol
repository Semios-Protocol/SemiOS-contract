// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { DaoStorage } from "contracts/storages/DaoStorage.sol";
import { PDProtocol } from "contracts/PDProtocol.sol";

contract D4AProtocolHarness is PDProtocol {
    function exposed_MINTNFT_TYPEHASH() public pure returns (bytes32) {
        return _MINTNFT_TYPEHASH;
    }

    function exposed_daoMintInfos(bytes32 daoId) public view returns (uint32 daoMintCap) {
        return DaoStorage.layout().daoInfos[daoId].daoMintInfo.daoMintCap;
    }

    function exposed_checkMintEligibility(
        bytes32 daoId,
        address account,
        bytes32[] calldata proof,
        uint256 amount
    )
        public
        view
    {
        _checkMintEligibility(daoId, account, proof, 1, amount);
    }

    function exposed_ableToMint(
        bytes32 daoId,
        address account,
        bytes32[] calldata proof,
        uint256 amount
    )
        public
        view
        returns (bool)
    {
        return _ableToMint(daoId, account, proof, amount);
    }

    function exposed_verifySignature(
        bytes32 daoId,
        bytes32 canvasId,
        string calldata tokenUri,
        uint256 flatPrice,
        bytes calldata signature
    )
        public
        view
    {
        _verifySignature(daoId, canvasId, tokenUri, flatPrice, signature);
    }
}

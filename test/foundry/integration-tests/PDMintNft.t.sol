// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { DeployHelper } from "test/foundry/utils/DeployHelper.sol";

import { NotInWhitelist, ExceedMinterMaxMintAmount } from "contracts/interface/D4AErrors.sol";
import { D4AERC721 } from "contracts/D4AERC721.sol";
import "contracts/interface/D4AStructs.sol";

contract PDMintNftTest is DeployHelper {
    function setUp() public {
        setUpEnv();
    }

    function test_RevertIf_NoNftAsPass() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.uniPriceModeOff = true;
        param.topUpMode = false;
        param.isProgressiveJackpot = false;
        param.needMintableWork = true;
        bytes32 daoId = _createDaoForFunding(param, daoCreator.addr);

        bytes32 canvasId = param.canvasId;
        string memory tokenUri = string.concat(
            tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
        );
        uint256 flatPrice = 0.01 ether;
        bytes32 digest = mintNftSigUtils.getTypedDataHash(canvasId, tokenUri, flatPrice);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(daoCreator.key, digest);
        vm.expectRevert(ExceedMinterMaxMintAmount.selector);
        hoax(nftMinter.addr);
        CreateCanvasAndMintNFTParam memory mintNftTransferParam;
        mintNftTransferParam.daoId = daoId;
        mintNftTransferParam.canvasId = canvasId;
        mintNftTransferParam.tokenUri = tokenUri;
        mintNftTransferParam.proof = new bytes32[](0);
        mintNftTransferParam.flatPrice = flatPrice;
        mintNftTransferParam.nftSignature = abi.encodePacked(r, s, v);
        mintNftTransferParam.nftOwner = nftMinter.addr;
        mintNftTransferParam.erc20Signature = "";
        mintNftTransferParam.deadline = 0;
        protocol.mintNFT{ value: flatPrice }(mintNftTransferParam);
    }

    function test_CanOnlyMintFiveNfts() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.uniPriceModeOff = true;
        param.topUpMode = false;
        param.isProgressiveJackpot = false;
        param.needMintableWork = true;
        bytes32 daoId = _createDaoForFunding(param, daoCreator.addr);

        _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            daoCreator.addr
        );
        _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(2)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            daoCreator.addr
        );
        _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(3)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            daoCreator.addr
        );
        _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(4)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            daoCreator.addr
        );
        _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(5)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            daoCreator.addr
        );

        bytes32 canvasId = param.canvasId;
        string memory tokenUri = string.concat(
            tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(6)), ".json"
        );
        uint256 flatPrice = 0.01 ether;
        bytes32 digest = mintNftSigUtils.getTypedDataHash(canvasId, tokenUri, flatPrice);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(daoCreator.key, digest);

        //  直接调用mintNFT无法正确获取错误，因此需要使用下面的铸造方式
        vm.expectRevert(ExceedMinterMaxMintAmount.selector);
        vm.prank(daoCreator.addr);
        CreateCanvasAndMintNFTParam memory mintNftTransferParam;
        mintNftTransferParam.daoId = daoId;
        mintNftTransferParam.canvasId = canvasId;
        mintNftTransferParam.tokenUri = tokenUri;
        mintNftTransferParam.proof = new bytes32[](0);
        mintNftTransferParam.flatPrice = flatPrice;
        mintNftTransferParam.nftSignature = abi.encodePacked(r, s, v);
        mintNftTransferParam.nftOwner = daoCreator.addr;
        mintNftTransferParam.erc20Signature = "";
        mintNftTransferParam.deadline = 0;
        protocol.mintNFT{ value: flatPrice }(mintNftTransferParam);
    }

    function test_CanMintOnceHaveNft() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.uniPriceModeOff = true;
        param.topUpMode = false;
        param.isProgressiveJackpot = false;
        param.needMintableWork = true;
        bytes32 daoId = _createDaoForFunding(param, daoCreator.addr);

        {
            bytes32 canvasId = param.canvasId;
            string memory tokenUri = string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
            );
            uint256 flatPrice = 0.01 ether;
            bytes32 digest = mintNftSigUtils.getTypedDataHash(canvasId, tokenUri, flatPrice);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(daoCreator.key, digest);
            vm.expectRevert(ExceedMinterMaxMintAmount.selector);
            hoax(nftMinter.addr);
            CreateCanvasAndMintNFTParam memory mintNftTransferParam;
            mintNftTransferParam.daoId = daoId;
            mintNftTransferParam.canvasId = canvasId;
            mintNftTransferParam.tokenUri = tokenUri;
            mintNftTransferParam.proof = new bytes32[](0);
            mintNftTransferParam.flatPrice = flatPrice;
            mintNftTransferParam.nftSignature = abi.encodePacked(r, s, v);
            mintNftTransferParam.nftOwner = nftMinter.addr;
            mintNftTransferParam.erc20Signature = "";
            mintNftTransferParam.deadline = 0;
            protocol.mintNFT{ value: flatPrice }(mintNftTransferParam);
        }

        _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            daoCreator.addr
        );
        {
            address nft = protocol.getDaoNft(daoId);
            vm.prank(daoCreator.addr);
            D4AERC721(nft).safeTransferFrom(daoCreator.addr, nftMinter.addr, 1);
        }

        _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(2)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );
    }

    function test_PreuploadedWorksShouldOccupy1to1000TokenIds() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.uniPriceModeOff = true;
        param.topUpMode = false;
        param.isProgressiveJackpot = false;
        param.needMintableWork = true;
        bytes32 daoId = _createDaoForFunding(param, daoCreator.addr);

        uint256 tokenId = _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(2)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            daoCreator.addr
        );
        assertEq(tokenId, 1);
        {
            address nft = protocol.getDaoNft(daoId);
            vm.prank(daoCreator.addr);
            D4AERC721(nft).safeTransferFrom(daoCreator.addr, nftMinter.addr, 1);
        }

        tokenId = _mintNft(daoId, param.canvasId, "test token uri 1", 0.01 ether, daoCreator.key, nftMinter.addr);
        assertEq(tokenId, 1001);
        tokenId = _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );
        assertEq(tokenId, 2);
        tokenId = _mintNft(daoId, param.canvasId, "test token uri 2", 0.01 ether, daoCreator.key, nftMinter.addr);
        assertEq(tokenId, 1002);
        tokenId = _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(5)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );
        assertEq(tokenId, 3);
        tokenId = _mintNft(
            daoId,
            param.canvasId,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(6)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );
        assertEq(tokenId, 4);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DeployHelper } from "test/foundry/utils/DeployHelper.sol";

import {
    UserMintCapParam,
    SetChildrenParam,
    AllRatioParam,
    CreateCanvasAndMintNFTParam,
    NftIdentifier
} from "contracts/interface/D4AStructs.sol";
import { ClaimMultiRewardParam } from "contracts/D4AUniversalClaimer.sol";

import { ExceedMinterMaxMintAmount, NotAncestorDao } from "contracts/interface/D4AErrors.sol";
import { D4AFeePool } from "contracts/feepool/D4AFeePool.sol";
import { D4AERC721 } from "contracts/D4AERC721.sol";
import { PDCreate } from "contracts/PDCreate.sol";

import { console2 } from "forge-std/Test.sol";

contract ProtoDaoIntergrate14 is DeployHelper {
    error TransferFromFailed();

    function setUp() public {
        super.setUpEnv();
    }

    function test_PDCreateFunding_4_34() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.topUpMode = true;
        param.noPermission = true;
        param.mintableRound = 50;
        param.daoUri = "topup dao uri";

        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );

        NftIdentifier memory nft1 = NftIdentifier(protocol.getDaoNft(daoId), 1);

        //------------------
        param.isBasicDao = false;
        param.existDaoId = daoId;
        param.topUpMode = false;
        param.outputPaymentMode = true;
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        param.daoUri = "normal dao uri";
        param.uniPriceModeOff = true;
        bytes32 canvasId2 = param.canvasId;
        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        vm.roll(3);
        address token = protocol.getDaoToken(daoId2);
        deal(token, nftMinter.addr, 100_000_000 ether);
        {
            (uint256 topUpOutput, uint256 topUpInput) = protocol.updateTopUpAccount(daoId2, nft1);
            assertEq(topUpOutput, 1_000_000 ether);
            assertEq(topUpInput, 0.01 ether);
        }

        bytes32 digest = mintNftSigUtils.getTypedDataHash(canvasId2, "a1234", 2_000_000 ether);
        bytes memory sig;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(daoCreator2.key, digest);
            sig = abi.encodePacked(r, s, v);
        }

        vm.expectRevert(TransferFromFailed.selector);
        vm.prank(nftMinter.addr);
        CreateCanvasAndMintNFTParam memory mintNftTransferParam;
        mintNftTransferParam.daoId = daoId2;
        mintNftTransferParam.canvasId = canvasId2;
        mintNftTransferParam.tokenUri = "a1234";
        mintNftTransferParam.proof = new bytes32[](0);
        mintNftTransferParam.flatPrice = 2_000_000 ether;
        mintNftTransferParam.nftSignature = sig;
        mintNftTransferParam.nftOwner = nftMinter.addr;
        mintNftTransferParam.erc20Signature = "";
        mintNftTransferParam.deadline = 0;
        mintNftTransferParam.nftIdentifier = nft1;

        protocol.mintNFT{ value: 0 }(mintNftTransferParam);
        //uint256 tokenId = protocol.mintNFT(daoId2, canvasId2, "a1234", new bytes32[](0), 2_000_000 ether, sig, "", 0);
        vm.startPrank(nftMinter.addr);

        IERC20(token).approve(address(protocol), 1_000_000 ether);
        protocol.mintNFT(mintNftTransferParam);

        {
            (uint256 topUpOutput, uint256 topUpInput) = protocol.updateTopUpAccount(daoId2, nft1);
            assertEq(topUpOutput, 0);
            assertEq(topUpInput, 0);
        }
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 100_000_000 ether - 1_000_000 ether);
    }

    function test_PDCreateFunding_4_20() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.noPermission = true;
        param.daoUri = "test 1.4-20 dao uri";
        param.isProgressiveJackpot = true;
        param.infiniteMode = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);
        address token = protocol.getDaoToken(daoId);
        assertGe(protocol.getDaoAssetPool(daoId).balance, 0);
        assertGe(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId)), 0);

        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp + 1));
        param.existDaoId = daoId;
        param.isBasicDao = false;
        param.daoUri = "sub dao uri";
        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        SetChildrenParam memory vars;
        vars.childrenDaoId = new bytes32[](1);
        vars.childrenDaoId[0] = daoId2;
        vars.childrenDaoOutputRatios = new uint256[](1);
        vars.childrenDaoOutputRatios[0] = 3000;
        vars.childrenDaoInputRatios = new uint256[](1);
        vars.childrenDaoInputRatios[0] = 3000;
        vars.selfRewardOutputRatio = 5000;
        vars.selfRewardInputRatio = 5000;
        vars.redeemPoolInputRatio = 1000;

        vm.prank(daoCreator.addr);
        protocol.setChildren(daoId, vars);

        deal(protocol.getDaoAssetPool(daoId), 10 ether);

        vm.roll(3);
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );

        assertEq(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId2)), 50_000_000 ether * 0.3);
        assertEq(protocol.getDaoAssetPool(daoId2).balance, 3 ether);

        assertEq(protocol.getRoundOutputReward(daoId, 3), 5_000_000 ether * 5);
        assertEq(protocol.getRoundInputReward(daoId, 3), 5 ether);
        assertEq(protocol.getDaoFeePool(daoId).balance, 1 ether + 0.006 ether);
        assertEq(protocol.getDaoAssetPool(daoId).balance, 1 ether + 0.0035 ether);
        assertEq(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId)), 5_000_000 ether * 2);

        vm.roll(6);
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );
        assertEq(
            IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId2)),
            50_000_000 ether * 0.3 + 5_000_000 ether * 2 * 0.3
        );
        assertEq(protocol.getDaoAssetPool(daoId2).balance, 3 ether + (1 ether + 0.0035 ether) * 0.3);
        assertEq(protocol.getRoundOutputReward(daoId, 6), 5_000_000 ether * 2 * 0.5);
        assertEq(protocol.getRoundInputReward(daoId, 6), (1 ether + 0.0035 ether) * 0.5);
        assertEq(
            protocol.getDaoFeePool(daoId).balance,
            (1 ether + 0.006 ether) + ((1 ether + 0.0035 ether) * 0.1 + 0.01 ether * 0.6)
        );
        assertEq(protocol.getDaoAssetPool(daoId).balance, (1 ether + 0.0035 ether) * 0.1 + 0.01 ether * 0.35);
        assertEq(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId)), 5_000_000 ether * 2 * 0.2);
    }

    function test_PDCreateFunding_4_21() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.noPermission = true;
        param.daoUri = "test 1.4-21 dao uri";
        param.isProgressiveJackpot = false;
        param.infiniteMode = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);
        address token = protocol.getDaoToken(daoId);

        // assertGe(protocol.getDaoAssetPool(daoId).balance, 1);
        // assertGe(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId)) , 1);

        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp + 1));
        bytes32 canvasId2 = param.canvasId;
        param.existDaoId = daoId;
        param.isBasicDao = false;
        param.daoUri = "sub dao uri";
        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        uint256 outputBalance = IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId2));
        uint256 inputBalance = protocol.getDaoAssetPool(daoId2).balance;
        assertEq(outputBalance, 0);
        assertEq(inputBalance, 0);
        deal(protocol.getDaoAssetPool(daoId2), 1 ether);

        _grantPool(daoId2, daoCreator.addr, 1_000_000 ether);

        super._mintNft(daoId2, canvasId2, "a1234", 0.01 ether, daoCreator2.key, nftMinter.addr);

        assertEq(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId2)), 1_000_000 ether);
        assertEq(protocol.getDaoAssetPool(daoId2).balance, 1 ether + 0.0035 ether);
    }

    function test_PDCreateFunding_4_22() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.noPermission = true;
        param.daoUri = "test 1.4-22 dao uri";
        param.isProgressiveJackpot = false;
        param.infiniteMode = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);
        address token = protocol.getDaoToken(daoId);

        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp + 1));
        param.existDaoId = daoId;
        param.isBasicDao = false;
        param.daoUri = "sub dao uri";
        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator2.addr);
        SetChildrenParam memory vars;
        vars.childrenDaoId = new bytes32[](1);
        vars.childrenDaoId[0] = daoId2;

        vars.childrenDaoOutputRatios = new uint256[](1);
        vars.childrenDaoOutputRatios[0] = 3000;
        vars.childrenDaoInputRatios = new uint256[](1);
        vars.childrenDaoInputRatios[0] = 3000;

        vars.selfRewardOutputRatio = 5000;
        vars.selfRewardInputRatio = 5000;
        vars.redeemPoolInputRatio = 1000;

        vm.prank(daoCreator.addr);
        protocol.setChildren(daoId, vars);
        deal(protocol.getDaoAssetPool(daoId), 10 ether);

        assertGe(protocol.getDaoAssetPool(daoId).balance, 1);
        assertGe(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId)), 1);

        uint256 mainOutputBalance = IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId));
        uint256 mainInputBalance = protocol.getDaoAssetPool(daoId).balance;

        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );

        assertEq(
            IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId2)),
            mainOutputBalance * vars.childrenDaoOutputRatios[0] / 10_000
        );
        assertEq(protocol.getDaoAssetPool(daoId2).balance, mainInputBalance * vars.childrenDaoInputRatios[0] / 10_000);

        assertEq(protocol.getRoundOutputReward(daoId, 1), mainOutputBalance * vars.selfRewardOutputRatio / 10_000);
        assertEq(protocol.getRoundInputReward(daoId, 1), mainInputBalance * vars.selfRewardInputRatio / 10_000);
        //redeemPoolMintFeeRatioFiatPrice = 60% in DeployHelper.sol --> 0.01 ether * 0.6
        assertEq(
            protocol.getDaoFeePool(daoId).balance,
            mainInputBalance * vars.redeemPoolInputRatio / 10_000 + 0.01 ether * 0.6
        );

        assertEq(
            protocol.getDaoAssetPool(daoId).balance,
            mainInputBalance
                * (10_000 - vars.childrenDaoInputRatios[0] - vars.selfRewardInputRatio - vars.redeemPoolInputRatio) / 10_000
                + 0.01 ether * 0.35
        );
        assertEq(
            IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId)),
            mainOutputBalance * (10_000 - vars.childrenDaoOutputRatios[0] - vars.selfRewardOutputRatio) / 10_000
        );
    }

    function test_PDCreateFunding_4_17() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.noPermission = true;
        param.daoUri = "test 1.4-17 dao_1 uri";
        param.isProgressiveJackpot = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);
        address token = protocol.getDaoToken(daoId);
        vm.roll(protocol.getDaoRemainingRound(daoId) + 2);
        assertEq(protocol.getDaoRemainingRound(daoId), 0);

        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp + 1));
        param.existDaoId = daoId;
        param.isBasicDao = false;
        param.daoUri = "sub dao uri";
        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        SetChildrenParam memory vars;
        vars.childrenDaoId = new bytes32[](1);
        vars.childrenDaoId[0] = daoId2;
        vars.childrenDaoOutputRatios = new uint256[](1);
        vars.childrenDaoOutputRatios[0] = 10_000;
        vars.childrenDaoInputRatios = new uint256[](1);
        vars.childrenDaoInputRatios[0] = 10_000;

        vm.prank(daoCreator.addr);
        protocol.setChildren(daoId, vars);
        deal(protocol.getDaoAssetPool(daoId), 10 ether);

        uint256 mainDaoERC20Balance = IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId));
        uint256 mainDaoETHBalance = protocol.getDaoAssetPool(daoId).balance;

        uint256 cycleRound = 50;
        vm.prank(daoCreator.addr);
        protocol.setDaoRemainingRound(daoId, cycleRound);

        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );
        assertEq(protocol.getDaoAssetPool(daoId2).balance, mainDaoETHBalance / 50);
        assertEq(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId2)), mainDaoERC20Balance / 50);

        vm.roll(block.number + 49);
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
            ),
            0.01 ether,
            daoCreator.key,
            nftMinter.addr
        );
        assertEq(protocol.getDaoAssetPool(daoId2).balance, mainDaoETHBalance + 0.01 ether * 0.35);
        assertEq(IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId2)), mainDaoERC20Balance);
    }

    function test_PDCreateFunding_ZeroUnifiedPrice() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.noPermission = true;
        param.uniPriceModeOff = false;

        param.mintableRound = 10;
        param.selfRewardOutputRatio = 7000;
        param.selfRewardInputRatio = 7000;
        param.daoUri = "test 1.4-xx dao uri";
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);
        address token = protocol.getDaoToken(daoId);

        vm.prank(daoCreator.addr);
        protocol.setDaoUnifiedPrice(daoId, 0 ether);

        deal(protocol.getDaoAssetPool(daoId), 10 ether);
        uint256 ether_dao_asset_balance = protocol.getDaoAssetPool(daoId).balance;
        uint256 token_dao_asset_balance = IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId));

        for (uint256 i = 0; i < 3; i++) {
            super._mintNft(
                daoId,
                canvasId1,
                string.concat(
                    tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(i)), ".json"
                ),
                0 ether,
                daoCreator.key,
                nftMinter.addr
            );
        }
        for (uint256 i = 3; i < 5; i++) {
            super._mintNft(
                daoId,
                canvasId1,
                string.concat(
                    tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(i)), ".json"
                ),
                0 ether,
                daoCreator.key,
                nftMinter2.addr
            );
        }

        vm.roll(2);
        uint256 remainingRound = protocol.getDaoRemainingRound(daoId) + 1;
        uint256 token_balance_before = IERC20(token).balanceOf(nftMinter.addr);
        uint256 eth_balance_before = nftMinter.addr.balance;
        protocol.claimNftMinterReward(daoId, nftMinter.addr);
        assertEq(
            IERC20(token).balanceOf(nftMinter.addr) - token_balance_before,
            token_dao_asset_balance * param.selfRewardOutputRatio / 10_000 / remainingRound / 5 * 800 / 10_000 * 3,
            "ERC20 balance nftMinter error in Round1"
        );
        assertEq(
            nftMinter.addr.balance - eth_balance_before,
            ether_dao_asset_balance * param.selfRewardInputRatio / 10_000 / remainingRound / 5 * 800 / 10_000 * 3,
            "ETH balance nftMinter error in Round1"
        );

        token_balance_before = IERC20(token).balanceOf(nftMinter2.addr);
        eth_balance_before = nftMinter2.addr.balance;
        protocol.claimNftMinterReward(daoId, nftMinter2.addr);
        assertEq(
            IERC20(token).balanceOf(nftMinter2.addr) - token_balance_before,
            token_dao_asset_balance * param.selfRewardOutputRatio / 10_000 / remainingRound / 5 * 800 / 10_000 * 2,
            "ERC20 balance nftMinter2 error in Round1"
        );
        assertEq(
            nftMinter2.addr.balance - eth_balance_before,
            ether_dao_asset_balance * param.selfRewardInputRatio / 10_000 / remainingRound / 5 * 800 / 10_000 * 2,
            "ETH balance nftMinter2 Error in Round1"
        );

        token_balance_before = IERC20(token).balanceOf(daoCreator.addr);
        eth_balance_before = daoCreator.addr.balance;
        protocol.claimDaoNftOwnerReward(daoId);
        assertEq(
            IERC20(token).balanceOf(daoCreator.addr) - token_balance_before,
            token_dao_asset_balance * param.selfRewardOutputRatio / 10_000 / remainingRound / 5 * 7000 / 10_000 * 5,
            "ERC20 balance daoCreator error in Round1"
        );
        assertEq(
            daoCreator.addr.balance - eth_balance_before,
            ether_dao_asset_balance * param.selfRewardInputRatio / 10_000 / remainingRound / 5 * 7000 / 10_000 * 5,
            "ETH balance daocreator Error in Round1"
        );

        token_balance_before = IERC20(token).balanceOf(daoCreator.addr);
        eth_balance_before = daoCreator.addr.balance;
        protocol.claimCanvasReward(canvasId1);
        assertEq(
            IERC20(token).balanceOf(daoCreator.addr) - token_balance_before,
            token_dao_asset_balance * param.selfRewardOutputRatio / 10_000 / remainingRound / 5 * 2000 / 10_000 * 5,
            "ERC20 Canvas Creator Error in Round1"
        );
        assertEq(
            daoCreator.addr.balance - eth_balance_before,
            ether_dao_asset_balance * param.selfRewardInputRatio / 10_000 / remainingRound / 5 * 2000 / 10_000 * 5,
            "ETH Canvas Creator Error in Round1"
        );

        //Start Second Active Round
        ether_dao_asset_balance = protocol.getDaoAssetPool(daoId).balance;
        token_dao_asset_balance = IERC20(token).balanceOf(protocol.getDaoAssetPool(daoId));

        for (uint256 i = 5; i < 7; i++) {
            super._mintNft(
                daoId,
                canvasId1,
                string.concat(
                    tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(i)), ".json"
                ),
                0 ether,
                daoCreator.key,
                nftMinter.addr
            );
        }
        for (uint256 i = 7; i < 10; i++) {
            super._mintNft(
                daoId,
                canvasId1,
                string.concat(
                    tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(i)), ".json"
                ),
                0 ether,
                daoCreator.key,
                nftMinter2.addr
            );
        }

        vm.roll(3);
        remainingRound = protocol.getDaoRemainingRound(daoId) + 1;

        token_balance_before = IERC20(token).balanceOf(nftMinter.addr);
        eth_balance_before = nftMinter.addr.balance;
        protocol.claimNftMinterReward(daoId, nftMinter.addr);
        assertEq(
            (IERC20(token).balanceOf(nftMinter.addr) - token_balance_before) / 10,
            (token_dao_asset_balance * param.selfRewardOutputRatio / 10_000 / remainingRound / 5 * 800 / 10_000 * 2)
                / 10,
            "ERC20 balance nftMinter error in Round2"
        );
        assertEq(
            (nftMinter.addr.balance - eth_balance_before) / 10,
            (ether_dao_asset_balance * param.selfRewardInputRatio / 10_000 / remainingRound / 5 * 800 / 10_000 * 2) / 10,
            "ETH balance nftMinter error in Round2"
        );

        token_balance_before = IERC20(token).balanceOf(nftMinter2.addr);
        eth_balance_before = nftMinter2.addr.balance;
        protocol.claimNftMinterReward(daoId, nftMinter2.addr);
        assertEq(
            (IERC20(token).balanceOf(nftMinter2.addr) - token_balance_before) / 10,
            (token_dao_asset_balance * param.selfRewardOutputRatio / 10_000 / remainingRound / 5 * 800 / 10_000 * 3)
                / 10,
            "ERC20 balance nftMinter2 error in Round2"
        );
        assertEq(
            (nftMinter2.addr.balance - eth_balance_before) / 10,
            (ether_dao_asset_balance * param.selfRewardInputRatio / 10_000 / remainingRound / 5 * 800 / 10_000 * 3) / 10,
            "ETH balance nftMinter2 Error in Round2"
        );

        token_balance_before = IERC20(token).balanceOf(daoCreator.addr);
        eth_balance_before = daoCreator.addr.balance;
        protocol.claimDaoNftOwnerReward(daoId);
        assertEq(
            (IERC20(token).balanceOf(daoCreator.addr) - token_balance_before) / 10,
            (token_dao_asset_balance * param.selfRewardOutputRatio / 10_000 / remainingRound / 5 * 7000 / 10_000 * 5)
                / 10,
            "ERC20 balance daoCreator error in Round2"
        );
        assertEq(
            (daoCreator.addr.balance - eth_balance_before) / 10,
            (ether_dao_asset_balance * param.selfRewardInputRatio / 10_000 / remainingRound / 5 * 7000 / 10_000 * 5)
                / 10,
            "ETH balance daocreator Error in Round2"
        );

        token_balance_before = IERC20(token).balanceOf(daoCreator.addr);
        eth_balance_before = daoCreator.addr.balance;
        protocol.claimCanvasReward(canvasId1);
        assertEq(
            (IERC20(token).balanceOf(daoCreator.addr) - token_balance_before) / 10,
            (token_dao_asset_balance * param.selfRewardOutputRatio / 10_000 / remainingRound / 5 * 2000 / 10_000 * 5)
                / 10,
            "ERC20 balance canvas creator Error in Round2"
        );
        assertEq(
            (daoCreator.addr.balance - eth_balance_before) / 10,
            (ether_dao_asset_balance * param.selfRewardInputRatio / 10_000 / remainingRound / 5 * 2000 / 10_000 * 5)
                / 10,
            "ETH balance  canvas creator Error in Round2"
        );

        //q1. redeem pool ProtocolFeePool balance ?
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DeployHelper } from "test/foundry/utils/DeployHelper.sol";

import { UserMintCapParam, CreateCanvasAndMintNFTParam } from "contracts/interface/D4AStructs.sol";
import { ClaimMultiRewardParam } from "contracts/D4AUniversalClaimer.sol";

import { ExceedMinterMaxMintAmount, NotAncestorDao } from "contracts/interface/D4AErrors.sol";
import { D4AFeePool } from "contracts/feepool/D4AFeePool.sol";
import { D4AERC721 } from "contracts/D4AERC721.sol";
import { PDCreate } from "contracts/PDCreate.sol";

import { console2 } from "forge-std/Test.sol";

contract ProtoDaoExtendTest is DeployHelper {
    function setUp() public {
        super.setUpEnv();
    }

    function test_PDCreateFunding_createContinuousDAO_erc20_two_mint_with_same_price() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        param.daoUri = "continuous dao uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));

        param.isBasicDao = false;
        param.existDaoId = daoId;

        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator2.addr);

        param.daoUri = "continuous dao uri2";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;

        param.isBasicDao = false;
        param.existDaoId = daoId;
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = subDaoId;
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 4000;
        param.childrenDaoOutputRatios[1] = 3000;
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 1000;
        param.childrenDaoInputRatios[1] = 2000;
        param.redeemPoolInputRatio = 3000;
        param.selfRewardOutputRatio = 2000;
        param.selfRewardInputRatio = 3500;

        param.noPermission = true;
        param.mintableRound = 10;

        bytes32 subDaoId2 = super._createDaoForFunding(param, daoCreator3.addr);
        _grantPool(subDaoId2, daoCreator.addr, 10_000_000 ether);

        uint256 flatPrice = 0.01 ether;
        super._mintNft(
            subDaoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId2)), "-", vm.toString(uint256(0)), ".json"
            ),
            flatPrice,
            daoCreator3.key,
            nftMinter.addr
        );
        super._mintNft(
            subDaoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId2)), "-", vm.toString(uint256(1)), ".json"
            ),
            flatPrice,
            daoCreator3.key,
            nftMinter2.addr
        );

        //10_000_000 ether - 900_000 ether;
        address assetPool3 = protocol.getDaoAssetPool(subDaoId2);
        address assetPool1 = protocol.getDaoAssetPool(daoId);
        address assetPool2 = protocol.getDaoAssetPool(subDaoId);

        address token = protocol.getDaoToken(subDaoId2);
        assertEq(token, protocol.getDaoToken(daoId));
        assertEq(IERC20(token).balanceOf(assetPool3), 10_000_000 ether - 900_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool1), 50_000_000 ether + 400_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool2), 300_000 ether);
        assertEq(IERC20(token).balanceOf(address(protocol)), 200_000 ether);

        vm.roll(2);

        protocol.claimDaoNftOwnerReward(subDaoId2);
        //1000000 * 20% * 70%
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 140_000 ether);

        //add 1000000 * 20% * 20%
        protocol.claimCanvasReward(canvasId3);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 180_000 ether);

        //1000000 * 20% * 8% * (0.01) / (0.01 + 0.01)
        protocol.claimNftMinterReward(subDaoId2, nftMinter.addr);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 8000 ether);

        // 1000000 * 20% * 8% * (0.01) / (0.01 + 0.01)
        protocol.claimNftMinterReward(subDaoId2, nftMinter2.addr);
        assertEq(IERC20(token).balanceOf(nftMinter2.addr), 8000 ether);

        assertEq(IERC20(token).balanceOf(protocol.protocolFeePool()), 4000 ether);
        assertEq(IERC20(token).balanceOf(address(protocol)), 0);
    }

    function test_PDCreateFunding_createContinuousDAO_erc20_two_mint_with_diff_price() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        param.daoUri = "continuous dao uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));

        param.isBasicDao = false;
        param.existDaoId = daoId;

        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator2.addr);

        param.daoUri = "continuous dao uri2";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;

        param.isBasicDao = false;
        param.existDaoId = daoId;
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = subDaoId;
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 4000;
        param.childrenDaoOutputRatios[1] = 3000;
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 1000;
        param.childrenDaoInputRatios[1] = 2000;
        param.redeemPoolInputRatio = 3000;
        param.selfRewardOutputRatio = 2000;
        param.selfRewardInputRatio = 3500;

        param.noPermission = true;
        param.mintableRound = 10;

        bytes32 subDaoId2 = super._createDaoForFunding(param, daoCreator3.addr);
        _grantPool(subDaoId2, daoCreator.addr, 10_000_000 ether);
        uint256 flatPrice = 0.01 ether;
        super._mintNft(
            subDaoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId2)), "-", vm.toString(uint256(0)), ".json"
            ),
            flatPrice,
            daoCreator3.key,
            nftMinter.addr
        );
        hoax(daoCreator3.addr);
        protocol.setDaoUnifiedPrice(subDaoId2, 0.04 ether);
        super._mintNft(
            subDaoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId2)), "-", vm.toString(uint256(1)), ".json"
            ),
            0.04 ether,
            daoCreator3.key,
            nftMinter2.addr
        );

        //10_000_000 ether - 900_000 ether;
        address assetPool3 = protocol.getDaoAssetPool(subDaoId2);
        address assetPool1 = protocol.getDaoAssetPool(daoId);
        address assetPool2 = protocol.getDaoAssetPool(subDaoId);

        address token = protocol.getDaoToken(subDaoId2);
        assertEq(token, protocol.getDaoToken(daoId));
        assertEq(IERC20(token).balanceOf(assetPool3), 10_000_000 ether - 900_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool1), 50_000_000 ether + 400_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool2), 300_000 ether);
        assertEq(IERC20(token).balanceOf(address(protocol)), 200_000 ether);

        vm.roll(2);

        //1000000 * 20% * 70%
        protocol.claimDaoNftOwnerReward(subDaoId2);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 140_000 ether);

        //add 1000000 * 20% * 20%
        protocol.claimCanvasReward(canvasId3);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 180_000 ether);

        //1000000 * 20% * 8% * (0.01) / (0.01 + 0.04)
        protocol.claimNftMinterReward(subDaoId2, nftMinter.addr);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 3200 ether);

        // 1000000 * 20% * 8% * (0.04) / (0.01 + 0.04)
        protocol.claimNftMinterReward(subDaoId2, nftMinter2.addr);
        assertEq(IERC20(token).balanceOf(nftMinter2.addr), 12_800 ether);

        assertEq(IERC20(token).balanceOf(protocol.protocolFeePool()), 4000 ether);
        assertEq(IERC20(token).balanceOf(address(protocol)), 0);
    }

    function test_PDCreateFunding_createContinuousDAO_erc20_three_mint_with_diff_price() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        param.daoUri = "continuous dao uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));

        param.isBasicDao = false;
        param.existDaoId = daoId;

        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator2.addr);

        param.daoUri = "continuous dao uri2";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;

        param.isBasicDao = false;
        param.existDaoId = daoId;
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = subDaoId;
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 4000;
        param.childrenDaoOutputRatios[1] = 3000;
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 1000;
        param.childrenDaoInputRatios[1] = 2000;
        param.redeemPoolInputRatio = 3000;
        param.selfRewardOutputRatio = 2000;
        param.selfRewardInputRatio = 3500;

        param.noPermission = true;
        param.mintableRound = 10;

        bytes32 subDaoId2 = super._createDaoForFunding(param, daoCreator3.addr);
        _grantPool(subDaoId2, daoCreator.addr, 10_000_000 ether);
        uint256 flatPrice = 0.01 ether;
        super._mintNft(
            subDaoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId2)), "-", vm.toString(uint256(0)), ".json"
            ),
            flatPrice,
            daoCreator3.key,
            nftMinter.addr
        );
        hoax(daoCreator3.addr);
        protocol.setDaoUnifiedPrice(subDaoId2, 0.04 ether);
        super._mintNft(
            subDaoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId2)), "-", vm.toString(uint256(1)), ".json"
            ),
            0.04 ether,
            daoCreator3.key,
            nftMinter2.addr
        );
        hoax(daoCreator3.addr);
        protocol.setDaoUnifiedPrice(subDaoId2, 0.05 ether);
        super._mintNft(
            subDaoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId2)), "-", vm.toString(uint256(2)), ".json"
            ),
            0.05 ether,
            daoCreator3.key,
            randomGuy.addr
        );

        //10_000_000 ether - 900_000 ether;
        address assetPool3 = protocol.getDaoAssetPool(subDaoId2);
        address assetPool1 = protocol.getDaoAssetPool(daoId);
        address assetPool2 = protocol.getDaoAssetPool(subDaoId);

        address token = protocol.getDaoToken(subDaoId2);
        assertEq(token, protocol.getDaoToken(daoId));
        assertEq(IERC20(token).balanceOf(assetPool3), 10_000_000 ether - 900_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool1), 50_000_000 ether + 400_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool2), 300_000 ether);
        assertEq(IERC20(token).balanceOf(address(protocol)), 200_000 ether);

        vm.roll(2);

        //1000000 * 20% * 70%
        protocol.claimDaoNftOwnerReward(subDaoId2);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 140_000 ether);

        //add 1000000 * 20% * 20%
        protocol.claimCanvasReward(canvasId3);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 180_000 ether);

        //1000000 * 20% * 8% * (0.01) / (0.01 + 0.04 + 0.05)
        protocol.claimNftMinterReward(subDaoId2, nftMinter.addr);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 1600 ether);

        // 1000000 * 20% * 8% * (0.04) / (0.01 + 0.04 + 0.05)
        protocol.claimNftMinterReward(subDaoId2, nftMinter2.addr);
        assertEq(IERC20(token).balanceOf(nftMinter2.addr), 6400 ether);

        // 1000000 * 20% * 8% * (0.05) / (0.01 + 0.04 + 0.05)
        protocol.claimNftMinterReward(subDaoId2, randomGuy.addr);
        assertEq(IERC20(token).balanceOf(randomGuy.addr), 8000 ether);

        assertEq(IERC20(token).balanceOf(protocol.protocolFeePool()), 4000 ether);
        assertEq(IERC20(token).balanceOf(address(protocol)), 0);
    }

    function test_PDCreateFunding_createContinuousDAO_eth_with_one_mint() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.isBasicDao = true;
        param.existDaoId = bytes32(0);
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        param.daoUri = "continuous dao uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        param.isBasicDao = false;
        param.existDaoId = daoId;
        bytes32 daoId1 = super._createDaoForFunding(param, daoCreator2.addr);

        param.daoUri = "continuous dao uri2";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = daoId1;
        param.childrenDaoOutputRatios = new uint256[](2);
        // output ratio
        param.childrenDaoOutputRatios[0] = 4000;
        param.childrenDaoOutputRatios[1] = 3000;
        param.selfRewardOutputRatio = 2000;
        param.childrenDaoInputRatios = new uint256[](2);
        // input ratio
        param.childrenDaoInputRatios[0] = 1000;
        param.childrenDaoInputRatios[1] = 2000;
        param.redeemPoolInputRatio = 3000;
        param.selfRewardInputRatio = 3500;
        param.noPermission = true;
        param.mintableRound = 10;
        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator3.addr);

        address assetPool1 = protocol.getDaoAssetPool(daoId);
        address assetPool2 = protocol.getDaoAssetPool(daoId1);
        address assetPool3 = protocol.getDaoAssetPool(daoId2);

        _grantPool(daoId2, daoCreator.addr, 10_000_000 ether);

        uint256 daoCreator3_eth_balance_before = daoCreator3.addr.balance;
        uint256 flatPrice = 0.01 ether;
        super._mintNft(
            daoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId2)), "-", vm.toString(uint256(0)), ".json"
            ),
            flatPrice,
            daoCreator3.key,
            nftMinter.addr
        );
        uint256 daoCreator3_eth_balance_after = daoCreator3.addr.balance;

        address token = protocol.getDaoToken(daoId2);
        // show_address_erc20_balance(token, assetPool1, assetPool2, assetPool3);

        assertEq(token, protocol.getDaoToken(daoId));
        // 10_000_000 ether is grant InitialTokenSupplyForSubDao
        // 900_000 ether = 10_000_000 ether * (1 DRB/10 DRB) * (param.childrenDaoOutputRatios[0] +
        // param.childrenDaoOutputRatios[1] + param.selfRewardOutputRatio) / BASIS_POINT
        // 900_000 ether = 10_000_000 ether * (1 DRB/10 DRB) * (4000 + 3000 + 2000) / 10000
        assertEq(IERC20(token).balanceOf(assetPool3), 10_000_000 ether - 900_000 ether);
        // 50_000_000 ether = 1G ether * BasicDaoParam.initTokenSupplyRatio / BASIS_POINT
        // 50_000_000 ether = 1G ether * 500 / 10000
        // 400_000 ether = 10_000_000 ether * (1 DRB/10 DRB) * 4000 / 10000
        assertEq(IERC20(token).balanceOf(assetPool1), 50_000_000 ether + 400_000 ether);
        // 300_000 ether = 10_000_000 ether * (1 DRB/10 DRB) * 3000 / 10000
        assertEq(IERC20(token).balanceOf(assetPool2), 300_000 ether);
        // 200_000 ether = 10_000_000 ether * (1 DRB/10 DRB) * 2000 / 10000
        assertEq(IERC20(token).balanceOf(address(protocol)), 200_000 ether);

        vm.roll(2);

        // 10_000_000 ether * (1 DRB/10 DRB) * (param.selfRewardOutputRatio / BASIS_POINT) *
        // (AllRatioForFundingParam.daoCreatorOutputRewardRatio / BASIS_POINT)
        // 140_000 ether = 10_000_000 ether * (1 DRB/10 DRB) * 0.2 * 0.7
        protocol.claimDaoNftOwnerReward(daoId2);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 140_000 ether);

        // canvasId3 is daoCreator3
        // add AllRatioForFundingParam.canvasCreatorOutputRewardRatio
        // 10_000_000 ether * (1 DRB/10 DRB) * (0.2 * 0.7 + 0.2 * 0.2)
        protocol.claimCanvasReward(canvasId3);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 180_000 ether);

        // 10_000_000 ether * (1 DRB/10 DRB) * (0.2 * 0.08)
        protocol.claimNftMinterReward(daoId2, nftMinter.addr);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 16_000 ether);

        // 1000000 * 0.2 - 180_000 ether - 16_000 ether
        assertEq(IERC20(token).balanceOf(protocol.protocolFeePool()), 4000 ether);
        assertEq(IERC20(token).balanceOf(address(protocol)), 0);

        vm.roll(3);

        // 0.01 ether * AllRatioForFundingParam.assetPoolMintFeeRatioFiatPrice
        // 0.01 ether * 0.35
        uint256 assetPool3_eth_balance = assetPool3.balance;
        assertEq(assetPool3_eth_balance, 0.35 * 0.01 ether);

        // canvas creator is daoCreator3
        // 0.01 ether * AllRatioForFundingParam.canvasCreatorMintFeeRatioFiatPrice
        // 0.01 ether * 0.025
        assertEq(daoCreator3_eth_balance_after - daoCreator3_eth_balance_before, 0.025 * 0.01 ether);

        // 0.01 ether * AllRatioForFundingParam.redeemPoolMintFeeRatioFiatPrice
        address redeemPool = protocol.getDaoFeePool(daoId2);
        uint256 redeemPool_eth_balance = redeemPool.balance;
        assertEq(redeemPool_eth_balance, 0.6 * 0.01 ether);
    }

    function test_PDCreateFunding_createContinuousDAO_eth_with_transfer() public {
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.isBasicDao = true;
        param.existDaoId = bytes32(0);
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        param.daoUri = "continuous dao uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        param.isBasicDao = false;
        param.existDaoId = daoId;
        bytes32 daoId1 = super._createDaoForFunding(param, daoCreator2.addr);

        param.daoUri = "continuous dao uri2";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = daoId1;
        // output ratio
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 4000;
        param.childrenDaoOutputRatios[1] = 3000;
        param.selfRewardOutputRatio = 2000;
        // input ratio
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 1000;
        param.childrenDaoInputRatios[1] = 2000;
        param.redeemPoolInputRatio = 3000;
        param.selfRewardInputRatio = 3500;
        param.noPermission = true;
        param.mintableRound = 10;
        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator3.addr);

        address assetPool1 = protocol.getDaoAssetPool(daoId);
        address assetPool2 = protocol.getDaoAssetPool(daoId1);
        address assetPool3 = protocol.getDaoAssetPool(daoId2);

        assertEq(assetPool3.balance, 0 ether);
        deal(assetPool3, 1 ether);

        _grantPool(daoId2, daoCreator.addr, 10_000_000 ether);

        assertEq(assetPool1.balance, 0 ether);
        assertEq(assetPool2.balance, 0 ether);
        assertEq(assetPool3.balance, 1 ether);
        address redeemPool = protocol.getDaoFeePool(daoId2);
        assertEq(redeemPool.balance, 0 ether);
        assertEq(address(protocol).balance, 0 ether);

        uint256 flatPrice = 0.01 ether;
        super._mintNft(
            daoId2,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId2)), "-", vm.toString(uint256(0)), ".json"
            ),
            flatPrice,
            daoCreator3.key,
            nftMinter.addr
        );

        // 1 ether * (1 DRB/10 DRB) * (childrenDaoInputRatios / BASIS_POINT)
        // 1 ether * (1 DRB/10 DRB) * (1000 / 10000)
        assertEq(assetPool1.balance, 0.01 ether);
        // 1 ether * (1 DRB/10 DRB) * (2000 / 10000)
        assertEq(assetPool2.balance, 0.02 ether);
        // 1 ether - 1 ether * (1 DRB/10 DRB) * (1000 + 2000 + 3000 + 3500) / 10000
        // add mint fee: 0.01 ether * 0.35
        assertEq(assetPool3.balance, 0.9085 ether);
        // 1 ether * (1 DRB/10 DRB) * (3000 / 10000)
        // add mint fee: 0.01 ether * 0.6
        assertEq(redeemPool.balance, 0.036 ether);
        // 1 ether * (1 DRB/10 DRB) * (3500 / 10000)
        assertEq(address(protocol).balance, 0.035 ether);

        vm.roll(2);

        // before claim reward
        assertEq(assetPool1.balance, 0.01 ether);
        assertEq(assetPool2.balance, 0.02 ether);
        assertEq(assetPool3.balance, 0.9085 ether);
        assertEq(redeemPool.balance, 0.036 ether);
        assertEq(address(protocol).balance, 0.035 ether);

        // !!! claim reward
        uint256 daoCreator3_eth_balance_before_claim = daoCreator3.addr.balance;
        protocol.claimDaoNftOwnerReward(daoId2);
        uint256 daoCreator3_eth_balance_after_claim = daoCreator3.addr.balance;
        // 0.035 ether * 0.7
        assertEq(daoCreator3_eth_balance_after_claim - daoCreator3_eth_balance_before_claim, 0.0245 ether);

        // canvas is also daoCreator3
        // 0.035 ether * 0.2
        daoCreator3_eth_balance_before_claim = daoCreator3.addr.balance;
        protocol.claimCanvasReward(canvasId3);
        daoCreator3_eth_balance_after_claim = daoCreator3.addr.balance;
        assertEq(daoCreator3_eth_balance_after_claim - daoCreator3_eth_balance_before_claim, 0.007 ether);

        // 0.035 ether * 0.08
        uint256 nftMinter_eth_balance_before_claim = nftMinter.addr.balance;
        protocol.claimNftMinterReward(daoId2, nftMinter.addr);
        uint256 nftMinter_eth_balance_after_claim = nftMinter.addr.balance;
        assertEq(nftMinter_eth_balance_after_claim - nftMinter_eth_balance_before_claim, 0.0028 ether);

        // after claim reward
        assertEq(assetPool1.balance, 0.01 ether);
        assertEq(assetPool2.balance, 0.02 ether);
        assertEq(assetPool3.balance, 0.9085 ether);
        assertEq(redeemPool.balance, 0.036 ether);
        assertEq(address(protocol).balance, 0 ether);
    }

    // testcase 1.3-14
    function test_PDCreateFunding_1_3_14() public {
        // set create data params
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.isProgressiveJackpot = true;
        param.noPermission = true;
        // erc20 and input ratio
        param.selfRewardOutputRatio = 2000;
        param.redeemPoolInputRatio = 3000;
        param.selfRewardInputRatio = 3500;

        // create basic dao
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        // get pool address
        address assetPool = protocol.getDaoAssetPool(daoId);
        address redeemPool = protocol.getDaoFeePool(daoId);
        address protocolPool = protocol.protocolFeePool();

        // pool balance init as zero
        assertEq(assetPool.balance, 0 ether);
        assertEq(redeemPool.balance, 0 ether);
        assertEq(protocolPool.balance, 0 ether);

        // mint nft
        // canvas/minter/dao_creator are the same: daoCreator
        uint256 flatPrice = 0.01 ether;
        uint256 canvasId1_eth_balance_before_mint = daoCreator.addr.balance;
        // !!!! 1.3-14 step 3
        super._mintNftChangeBal(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            flatPrice,
            daoCreator.key,
            daoCreator.addr
        );
        uint256 canvasId1_eth_balance_after_mint = daoCreator.addr.balance;

        // !!!! 1.3-14 step 4
        // 0.01 ether * 0.35
        assertEq(assetPool.balance, 0.0035 ether);
        // 0.01 ether * 0.6
        assertEq(redeemPool.balance, 0.006 ether);
        // -0.01 ether + 0.01 ether * 0.025
        assertEq(canvasId1_eth_balance_before_mint - canvasId1_eth_balance_after_mint, 0.00975 ether);
        // 0.01 ether * (1 - 0.35 - 0.6 - 0.025)
        assertEq(protocolPool.balance, 0.00025 ether);

        bytes32 canvasId2 = keccak256(abi.encode(canvasCreator2.addr, block.timestamp));
        string memory tokenUri = string.concat(
            tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
        );
        {
            bytes32 digest = mintNftSigUtils.getTypedDataHash(canvasId2, tokenUri, flatPrice);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(canvasCreator2.key, digest);
            CreateCanvasAndMintNFTParam memory vars;
            vars.daoId = daoId;
            vars.canvasId = canvasId2;
            vars.canvasUri = "test canvas uri 2";
            vars.canvasCreator = canvasCreator2.addr;
            vars.tokenUri = tokenUri;
            vars.nftSignature = abi.encodePacked(r, s, v);
            vars.flatPrice = 0.01 ether;
            vars.proof = new bytes32[](0);
            vars.canvasProof = new bytes32[](0);
            vars.nftOwner = daoCreator.addr;

            hoax(daoCreator.addr);
            // !!!! 1.3-14 step 5
            protocol.mintNFT{ value: flatPrice }(vars);
        }
        // !!!! 1.3-14 step 6
        assertEq(assetPool.balance, 0.007 ether);
        assertEq(redeemPool.balance, 0.012 ether);
        assertEq(canvasCreator2.addr.balance, 0.00025 ether);
        assertEq(protocolPool.balance, 0.0005 ether);

        vm.roll(2);

        // set claim param
        ClaimMultiRewardParam memory claimParam;
        claimParam.protocol = address(protocol);
        bytes32[] memory cavansIds = new bytes32[](2);
        cavansIds[0] = canvasId1;
        cavansIds[1] = canvasId2;
        bytes32 tempDaoId = daoId;

        bytes32[] memory daoIds = new bytes32[](1);
        daoIds[0] = tempDaoId;
        claimParam.canvasIds = cavansIds;
        claimParam.daoIds = daoIds;

        address token = protocol.getDaoToken(tempDaoId);
        address ppool = protocol.protocolFeePool();

        uint256 daoCreator_eth_balance_before_claim = daoCreator.addr.balance;
        uint256 canvasCreator2_eth_balance_before_claim = canvasCreator2.addr.balance;
        uint256 protocol_eth_balance_before_claim = ppool.balance;
        vm.prank(daoCreator.addr);
        universalClaimer.claimMultiReward(claimParam);
        uint256 daoCreator_eth_balance_after_claim = daoCreator.addr.balance;
        uint256 canvasCreator2_eth_balance_after_claim = canvasCreator2.addr.balance;
        uint256 protocol_eth_balance_after_claim = ppool.balance;

        // console2.log(IERC20(token).balanceOf(daoCreator.addr));
        // console2.log(IERC20(token).balanceOf(canvasCreator2.addr));
        // console2.log(IERC20(token).balanceOf(protocol.protocolFeePool()));

        // !!!! 1.3-14 step 7
        // erc20 token total reward for 1 drb: 50000000 / 60.0
        // daoCreator.addr erc20 reward consists of three part: as daoCreator, canvasCreator, minter
        // daoCreatorOutputRewardRatio: 50000000 / 60.0 * 0.2 * 0.7
        // canvasCreatorOutputRewardRatio: 50000000 / 60.0 * 0.2 * 0.2 * (0.01) / (0.01 + 0.01)
        // minterOutputRewardRatio: 50000000 / 60.0 * 0.2 * 0.08
        // 146666.6666666667 ether
        assertEq(IERC20(token).balanceOf(daoCreator.addr), 146_666_666_666_666_666_666_665 wei);

        // canvasCreatorOutputRewardRatio: 50000000 / 60.0 * 0.2 * 0.2 * (0.01) / (0.01 + 0.01)
        // 16666.666666666668 ether
        assertEq(IERC20(token).balanceOf(canvasCreator2.addr), 16_666_666_666_666_666_666_666 wei);

        // 50000000 / 60.0 * 0.2 * (10000 - 800 - 2000 - 7000) / 10000
        // 3333.3333333333335 ether
        assertEq(IERC20(token).balanceOf(ppool), 3_333_333_333_333_333_333_333 wei);

        // !!!! 1.3-14 step 8
        assertEq(daoCreator_eth_balance_after_claim - daoCreator_eth_balance_before_claim, 0);
        assertEq(canvasCreator2_eth_balance_after_claim - canvasCreator2_eth_balance_before_claim, 0);
        assertEq(protocol_eth_balance_after_claim - protocol_eth_balance_before_claim, 0);
    }

    // testcase 1.3-16
    function test_PDCreateFunding_1_3_16() public {
        // dao: daoCreator
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        // !!!! 1.3-16 step 1
        // subdao: daoCreator2
        param.daoUri = "continuous dao uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        bytes32 canvasId2 = param.canvasId;
        param.existDaoId = daoId;
        param.isProgressiveJackpot = true;
        param.noPermission = true;
        param.isBasicDao = false;

        // erc20 and input ratio
        param.selfRewardOutputRatio = 2000;
        param.redeemPoolInputRatio = 3000;
        param.selfRewardInputRatio = 3500;
        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator2.addr);

        // !!!! 1.3-16 step 2
        vm.roll(2);

        // get pool address
        address assetPool = protocol.getDaoAssetPool(subDaoId);
        address redeemPool = protocol.getDaoFeePool(subDaoId);
        address protocolPool = protocol.protocolFeePool();
        address token = protocol.getDaoToken(subDaoId);

        // pool balance init as zero
        assertEq(assetPool.balance, 0 ether);
        assertEq(redeemPool.balance, 0 ether);
        assertEq(protocolPool.balance, 0 ether);

        // !!!! 1.3-16 step 3
        uint256 flatPrice = 0.01 ether;
        deal(daoCreator2.addr, 1 ether);
        super._mintNftChangeBal(
            subDaoId,
            canvasId2,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            flatPrice,
            daoCreator2.key,
            daoCreator2.addr
        );

        // !!!! 1.3-16 step 4
        // 0.01 ether * 0.35
        assertEq(assetPool.balance, 0.0035 ether);
        // 0.01 ether * 0.6
        assertEq(redeemPool.balance, 0.006 ether);
        // -0.01 ether + 0.01 ether * 0.025
        assertEq(daoCreator2.addr.balance, 0.99025 ether);
        // 0.01 ether * (1 - 0.35 - 0.6 - 0.025)
        assertEq(protocolPool.balance, 0.00025 ether);

        vm.roll(3);

        // set claim param
        ClaimMultiRewardParam memory claimParam;
        claimParam.protocol = address(protocol);
        bytes32[] memory cavansIds = new bytes32[](2);
        cavansIds[0] = canvasId1;
        cavansIds[1] = canvasId2;

        bytes32[] memory daoIds = new bytes32[](2);
        daoIds[0] = daoId;
        daoIds[1] = subDaoId;
        claimParam.canvasIds = cavansIds;
        claimParam.daoIds = daoIds;

        address main_assetPool = protocol.getDaoAssetPool(daoId);

        vm.prank(daoCreator.addr);
        uint256 daoCreator_eth_balance_before_claim = daoCreator.addr.balance;
        universalClaimer.claimMultiReward(claimParam);
        uint256 daoCreator_eth_balance_after_claim = daoCreator.addr.balance;
        vm.prank(daoCreator2.addr);
        uint256 daoCreator2_eth_balance_before_claim = daoCreator2.addr.balance;
        universalClaimer.claimMultiReward(claimParam);
        uint256 daoCreator2_eth_balance_after_claim = daoCreator2.addr.balance;

        // !!!! 1.3-16 step 5
        // erc20
        assertEq(IERC20(token).balanceOf(daoCreator.addr), 0, "daoCreator");
        assertEq(IERC20(token).balanceOf(daoCreator2.addr), 0, "daoCreator2");
        assertEq(IERC20(token).balanceOf(assetPool), 0, "assetPool");
        assertEq(IERC20(token).balanceOf(redeemPool), 0, "redeemPool");
        assertEq(IERC20(token).balanceOf(main_assetPool), 50_000_000 ether, "main_assetPool");
        assertEq(IERC20(token).balanceOf(protocolPool), 0, "protocolPool");

        // eth
        assertEq(daoCreator_eth_balance_after_claim - daoCreator_eth_balance_before_claim, 0, "daoCreator");
        assertEq(daoCreator2_eth_balance_after_claim - daoCreator2_eth_balance_before_claim, 0, "daoCreator2");
    }

    // testcase 1.3-56
    function test_PDCreateFunding_1_3_56() public {
        // main dao
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        // subdao2
        param.daoUri = "continuous subdao2 uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        bytes32 canvasId2 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        bytes32 subDaoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        // subdao
        param.daoUri = "continuous subdao uri";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        // to main dao and subdao2
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = subDaoId2;
        // output ratio
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 4000;
        param.childrenDaoOutputRatios[1] = 3000;
        param.selfRewardOutputRatio = 2000;
        // input ratio
        param.redeemPoolInputRatio = 2000;
        param.selfRewardInputRatio = 5000;
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 2000;
        param.childrenDaoInputRatios[1] = 1000;
        param.isProgressiveJackpot = true;
        param.noPermission = true;
        param.uniPriceModeOff = true;
        param.mintableRound = 10;
        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator3.addr);

        address token = protocol.getDaoToken(subDaoId);
        address assetPool_subdao = protocol.getDaoAssetPool(subDaoId);
        address redeemPool = protocol.getDaoFeePool(subDaoId);
        address protocolPool = protocol.protocolFeePool();
        address assetPool_maindao = protocol.getDaoAssetPool(daoId);
        address assetPool_subdao2 = protocol.getDaoAssetPool(subDaoId2);
        // !!!! 1.3-56 step 1
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 0);
        assertEq(assetPool_subdao.balance, 0);
        assertEq(assetPool_maindao.balance, 0);
        assertEq(assetPool_subdao2.balance, 0);

        // !!!! 1.3-56 step 2
        deal(assetPool_subdao, 2 ether);
        deal(assetPool_maindao, 3 ether);
        deal(assetPool_subdao2, 4 ether);
        assertEq(assetPool_subdao.balance, 2 ether);
        assertEq(assetPool_maindao.balance, 3 ether);
        assertEq(assetPool_subdao2.balance, 4 ether);

        // !!!! 1.3-56 step 3 mint
        deal(daoCreator3.addr, 1 ether);
        assertEq(daoCreator3.addr.balance, 1 ether);
        // daoCreator3 is subdao_creator/canvas/minter
        super._mintNftChangeBal(
            subDaoId,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.3 ether,
            daoCreator3.key,
            daoCreator3.addr
        );

        // !!!! 1.3-56 step 3 mint fee dispatch
        // builder
        // 1 ether init
        // - 0.3 ether for mint
        // + 0.3 ether * 0.025
        assertEq(daoCreator3.addr.balance, 0.7075 ether);

        // subdao asset pool
        // init with 2 ether
        // + 0.3 ether * 0.35
        // - 2 ether / 10drb
        assertEq(assetPool_subdao.balance, 1.905 ether, "assetPool_subdao");
        // self reward
        // + 2 ether / 10drb * 0.5
        assertEq(address(protocol).balance, 0.1 ether, "protocol");

        // !!!! 1.3-56 step 4
        // main dao pool
        // init with 3 ether
        // + 2 ether / 10drb * 0.2
        assertEq(assetPool_maindao.balance, 3.04 ether, "assetPool_maindao");

        // !!!! 1.3-56 step 5
        // subdao2 pool
        // init with 4 ether
        // + 2 ether / 10drb * 0.1
        assertEq(assetPool_subdao2.balance, 4.02 ether, "assetPool_subdao2");

        // redeem pool
        // + 0.3 ether * 0.6
        // + 2 ether / 10drb * 0.2
        assertEq(redeemPool.balance, 0.22 ether, "redeemPool");
        // pdao
        // + 0.3 ether * (1 - 0.025 - 0.35 - 0.6)
        assertEq(protocolPool.balance, 0.0075 ether, "protocolPool");

        // default canvas next price is 0.01 ether
        super._mintNftChangeBal(
            subDaoId,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId)), "-", vm.toString(uint256(1)), ".json"
            ),
            0,
            daoCreator3.key,
            daoCreator3.addr
        );

        // !!!! 1.3-56 step 6 mint fee dispatch
        // builder
        // 0.7075 ether init
        // - 0.01 ether for mint
        // + 0.01 ether * 0.075
        assertEq(daoCreator3.addr.balance, 0.69825 ether);

        // !!!! 1.3-56 step 7
        // redeem pool
        // + 0.01 ether * 0.7
        assertEq(redeemPool.balance, 0.227 ether, "redeemPool");

        // !!!! 1.3-56 step 8
        // subdao asset pool
        // init with 1.905 ether
        // + 0.01 ether * 0.2
        assertEq(assetPool_subdao.balance, 1.907 ether, "assetPool_subdao");

        // self reward
        assertEq(address(protocol).balance, 0.1 ether, "protocol");
        // pdao
        // + 0.01 ether * (1 - 0.075 - 0.2 - 0.7)
        assertEq(protocolPool.balance, 0.00775 ether, "protocolPool");

        vm.roll(3);

        // set claim param
        ClaimMultiRewardParam memory claimParam;
        claimParam.protocol = address(protocol);
        bytes32[] memory cavansIds = new bytes32[](3);
        cavansIds[0] = canvasId1;
        cavansIds[1] = canvasId2;
        cavansIds[2] = canvasId3;
        bytes32[] memory daoIds = new bytes32[](3);
        daoIds[0] = daoId;
        daoIds[1] = subDaoId2;
        daoIds[2] = subDaoId;
        claimParam.canvasIds = cavansIds;
        claimParam.daoIds = daoIds;

        vm.prank(daoCreator3.addr);
        uint256 daoCreator3_eth_balance_before_claim = daoCreator3.addr.balance;
        uint256 protocol_eth_balance_before_claim = protocolPool.balance;
        universalClaimer.claimMultiReward(claimParam);
        uint256 daoCreator3_eth_balance_after_claim = daoCreator3.addr.balance;
        uint256 protocol_eth_balance_after_claim = protocolPool.balance;

        // eth
        // self reward eth is 0.1 ether
        // daoCreator3 is minter/canvas/dao_creator
        // + 0.1 ether * (0.08 + 0.2 + 0.7)
        assertEq(daoCreator3_eth_balance_after_claim - daoCreator3_eth_balance_before_claim, 0.098 ether, "daoCreator3");
        // protocol pool
        // + 0.1 ether * (1 - 0.08 - 0.2 - 0.7)
        assertEq(protocol_eth_balance_after_claim - protocol_eth_balance_before_claim, 0.002 ether, "protocol");
        assertEq(address(protocol).balance, 0, "protocol");
    }

    // testcase 1.3-57
    function test_PDCreateFunding_1_3_57() public {
        // main dao
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        // subdao2
        param.daoUri = "continuous subdao2 uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        bytes32 canvasId2 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        bytes32 subDaoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        // subdao
        param.daoUri = "continuous subdao uri";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        // to main dao and subdao2
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = subDaoId2;
        // output ratio
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 0;
        param.childrenDaoOutputRatios[1] = 1000;
        param.selfRewardOutputRatio = 7000;
        // input ratio
        param.redeemPoolInputRatio = 2000;
        param.selfRewardInputRatio = 5000;
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 2000;
        param.childrenDaoInputRatios[1] = 1000;
        param.isProgressiveJackpot = true;
        param.noPermission = true;
        param.uniPriceModeOff = true;
        param.mintableRound = 10;
        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator3.addr);

        _grantPool(subDaoId, daoCreator.addr, 80_000_000 ether);

        address token = protocol.getDaoToken(subDaoId);
        address assetPool_subdao = protocol.getDaoAssetPool(subDaoId);
        address assetPool_maindao = protocol.getDaoAssetPool(daoId);
        address assetPool_subdao2 = protocol.getDaoAssetPool(subDaoId2);
        // !!!! 1.3-57 step 1
        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 80_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 0);

        vm.roll(2);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 0 ether, "round 2");
        vm.roll(3);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 0 ether, "round 3 before mint");

        // !!!! 1.3-57 step 3 mint
        // daoCreator3 is subdao_creator/canvas/minter
        deal(nftMinter.addr, 1 ether);
        assertEq(nftMinter.addr.balance, 1 ether, "nftMinter");
        super._mintNftChangeBal(
            subDaoId,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.3 ether,
            daoCreator3.key,
            nftMinter.addr
        );

        // !!!! 1.3-57 step 4
        // 80_000_000 ether * (3drb / 10drb) * 0.1
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 2_400_000 ether);

        // !!!! 1.3-57 step 5
        // init with 80_000_000 ether
        // - 80_000_000 ether * (3drb / 10drb) * (0.1 + 0.7)
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 60_800_000 ether);

        vm.roll(4);

        // set claim param
        ClaimMultiRewardParam memory claimParam;
        claimParam.protocol = address(protocol);
        bytes32[] memory cavansIds = new bytes32[](3);
        cavansIds[0] = canvasId1;
        cavansIds[1] = canvasId2;
        cavansIds[2] = canvasId3;
        bytes32[] memory daoIds = new bytes32[](3);
        daoIds[0] = daoId;
        daoIds[1] = subDaoId2;
        daoIds[2] = subDaoId;
        claimParam.canvasIds = cavansIds;
        claimParam.daoIds = daoIds;

        assertEq(IERC20(token).balanceOf(nftMinter.addr), 0);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 0);

        // !!!! 1.3-57 step 7/8/9
        // to dispatch 80_000_000 ether * (3drb / 10drb) * 0.7
        // 8% for miner, 20% for canvas, 70% for creator

        vm.prank(nftMinter.addr);
        universalClaimer.claimMultiReward(claimParam);
        // 8% for miner
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 1_344_000 ether);

        vm.prank(daoCreator3.addr);
        universalClaimer.claimMultiReward(claimParam);
        // 20% for canvas and 70% for creator
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 15_120_000 ether);
    }

    // testcase 1.3-58
    function test_PDCreateFunding_1_3_58() public {
        // main dao
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        // subdao2
        param.daoUri = "continuous subdao2 uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        bytes32 canvasId2 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        bytes32 subDaoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        // subdao
        param.daoUri = "continuous subdao uri";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        // to main dao and subdao2
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = subDaoId2;
        // output ratio
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 0;
        param.childrenDaoOutputRatios[1] = 1000;
        param.selfRewardOutputRatio = 7000;
        // input ratio
        param.redeemPoolInputRatio = 2000;
        param.selfRewardInputRatio = 5000;
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 2000;
        param.childrenDaoInputRatios[1] = 1000;
        param.isProgressiveJackpot = true;
        param.noPermission = true;
        param.uniPriceModeOff = true;
        param.mintableRound = 10;
        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator3.addr);

        address token = protocol.getDaoToken(subDaoId);
        address assetPool_subdao = protocol.getDaoAssetPool(subDaoId);
        address assetPool_maindao = protocol.getDaoAssetPool(daoId);
        address assetPool_subdao2 = protocol.getDaoAssetPool(subDaoId2);
        // !!!! 1.3-58 step 1
        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 0);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 0);

        _grantPool(subDaoId2, daoCreator.addr, 20_000_000 ether);

        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);

        vm.roll(4);

        deal(nftMinter.addr, 1 ether);
        assertEq(nftMinter.addr.balance, 1 ether, "nftMinter");
        super._mintNftChangeBal(
            subDaoId,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.3 ether,
            daoCreator3.key,
            nftMinter.addr
        );

        // !!!! 1.3-58 step 2
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 0);

        // set claim param
        ClaimMultiRewardParam memory claimParam;
        claimParam.protocol = address(protocol);
        bytes32[] memory cavansIds = new bytes32[](3);
        cavansIds[0] = canvasId1;
        cavansIds[1] = canvasId2;
        cavansIds[2] = canvasId3;
        bytes32[] memory daoIds = new bytes32[](3);
        daoIds[0] = daoId;
        daoIds[1] = subDaoId2;
        daoIds[2] = subDaoId;
        claimParam.canvasIds = cavansIds;
        claimParam.daoIds = daoIds;

        vm.prank(nftMinter.addr);
        universalClaimer.claimMultiReward(claimParam);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 0);
        vm.prank(daoCreator3.addr);
        universalClaimer.claimMultiReward(claimParam);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 0);

        // !!!! 1.3-58 step 3

        _grantPool(subDaoId, daoCreator.addr, 80_000_000 ether);

        // !!!! 1.3-58 step 4
        vm.roll(7);

        // !!!! 1.3-58 step 5
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 80_000_000 ether);
        // !!!! 1.3-58 step 6/7/8
        vm.prank(nftMinter.addr);
        universalClaimer.claimMultiReward(claimParam);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 0);
        vm.prank(daoCreator3.addr);
        universalClaimer.claimMultiReward(claimParam);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 0);
    }

    // testcase 1.3-63
    function test_PDCreateFunding_1_3_63() public {
        // main dao
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        // subdao2
        param.daoUri = "continuous subdao2 uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        param.isBasicDao = false;
        param.existDaoId = daoId;
        bytes32 subDaoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        // subdao
        param.daoUri = "continuous subdao uri";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        // to main dao and subdao2
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = subDaoId2;

        // !!!! 1.3-63 step 1
        // output ratio
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 0;
        param.childrenDaoOutputRatios[1] = 0;
        param.selfRewardOutputRatio = 0;
        // input ratio
        param.redeemPoolInputRatio = 0;
        param.selfRewardInputRatio = 0;
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 0;
        param.childrenDaoInputRatios[1] = 0;
        param.isProgressiveJackpot = true;
        param.noPermission = true;
        param.uniPriceModeOff = true;
        param.mintableRound = 10;
        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator3.addr);

        _grantPool(subDaoId2, daoCreator.addr, 20_000_000 ether);
        _grantPool(subDaoId, daoCreator.addr, 30_000_000 ether);

        address token = protocol.getDaoToken(subDaoId);
        address assetPool_subdao = protocol.getDaoAssetPool(subDaoId);
        address redeemPool = protocol.getDaoFeePool(subDaoId);
        address protocolPool = protocol.protocolFeePool();
        address assetPool_maindao = protocol.getDaoAssetPool(daoId);
        address assetPool_subdao2 = protocol.getDaoAssetPool(subDaoId2);

        deal(assetPool_maindao, 4 ether);
        deal(assetPool_subdao2, 5 ether);
        deal(assetPool_subdao, 6 ether);

        // !!!! 1.3-63 step 2
        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 30_000_000 ether);
        assertEq(IERC20(token).balanceOf(redeemPool), 0);
        assertEq(IERC20(token).balanceOf(protocolPool), 0);
        assertEq(assetPool_maindao.balance, 4 ether);
        assertEq(assetPool_subdao2.balance, 5 ether);
        assertEq(assetPool_subdao.balance, 6 ether);
        assertEq(redeemPool.balance, 0);
        assertEq(protocolPool.balance, 0);

        // !!!! 1.3-63 step 3
        deal(nftMinter.addr, 1 ether);
        assertEq(nftMinter.addr.balance, 1 ether, "nftMinter");
        uint256 daoCreator3_eth_balance_before_mint = daoCreator3.addr.balance;
        super._mintNftChangeBal(
            subDaoId,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.3 ether,
            daoCreator3.key,
            nftMinter.addr
        );
        uint256 daoCreator3_eth_balance_after_mint = daoCreator3.addr.balance;

        assertEq(nftMinter.addr.balance, 0.7 ether);
        // 0.3 ether * 0.025
        assertEq(daoCreator3_eth_balance_after_mint - daoCreator3_eth_balance_before_mint, 0.0075 ether);
        // 0.3 ether * 0.35 + 6
        assertEq(assetPool_subdao.balance, 6.105 ether);
        // 0.3 ether * 0.6
        assertEq(redeemPool.balance, 0.18 ether);
        // 0.3 ether * (1 - 0.025 - 0.35 - 0.6)
        assertEq(protocolPool.balance, 0.0075 ether);

        assertEq(assetPool_maindao.balance, 4 ether);
        assertEq(assetPool_subdao2.balance, 5 ether);
        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 30_000_000 ether);
        assertEq(IERC20(token).balanceOf(redeemPool), 0);
        assertEq(IERC20(token).balanceOf(protocolPool), 0);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 0);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 0);

        // !!!! 1.3-63 step 4
        vm.roll(5);

        // !!!! 1.3-63 step 5/6
        assertEq(nftMinter.addr.balance, 0.7 ether);
        // 0.3 ether * 0.025
        assertEq(daoCreator3_eth_balance_after_mint - daoCreator3_eth_balance_before_mint, 0.0075 ether);
        // 0.3 ether * 0.35 + 6
        assertEq(assetPool_subdao.balance, 6.105 ether);
        // 0.3 ether * 0.6
        assertEq(redeemPool.balance, 0.18 ether);
        // 0.3 ether * (1 - 0.025 - 0.35 - 0.6)
        assertEq(protocolPool.balance, 0.0075 ether);

        assertEq(assetPool_maindao.balance, 4 ether);
        assertEq(assetPool_subdao2.balance, 5 ether);
        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 30_000_000 ether);
        assertEq(IERC20(token).balanceOf(redeemPool), 0);
        assertEq(IERC20(token).balanceOf(protocolPool), 0);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 0);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 0);

        // !!!! 1.3-63 step 4
        vm.roll(9);

        // !!!! 1.3-63 step 5/6
        assertEq(nftMinter.addr.balance, 0.7 ether);
        // 0.3 ether * 0.025
        assertEq(daoCreator3_eth_balance_after_mint - daoCreator3_eth_balance_before_mint, 0.0075 ether);
        // 0.3 ether * 0.35 + 6
        assertEq(assetPool_subdao.balance, 6.105 ether);
        // 0.3 ether * 0.6
        assertEq(redeemPool.balance, 0.18 ether);
        // 0.3 ether * (1 - 0.025 - 0.35 - 0.6)
        assertEq(protocolPool.balance, 0.0075 ether);

        assertEq(assetPool_maindao.balance, 4 ether);
        assertEq(assetPool_subdao2.balance, 5 ether);
        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 30_000_000 ether);
        assertEq(IERC20(token).balanceOf(redeemPool), 0);
        assertEq(IERC20(token).balanceOf(protocolPool), 0);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 0);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 0);
    }

    // testcase 1.3-64
    function test_PDCreateFunding_1_3_64() public {
        // main dao
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        // subdao2
        param.daoUri = "continuous subdao2 uri";
        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        bytes32 canvasId2 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        bytes32 subDaoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        // subdao
        param.daoUri = "continuous subdao uri";
        param.canvasId = keccak256(abi.encode(daoCreator3.addr, block.timestamp));
        bytes32 canvasId3 = param.canvasId;
        param.isBasicDao = false;
        param.existDaoId = daoId;
        // to main dao and subdao2
        param.childrenDaoId = new bytes32[](2);
        param.childrenDaoId[0] = daoId;
        param.childrenDaoId[1] = subDaoId2;

        // !!!! 1.3-64 step 1
        // output ratio
        param.childrenDaoOutputRatios = new uint256[](2);
        param.childrenDaoOutputRatios[0] = 0;
        param.childrenDaoOutputRatios[1] = 0;
        param.selfRewardOutputRatio = 10_000;
        // input ratio
        param.redeemPoolInputRatio = 0;
        param.selfRewardInputRatio = 10_000;
        param.childrenDaoInputRatios = new uint256[](2);
        param.childrenDaoInputRatios[0] = 0;
        param.childrenDaoInputRatios[1] = 0;
        param.isProgressiveJackpot = true;
        param.noPermission = true;
        param.uniPriceModeOff = true;
        param.mintableRound = 10;
        bytes32 subDaoId = super._createDaoForFunding(param, daoCreator3.addr);

        _grantPool(subDaoId2, daoCreator.addr, 20_000_000 ether);
        _grantPool(subDaoId, daoCreator.addr, 30_000_000 ether);

        address token = protocol.getDaoToken(subDaoId);
        address assetPool_subdao = protocol.getDaoAssetPool(subDaoId);
        address redeemPool = protocol.getDaoFeePool(subDaoId);
        address protocolPool = protocol.protocolFeePool();
        address assetPool_maindao = protocol.getDaoAssetPool(daoId);
        address assetPool_subdao2 = protocol.getDaoAssetPool(subDaoId2);

        deal(assetPool_maindao, 4 ether);
        deal(assetPool_subdao2, 5 ether);
        deal(assetPool_subdao, 6 ether);

        // !!!! 1.3-64 step 2
        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 30_000_000 ether);
        assertEq(IERC20(token).balanceOf(redeemPool), 0);
        assertEq(IERC20(token).balanceOf(protocolPool), 0);
        assertEq(assetPool_maindao.balance, 4 ether);
        assertEq(assetPool_subdao2.balance, 5 ether);
        assertEq(assetPool_subdao.balance, 6 ether);
        assertEq(redeemPool.balance, 0);
        assertEq(protocolPool.balance, 0);

        // !!!! 1.3-64 step 3
        deal(nftMinter.addr, 1 ether);
        assertEq(nftMinter.addr.balance, 1 ether, "nftMinter");
        uint256 daoCreator3_eth_balance_before_mint = daoCreator3.addr.balance;
        super._mintNftChangeBal(
            subDaoId,
            canvasId3,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(subDaoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.3 ether,
            daoCreator3.key,
            nftMinter.addr
        );
        uint256 daoCreator3_eth_balance_after_mint = daoCreator3.addr.balance;

        // !!!! 1.3-64 step 4
        vm.roll(2);

        // !!!! 1.3-64 step 5
        // 1 ether - 0.3 ether
        assertEq(nftMinter.addr.balance, 0.7 ether);
        // 0.3 ether * 0.025
        assertEq(daoCreator3_eth_balance_after_mint - daoCreator3_eth_balance_before_mint, 0.0075 ether);
        // init with 6 ether
        // mint fee: + 0.3 ether * 0.35
        // reward: - 6 ether * (1drb / 10drb)
        assertEq(assetPool_subdao.balance, 5.505 ether);
        // 6 ether * (1drb / 10drb)
        assertEq(address(protocol).balance, 0.6 ether);
        // 0.3 ether * 0.6
        assertEq(redeemPool.balance, 0.18 ether);
        // 0.3 ether * (1 - 0.025 - 0.35 - 0.6)
        assertEq(protocolPool.balance, 0.0075 ether);
        assertEq(assetPool_maindao.balance, 4 ether);
        assertEq(assetPool_subdao2.balance, 5 ether);

        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);
        // init with 30_000_000 ether
        // reward: 30_000_000 ether * (1drb / 10drb)
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 27_000_000 ether);
        // 30_000_000 ether * (1drb / 10drb)
        assertEq(IERC20(token).balanceOf(address(protocol)), 3_000_000 ether);
        assertEq(IERC20(token).balanceOf(redeemPool), 0);
        assertEq(IERC20(token).balanceOf(protocolPool), 0);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 0);
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 0);

        // !!!! 1.3-64 step 6
        // set claim param
        ClaimMultiRewardParam memory claimParam;
        claimParam.protocol = address(protocol);
        bytes32[] memory cavansIds = new bytes32[](3);
        cavansIds[0] = canvasId1;
        cavansIds[1] = canvasId2;
        cavansIds[2] = canvasId3;
        bytes32[] memory daoIds = new bytes32[](3);
        daoIds[0] = daoId;
        daoIds[1] = subDaoId2;
        daoIds[2] = subDaoId;
        claimParam.canvasIds = cavansIds;
        claimParam.daoIds = daoIds;

        {
            vm.prank(nftMinter.addr);
            uint256 daoCreator3_eth_balance_before_claim = daoCreator3.addr.balance;
            universalClaimer.claimMultiReward(claimParam);
            uint256 daoCreator3_eth_balance_after_claim = daoCreator3.addr.balance;

            // eth
            // 1 ether - 0.3 ether
            // + 0.6 ether * 0.08
            assertEq(nftMinter.addr.balance, 0.748 ether);
            // 0.6 ether * (0.2 + 0.7)
            assertEq(daoCreator3_eth_balance_after_claim - daoCreator3_eth_balance_before_claim, 0.54 ether);
            // init with 6 ether
            // mint fee: + 0.3 ether * 0.35
            // reward: - 6 ether * (1drb / 10drb)
            assertEq(assetPool_subdao.balance, 5.505 ether);
            // 6 ether * (1drb / 10drb)
            assertEq(address(protocol).balance, 0 ether);
            // 0.3 ether * 0.6
            assertEq(redeemPool.balance, 0.18 ether);
            // mint fee: + 0.3 ether * (1 - 0.025 - 0.35 - 0.6)
            // reward: + 0.6 ether * (1 - 0.08 - 0.2 - 0.7)
            assertEq(protocolPool.balance, 0.0195 ether);
            assertEq(assetPool_maindao.balance, 4 ether);
            assertEq(assetPool_subdao2.balance, 5 ether);
        }

        // erc20
        assertEq(IERC20(token).balanceOf(assetPool_maindao), 50_000_000 ether);
        assertEq(IERC20(token).balanceOf(assetPool_subdao2), 20_000_000 ether);
        // init with 30_000_000 ether
        // reward: 30_000_000 ether * (1drb / 10drb)
        assertEq(IERC20(token).balanceOf(assetPool_subdao), 27_000_000 ether);
        assertEq(IERC20(token).balanceOf(address(protocol)), 0);
        assertEq(IERC20(token).balanceOf(redeemPool), 0);
        // 30_000_000 ether * (1drb / 10drb) * 0.08
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 240_000 ether);
        // 30_000_000 ether * (1drb / 10drb) * (0.2 + 0.7)
        assertEq(IERC20(token).balanceOf(daoCreator3.addr), 2_700_000 ether);
        // 30_000_000 ether * (1drb / 10drb) * (1 - 0.08 - 0.2 - 0.7)
        assertEq(IERC20(token).balanceOf(protocolPool), 60_000 ether);

        vm.prank(daoCreator3.addr);
        universalClaimer.claimMultiReward(claimParam);
    }
}

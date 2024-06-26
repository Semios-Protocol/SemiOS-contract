// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DeployHelper } from "test/foundry/utils/DeployHelper.sol";

import { UserMintCapParam, SetChildrenParam } from "contracts/interface/D4AStructs.sol";
import { ClaimMultiRewardParam } from "contracts/D4AUniversalClaimer.sol";

import { ExceedMinterMaxMintAmount, NotAncestorDao } from "contracts/interface/D4AErrors.sol";
import { D4AFeePool } from "contracts/feepool/D4AFeePool.sol";
import { D4AERC721 } from "contracts/D4AERC721.sol";
import { PDCreate } from "contracts/PDCreate.sol";

import { console2 } from "forge-std/Test.sol";

contract ProtoDaoMintFee is DeployHelper {
    function setUp() public {
        super.setUpEnv();
    }
    // testcase 1.3-15

    function test_PDCreateFunding_1_3_59() public {
        // dao: daoCreator
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.selfRewardInputRatio = 10_000;
        param.selfRewardOutputRatio = 10_000;
        param.noPermission = true;
        // param.noDefaultRatio = true;
        // param.canvasCreatorOutputRewardRatio = 2000;
        // param.minterOutputRewardRatio = 5000;
        // param.daoCreatorOutputRewardRatio = 2800;
        // param.canvasCreatorInputRewardRatio = 2000;
        // param.minterInputRewardRatio = 5000;
        // param.daoCreatorInputRewardRatio = 2800;

        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        bytes32 canvasId2 = param.canvasId;
        param.existDaoId = daoId;
        param.isBasicDao = false;
        param.noPermission = true;
        param.topUpMode = false;
        param.uniPriceModeOff = true;
        param.mintableRound = 10;
        param.daoUri = "continuous dao uri";

        param.childrenDaoId = new bytes32[](1);
        param.childrenDaoId[0] = daoId;
        // output ratio
        param.childrenDaoOutputRatios = new uint256[](1);
        param.childrenDaoOutputRatios[0] = 8000;
        // input ratio
        param.childrenDaoInputRatios = new uint256[](1);
        param.childrenDaoInputRatios[0] = 8000;

        param.selfRewardInputRatio = 0;
        param.selfRewardOutputRatio = 0;

        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        address token = protocol.getDaoToken(daoId);
        address pool = protocol.getDaoAssetPool(daoId);
        address pool2 = protocol.getDaoAssetPool(daoId2);
        deal(pool, 10 ether);
        deal(pool2, 20 ether);

        _grantPool(daoId2, daoCreator.addr, 40_000 ether);
        //step 6
        super._mintNft(
            daoId2,
            canvasId2,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(0)), ".json"
            ),
            0.05 ether,
            daoCreator2.key,
            nftMinter.addr
        );
        assertEq(pool.balance, 10 ether + 2 ether * 4 / 5);
        assertEq(IERC20(token).balanceOf(pool), 50_000_000 ether + 4000 ether * 4 / 5);

        vm.roll(2);
        deal(daoCreator.addr, 0);
        protocol.claimDaoNftOwnerReward(daoId);
        protocol.claimNftMinterReward(daoId, nftMinter.addr);
        protocol.claimCanvasReward(canvasId1);
        assertEq(daoCreator.addr.balance, 0);
        assertEq(IERC20(token).balanceOf(daoCreator.addr), 0);
        assertEq(nftMinter.addr.balance, 0);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 0);
    }

    function test_PDCreateFunding_1_3_60() public {
        // dao: daoCreator
        DeployHelper.CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.selfRewardInputRatio = 10_000;
        param.selfRewardOutputRatio = 10_000;
        param.noPermission = true;
        param.mintableRound = 10;

        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);

        param.canvasId = keccak256(abi.encode(daoCreator2.addr, block.timestamp));
        param.existDaoId = daoId;
        param.isBasicDao = false;
        param.noPermission = true;
        param.topUpMode = false;
        param.uniPriceModeOff = true;
        param.mintableRound = 10;
        param.daoUri = "continuous dao uri";

        param.childrenDaoId = new bytes32[](1);
        param.childrenDaoId[0] = daoId;
        // output ratio
        param.childrenDaoOutputRatios = new uint256[](1);
        param.childrenDaoOutputRatios[0] = 8000;
        // input ratio
        param.childrenDaoInputRatios = new uint256[](1);
        param.childrenDaoInputRatios[0] = 8000;

        param.selfRewardInputRatio = 0;
        param.selfRewardOutputRatio = 0;

        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator2.addr);

        address token = protocol.getDaoToken(daoId);
        address pool = protocol.getDaoAssetPool(daoId);
        address pool2 = protocol.getDaoAssetPool(daoId2);
        deal(pool, 10 ether);
        deal(pool2, 20 ether);

        _grantPool(daoId2, daoCreator.addr, 40_000 ether);
        //step 6
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
        vm.roll(2);

        deal(daoCreator.addr, 0);
        protocol.claimDaoNftOwnerReward(daoId);
        protocol.claimNftMinterReward(daoId, nftMinter.addr);
        protocol.claimCanvasReward(canvasId1);
        // 10/10*0.9
        assertEq(daoCreator.addr.balance, 0.9 ether);
        assertEq(IERC20(token).balanceOf(daoCreator.addr), 4_500_000 ether);
        // 0.08
        assertEq(nftMinter.addr.balance, 0.08 ether);
        assertEq(IERC20(token).balanceOf(nftMinter.addr), 400_000 ether);
    }
}

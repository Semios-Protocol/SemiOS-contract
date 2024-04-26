// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { DeployHelper } from "test/foundry/utils/DeployHelper.sol";
import { PDProtocolHarness } from "test/foundry/harness/PDProtocolHarness.sol";
import { BasicDaoUnlocker } from "contracts/BasicDaoUnlocker.sol";
import { D4AFeePool } from "contracts/feepool/D4AFeePool.sol";
import { PDCreate } from "contracts/PDCreate.sol";
import "contracts/interface/D4AStructs.sol";

import { D4AERC721 } from "contracts/D4AERC721.sol";
import { console2 } from "forge-std/console2.sol";
import "contracts/interface/D4AErrors.sol";
import {
    PriceTemplateType, RewardTemplateType, TemplateChoice, PlanTemplateType
} from "contracts/interface/D4AEnums.sol";

contract PDPlanTest is DeployHelper {
    bytes32 daoId;
    bytes32 daoId2;
    bytes32 canvasId1;
    bytes32 canvasId2;
    NftIdentifier[] nfts;

    function setUp() public {
        setUpEnv();
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        canvasId1 = param.canvasId;
        param.existDaoId = bytes32(0);
        param.isBasicDao = true;
        param.isProgressiveJackpot = true;
        param.noPermission = true;
        param.unifiedPrice = 0.1 ether;
        param.topUpMode = true;
        daoId = _createDaoForFunding(param, daoCreator.addr);
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp + 1));
        param.isBasicDao = false;
        param.existDaoId = daoId;
        param.topUpMode = false;
        param.daoUri = "normal dao";
        canvasId2 = param.canvasId;
        daoId2 = _createDaoForFunding(param, daoCreator.addr);
        //initial topup account
        _testERC721.mint(nftMinter.addr, 0);
        _testERC721.mint(nftMinter1.addr, 1);
        _testERC721.mint(nftMinter2.addr, 2);
        _testERC721.mint(nftMinter3.addr, 3);
        _testERC20.mint(address(this), 100 ether);
        _testERC20.approve(address(protocol), 100 ether);

        nfts.push(NftIdentifier(address(_testERC721), 0));
        nfts.push(NftIdentifier(address(_testERC721), 1));
        nfts.push(NftIdentifier(address(_testERC721), 2));
        nfts.push(NftIdentifier(address(_testERC721), 3));
    }

    function test_planBasic() public {
        //minter 0 has balance in round 1;
        MintNftParamTest memory nftParam;
        nftParam.daoId = daoId;
        nftParam.canvasId = canvasId1;
        nftParam.tokenUri = "nft 0";
        nftParam.flatPrice = 0.1 ether;
        nftParam.canvasCreatorKey = daoCreator.key;
        nftParam.nftIdentifier = NftIdentifier(address(_testERC721), 0);
        //minter0 have balance in round 1
        super._mintNftWithParam(nftParam, nftMinter.addr);

        //plan begin in round 2
        protocol.createPlan(daoId, 2, 1, 10, 4_200_000, address(_testERC20), false, false, PlanTemplateType(0));
        vm.roll(2);
        protocol.updateTopUpAccount(daoId, NftIdentifier(address(_testERC721), 0));
        nftParam.tokenUri = "nft 1";
        nftParam.nftIdentifier = NftIdentifier(address(_testERC721), 1);
        super._mintNftWithParam(nftParam, nftMinter1.addr);
        //current contribuction: 0,0,0,0
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 0));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 1));
        assertEq(_testERC20.balanceOf(nftMinter.addr), 0);
        assertEq(_testERC20.balanceOf(nftMinter1.addr), 0);
        vm.roll(3);
        protocol.updateMultiTopUpAccount(daoId, nfts);
        nftParam.tokenUri = "nft 2";
        nftParam.nftIdentifier = NftIdentifier(address(_testERC721), 2);
        super._mintNftWithParam(nftParam, nftMinter2.addr);
        //in round 2 claim reward for round 1
        //current contribuction: 1,0,0,0
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 0));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 1));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 2));
        assertEq(_testERC20.balanceOf(nftMinter.addr), 420_000);
        assertEq(_testERC20.balanceOf(nftMinter1.addr), 0);
        assertEq(_testERC20.balanceOf(nftMinter2.addr), 0);
        vm.roll(4);
        nftParam.tokenUri = "nft 3";
        nftParam.nftIdentifier = NftIdentifier(address(_testERC721), 3);
        super._mintNftWithParam(nftParam, nftMinter3.addr);
        protocol.updateMultiTopUpAccount(daoId, nfts); //挂账和mint的先后顺序不影响，因为本回合的挂账都不会成功
        //current contribuction: 1,1,0,0
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 0));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 1));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 2));
        assertEq(_testERC20.balanceOf(nftMinter.addr), 420_000 + 210_000);
        assertEq(_testERC20.balanceOf(nftMinter1.addr), 210_000);
        assertEq(_testERC20.balanceOf(nftMinter2.addr), 0);
        vm.roll(5);
        protocol.updateMultiTopUpAccount(daoId, nfts);
        //current contribuction: 1,1,1,0
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 0));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 1));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 2));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 3));
        assertEq(_testERC20.balanceOf(nftMinter.addr), 420_000 + 210_000 + 140_000);
        assertEq(_testERC20.balanceOf(nftMinter1.addr), 210_000 + 140_000);
        assertEq(_testERC20.balanceOf(nftMinter2.addr), 140_000);
        assertEq(_testERC20.balanceOf(nftMinter3.addr), 0);
        vm.roll(6);
        protocol.updateMultiTopUpAccount(daoId, nfts);
        //current contribuction: 1,1,1,1
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 0));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 1));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 2));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 3));
        assertEq(_testERC20.balanceOf(nftMinter.addr), 420_000 + 210_000 + 140_000 + 105_000);
        assertEq(_testERC20.balanceOf(nftMinter1.addr), 210_000 + 140_000 + 105_000);
        assertEq(_testERC20.balanceOf(nftMinter2.addr), 140_000 + 105_000);
        assertEq(_testERC20.balanceOf(nftMinter3.addr), 105_000);
        vm.roll(7);
        //simple quit, for round 6 still 1,1,1,1
        nftParam.tokenUri = "nft 4";
        nftParam.nftIdentifier = NftIdentifier(address(_testERC721), 0);
        nftParam.daoId = daoId2;
        nftParam.canvasId = canvasId2;
        super._mintNftWithParam(nftParam, nftMinter.addr);
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 0));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 1));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 2));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 3));
        //current contribuction: 1,1,1,0
        assertEq(_testERC20.balanceOf(nftMinter.addr), 420_000 + 210_000 + 140_000 + 105_000 * 2);
        assertEq(_testERC20.balanceOf(nftMinter1.addr), 210_000 + 140_000 + 105_000 * 2);
        assertEq(_testERC20.balanceOf(nftMinter2.addr), 140_000 + 105_000 * 2, "a63");
        assertEq(_testERC20.balanceOf(nftMinter3.addr), 105_000 * 2, "a64");
        vm.roll(8);
        //using topup balance need not update
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 0));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 1));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 2));
        protocol.claimDaoPlanReward(daoId, NftIdentifier(address(_testERC721), 3));
        //current contribuction: 1,1,1,0
        assertEq(_testERC20.balanceOf(nftMinter.addr), 420_000 + 210_000 + 140_000 + 105_000 * 2, "a71");
        assertEq(_testERC20.balanceOf(nftMinter1.addr), 210_000 + 140_000 * 2 + 105_000 * 2, "a72");
        assertEq(_testERC20.balanceOf(nftMinter2.addr), 140_000 * 2 + 105_000 * 2, "a73");
        assertEq(_testERC20.balanceOf(nftMinter3.addr), 140_000 + 105_000 * 2, "a74");
    }
}

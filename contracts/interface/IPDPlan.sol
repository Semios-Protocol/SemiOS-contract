// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { PlanTemplateType } from "contracts/interface/D4AEnums.sol";
import { NftIdentifier, CreatePlanParam } from "contracts/interface/D4AStructs.sol";

interface IPDPlan {
    event NewSemiOsPlan(
        bytes32 planId,
        bytes32 daoId,
        uint256 startBlock,
        uint256 duration,
        uint256 totalRounds,
        uint256 totalReward,
        address rewardToken,
        PlanTemplateType planTemplateType,
        bool io,
        address owner,
        bool useTreasury,
        string planUri
    );
    event PlanTotalRewardAdded(bytes32 planId, uint256 amount, bool useTreasury);
    event PlanRewardClaimed(bytes32 planId, NftIdentifier nft, address owner, uint256 reward, address token);
    event PlanRewardClaimSignal();
    event PlanDeleted(bytes32 daoId, bytes32 planId);

    function createPlan(CreatePlanParam calldata param) external payable returns (bytes32 planId);
    function addPlanTotalReward(bytes32 planId, uint256 amount, bool useTreasury) external payable;
    function claimMultiPlanReward(bytes32[] calldata planIds, NftIdentifier calldata nft) external returns (uint256);
    function claimDaoPlanRewardForMultiNft(bytes32 daoId, NftIdentifier[] calldata nfts) external returns (uint256);
    function claimDaoPlanReward(bytes32 daoId, NftIdentifier calldata nft) external returns (uint256);
    function deletePlan(bytes32 planId) external;

    function updateTopUpAccount(
        bytes32 daoId,
        NftIdentifier memory nft
    )
        external
        returns (uint256 topUpOutputQuota, uint256 topUpInputQuota);

    function updateMultiTopUpAccount(bytes32 daoId, NftIdentifier[] calldata nfts) external;
    function getTopUpBalance(bytes32 daoId, NftIdentifier memory nft) external view returns (uint256, uint256);
    function getPlanCumulatedReward(bytes32 planId) external returns (uint256);
    function retriveUnclaimedToken(bytes32 planId) external;
    function getPlanCurrentRound(bytes32 planId) external view returns (uint256);
}

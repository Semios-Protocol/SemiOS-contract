// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { UpdateRewardParam } from "contracts/interface/D4AStructs.sol";

interface IRewardTemplateFunding {
    function updateRewardFunding(UpdateRewardParam memory param) external payable;

    function claimDaoCreatorReward(
        bytes32 daoId,
        address protocolFeePool,
        address daoCreator,
        uint256 currentRound,
        address token
    )
        external
        returns (uint256 protocolClaimableReward, uint256 daoCreatorClaimableReward);

    function claimCanvasCreatorReward(
        bytes32 daoId,
        bytes32 canvasId,
        address canvasCreator,
        uint256 currentRound,
        address token
    )
        external
        returns (uint256 claimableReward);

    function issueLastRoundReward(bytes32 daoId, address token) external;

    function claimNftMinterReward(
        bytes32 daoId,
        address nftMinter,
        uint256 currentRound,
        address token
    )
        external
        returns (uint256 claimableReward);
    //function getRoundReward(bytes32 daoId, uint256 round, address token) external view returns (uint256 rewardAmount);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { IRewardTemplate } from "contracts/interface/IRewardTemplate.sol";
import { UpdateRewardParam } from "contracts/interface/D4AStructs.sol";
import { BASIS_POINT } from "contracts/interface/D4AConstants.sol";
import { ExceedMaxMintableRound, InvalidRound } from "contracts/interface/D4AErrors.sol";
import { DaoStorage } from "contracts/storages/DaoStorage.sol";
import { RewardStorage } from "contracts/storages/RewardStorage.sol";
import { SettingsStorage } from "contracts/storages/SettingsStorage.sol";
import { D4AERC20 } from "contracts/D4AERC20.sol";

abstract contract RewardTemplateBase is IRewardTemplate {
    function updateReward(UpdateRewardParam memory param) public payable {
        // deal with daoFeeAmount being 0
        if (param.daoFeeAmount == 0) param.daoFeeAmount = 1 ether;

        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[param.daoId];

        uint256[] storage activeRounds =
            rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1].activeRounds;

        uint256 length = activeRounds.length;
        if (rewardInfo.isProgressiveJackpot) {
            if (param.currentRound - param.startRound >= param.totalRound) {
                revert ExceedMaxMintableRound();
            }
        } else {
            if (length != 0 && activeRounds[length - 1] != param.currentRound) {
                if (length >= param.totalRound) revert ExceedMaxMintableRound();
            }
        }

        // new checkpoint
        if (activeRounds.length == 0) {
            // has at least one old checkpoint
            if (rewardInfo.rewardCheckpoints.length > 1) {
                // last checkpoint's active rounds
                uint256[] storage activeRoundsOfLastCheckpoint =
                    rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 2].activeRounds;
                if (activeRoundsOfLastCheckpoint[activeRoundsOfLastCheckpoint.length - 1] != param.currentRound) {
                    _issueLastRoundReward(rewardInfo, param.daoId, param.token);
                    activeRounds.push(param.currentRound);
                }
            }
            // no old checkpoint
            else {
                // rewardInfo.rewardCheckpoints[0].lastActiveRound = param.currentRound;
                activeRounds.push(param.currentRound);
            }
        }
        // not new checkpoint
        else {
            if (activeRounds[activeRounds.length - 1] != param.currentRound) {
                // rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1].lastActiveRound =
                //     activeRounds[activeRounds.length - 1];
                _issueLastRoundReward(rewardInfo, param.daoId, param.token);
                activeRounds.push(param.currentRound);
            }
        }

        rewardInfo.rewardIssuePendingRound = param.currentRound;

        rewardInfo.totalWeights[param.currentRound] += param.daoFeeAmount;
        rewardInfo.protocolWeights[param.currentRound] +=
            param.daoFeeAmount * param.protocolERC20RatioInBps / BASIS_POINT;
        rewardInfo.daoCreatorWeights[param.currentRound] +=
            param.daoFeeAmount * param.daoCreatorERC20RatioInBps / BASIS_POINT;

        uint256 tokenRebateAmount =
            param.daoFeeAmount * param.nftMinterERC20RatioInBps * param.canvasRebateRatioInBps / BASIS_POINT ** 2;
        rewardInfo.canvasCreatorWeights[param.currentRound][param.canvasId] +=
            param.daoFeeAmount * param.canvasCreatorERC20RatioInBps / BASIS_POINT + tokenRebateAmount;
        rewardInfo.nftMinterWeights[param.currentRound][msg.sender] +=
            param.daoFeeAmount * param.nftMinterERC20RatioInBps / BASIS_POINT - tokenRebateAmount;
    }

    function claimDaoCreatorReward(
        bytes32 daoId,
        address protocolFeePool,
        address daoCreator,
        uint256 currentRound,
        address token
    )
        public
        returns (uint256 protocolClaimableReward, uint256 daoCreatorClaimableReward)
    {
        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];

        {
            uint256 length = rewardInfo.rewardCheckpoints.length;
            RewardStorage.RewardCheckpoint storage rewardCheckpoint = rewardInfo.rewardCheckpoints[length - 1];
            if (
                rewardCheckpoint.activeRounds.length == 0
                    || rewardCheckpoint.activeRounds[rewardCheckpoint.daoCreatorClaimableRoundIndex] == currentRound
            ) return (0, 0);
        }

        _updateRewardRoundAndIssue(rewardInfo, daoId, token, currentRound);

        RewardStorage.RewardCheckpoint[] storage rewardCheckpoints = rewardInfo.rewardCheckpoints;
        for (uint256 i; i < rewardCheckpoints.length; i++) {
            uint256 length = rewardCheckpoints[i].activeRounds.length;
            uint256[] memory activeRounds = rewardCheckpoints[i].activeRounds;

            // enumerate all active rounds, not including current round
            uint256 j = rewardCheckpoints[i].daoCreatorClaimableRoundIndex;
            for (; j < length && activeRounds[j] < currentRound;) {
                // given a past active round, get round reward
                uint256 roundReward = getRoundReward(daoId, activeRounds[j]);
                // update protocol's claimable reward
                protocolClaimableReward +=
                    roundReward * rewardInfo.protocolWeights[activeRounds[j]] / rewardInfo.totalWeights[activeRounds[j]];
                // update dao creator's claimable reward
                daoCreatorClaimableReward += roundReward * rewardInfo.daoCreatorWeights[activeRounds[j]]
                    / rewardInfo.totalWeights[activeRounds[j]];
                unchecked {
                    ++j;
                }
            }
            rewardCheckpoints[i].daoCreatorClaimableRoundIndex = j;
        }

        if (protocolClaimableReward > 0) D4AERC20(token).transfer(protocolFeePool, protocolClaimableReward);
        if (daoCreatorClaimableReward > 0) D4AERC20(token).transfer(daoCreator, daoCreatorClaimableReward);
    }

    function claimCanvasCreatorReward(
        bytes32 daoId,
        bytes32 canvasId,
        address canvasCreator,
        uint256 currentRound,
        address token
    )
        public
        returns (uint256 claimableReward)
    {
        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];

        {
            uint256 length = rewardInfo.rewardCheckpoints.length;
            RewardStorage.RewardCheckpoint storage rewardCheckpoint = rewardInfo.rewardCheckpoints[length - 1];
            if (
                rewardCheckpoint.activeRounds.length == 0
                    || rewardCheckpoint.activeRounds[rewardCheckpoint.canvasCreatorClaimableRoundIndexes[canvasId]]
                        == currentRound
            ) return 0;
        }

        _updateRewardRoundAndIssue(rewardInfo, daoId, token, currentRound);

        RewardStorage.RewardCheckpoint[] storage rewardCheckpoints = rewardInfo.rewardCheckpoints;
        for (uint256 i; i < rewardCheckpoints.length; i++) {
            uint256 length = rewardCheckpoints[i].activeRounds.length;
            uint256[] memory activeRounds = rewardCheckpoints[i].activeRounds;

            // enumerate all active rounds, not including current round
            uint256 j = rewardCheckpoints[i].canvasCreatorClaimableRoundIndexes[canvasId];
            for (; j < length && activeRounds[j] < currentRound;) {
                // given a past active round, get round reward
                uint256 roundReward = getRoundReward(daoId, activeRounds[j]);
                // update dao creator's claimable reward
                claimableReward += roundReward * rewardInfo.canvasCreatorWeights[activeRounds[j]][canvasId]
                    / rewardInfo.totalWeights[activeRounds[j]];
                unchecked {
                    ++j;
                }
            }
            rewardCheckpoints[i].canvasCreatorClaimableRoundIndexes[canvasId] = j;
        }

        if (claimableReward > 0) D4AERC20(token).transfer(canvasCreator, claimableReward);
    }

    function claimNftMinterReward(
        bytes32 daoId,
        address nftMinter,
        uint256 currentRound,
        address token
    )
        public
        returns (uint256 claimableReward)
    {
        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];

        {
            uint256 length = rewardInfo.rewardCheckpoints.length;
            RewardStorage.RewardCheckpoint storage rewardCheckpoint = rewardInfo.rewardCheckpoints[length - 1];
            if (
                rewardCheckpoint.activeRounds.length == 0
                    || rewardCheckpoint.activeRounds[rewardCheckpoint.nftMinterClaimableRoundIndexes[nftMinter]]
                        == currentRound
            ) return (0);
        }

        _updateRewardRoundAndIssue(rewardInfo, daoId, token, currentRound);

        RewardStorage.RewardCheckpoint[] storage rewardCheckpoints = rewardInfo.rewardCheckpoints;
        for (uint256 i; i < rewardCheckpoints.length; i++) {
            uint256 length = rewardCheckpoints[i].activeRounds.length;
            uint256[] memory activeRounds = rewardCheckpoints[i].activeRounds;

            // enumerate all active rounds, not including current round
            uint256 j = rewardCheckpoints[i].nftMinterClaimableRoundIndexes[nftMinter];
            for (; j < length && activeRounds[j] < currentRound;) {
                // given a past active round, get round reward
                uint256 roundReward = getRoundReward(daoId, activeRounds[j]);
                // update dao creator's claimable reward
                claimableReward += roundReward * rewardInfo.nftMinterWeights[activeRounds[j]][nftMinter]
                    / rewardInfo.totalWeights[activeRounds[j]];
                unchecked {
                    ++j;
                }
            }
            rewardCheckpoints[i].nftMinterClaimableRoundIndexes[nftMinter] = j;
        }

        if (claimableReward > 0) D4AERC20(token).transfer(nftMinter, claimableReward);
    }

    function setRewardCheckpoint(bytes32 daoId, int256 mintableRoundDelta) public payable {
        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];
        SettingsStorage.Layout storage settingsStorage = SettingsStorage.layout();

        if (rewardInfo.rewardCheckpoints.length == 0) {
            rewardInfo.rewardCheckpoints.push();
            rewardInfo.rewardCheckpoints[0].startRound = daoInfo.startRound;
            rewardInfo.rewardCheckpoints[0].totalRound = daoInfo.mintableRound;
            rewardInfo.rewardCheckpoints[0].totalReward = daoInfo.tokenMaxSupply;
        } else if (rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1].activeRounds.length == 0) {
            rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1].startRound = daoInfo.startRound;
            rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1].totalRound = daoInfo.mintableRound;
            rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1].totalReward = daoInfo.tokenMaxSupply;
        } else {
            // new checkpoint start at current round + 1
            uint256 currentRound = settingsStorage.drb.currentRound();
            RewardStorage.RewardCheckpoint storage rewardCheckpoint =
                rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1];
            uint256 totalRound = rewardCheckpoint.totalRound - (currentRound + 1 - rewardCheckpoint.startRound);
            _issueLastRoundReward(rewardInfo, daoId, daoInfo.token);
            uint256 totalReward = daoInfo.tokenMaxSupply - D4AERC20(daoInfo.token).totalSupply();
            if (rewardInfo.isProgressiveJackpot) totalReward -= getRoundReward(daoId, currentRound);

            // modify old checkpoint
            rewardCheckpoint.totalRound -= totalRound;
            rewardCheckpoint.totalReward -= totalReward;

            // set new checkpoint
            rewardInfo.rewardCheckpoints.push();
            uint256 length = rewardInfo.rewardCheckpoints.length;
            rewardInfo.rewardCheckpoints[length - 1].startRound = currentRound + 1;
            rewardInfo.rewardCheckpoints[length - 1].totalRound =
                SafeCast.toUint256(SafeCastLib.toInt256(totalRound) + mintableRoundDelta);
            rewardInfo.rewardCheckpoints[length - 1].totalReward = totalReward;
        }
    }

    /**
     * @dev given an array of active rounds and a round, return the number of rounds below the round
     */
    function _getBelowRoundCount(uint256[] memory activeRounds, uint256 round) public pure returns (uint256 index) {
        if (activeRounds.length == 0) return 0;

        uint256 l;
        uint256 r = activeRounds.length - 1;
        uint256 mid;
        while (l < r) {
            mid = l + r >> 1;
            if (activeRounds[mid] < round) l = mid + 1;
            else r = mid;
        }
        return activeRounds[l] == round ? l : l + 1;
    }

    /**
     * @dev given a DAO's reward info, a given round and the corresponding last active round relative to the round,
     * calculate reward of the round
     * @param daoId DAO id
     * @param round a specific round
     * @return rewardAmount reward amount of the round
     */
    function getRoundReward(bytes32 daoId, uint256 round) public view virtual returns (uint256 rewardAmount);

    function _updateRewardRoundAndIssue(
        RewardStorage.RewardInfo storage rewardInfo,
        bytes32 daoId,
        address token,
        uint256 currentRound
    )
        internal
    {
        uint256[] storage activeRounds =
            rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1].activeRounds;

        // new checkpoint
        if (activeRounds.length == 0) {
            // has at least one old checkpoint
            if (rewardInfo.rewardCheckpoints.length > 1) {
                // last checkpoint's active rounds
                uint256[] storage activeRoundsOfLastCheckpoint =
                    rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 2].activeRounds;
                if (activeRoundsOfLastCheckpoint[activeRoundsOfLastCheckpoint.length - 1] != currentRound) {
                    _issueLastRoundReward(rewardInfo, daoId, token);
                }
            }
        }
        // not new checkpoint
        else {
            if (activeRounds[activeRounds.length - 1] != currentRound) {
                // rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1].lastActiveRound =
                //     activeRounds[activeRounds.length - 1];
                _issueLastRoundReward(rewardInfo, daoId, token);
            }
        }
    }

    /**
     * @dev given a round, get the index of the corresponding reward checkpoint
     * @param rewardCheckpoints reward checkpoints of a DAO
     * @param round a specific round
     * @return index index of the corresponding reward checkpoint
     */
    function _getRewardCheckpointIndexByRound(
        RewardStorage.RewardCheckpoint[] storage rewardCheckpoints,
        uint256 round
    )
        internal
        view
        returns (uint256 index)
    {
        if (round < rewardCheckpoints[0].startRound) revert InvalidRound();

        uint256 length = rewardCheckpoints.length;
        for (uint256 i; i < length - 1;) {
            if (rewardCheckpoints[i + 1].startRound > round) return i;
            unchecked {
                ++i;
            }
        }
        return length - 1;
    }

    function _getLastActiveRound(
        RewardStorage.RewardInfo storage rewardInfo,
        uint256 round
    )
        internal
        view
        returns (uint256)
    {
        for (uint256 i = rewardInfo.rewardCheckpoints.length - 1; ~i != 0;) {
            uint256[] storage activeRounds = rewardInfo.rewardCheckpoints[i].activeRounds;
            if (activeRounds.length > 0) {
                for (uint256 j = activeRounds.length - 1; ~j != 0;) {
                    if (activeRounds[j] < round) return activeRounds[j];
                    unchecked {
                        --j;
                    }
                }
            }
            unchecked {
                --i;
            }
        }
        return 0;
    }

    /**
     * @dev Since this method is called when `_updateRewardRoundAndIssue` is called, which is called everytime when
     * `mint` or `claim reward`, we can assure that only one pending round reward is issued at a time
     */
    function _issueLastRoundReward(
        RewardStorage.RewardInfo storage rewardInfo,
        bytes32 daoId,
        address token
    )
        internal
    {
        // get reward of the pending round
        if (rewardInfo.rewardIssuePendingRound != 0) {
            uint256 roundReward = getRoundReward(daoId, rewardInfo.rewardIssuePendingRound);
            rewardInfo.rewardIssuePendingRound = 0;
            D4AERC20(token).mint(address(this), roundReward);
        }
    }
}

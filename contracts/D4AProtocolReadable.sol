// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { BASIS_POINT, BASIC_DAO_RESERVE_NFT_NUMBER } from "contracts/interface/D4AConstants.sol";
import { DaoTag } from "contracts/interface/D4AEnums.sol";
import { DaoStorage } from "contracts/storages/DaoStorage.sol";
import { BasicDaoStorage } from "contracts/storages/BasicDaoStorage.sol";
import { CanvasStorage } from "contracts/storages/CanvasStorage.sol";
import { PriceStorage } from "contracts/storages/PriceStorage.sol";
import { RewardStorage } from "./storages/RewardStorage.sol";
import { SettingsStorage } from "./storages/SettingsStorage.sol";
import { RoundStorage } from "contracts/storages/RoundStorage.sol";
import { ID4AProtocolReadable } from "contracts/interface/ID4AProtocolReadable.sol";
import { IPriceTemplate } from "contracts/interface/IPriceTemplate.sol";
import { IRewardTemplate } from "contracts/interface/IRewardTemplate.sol";

import { IPDRound } from "contracts/interface/IPDRound.sol";

contract D4AProtocolReadable is ID4AProtocolReadable {
    // legacy functions
    function getProjectCanvasAt(bytes32 daoId, uint256 index) public view returns (bytes32) {
        return DaoStorage.layout().daoInfos[daoId].canvases[index];
    }

    function getProjectInfo(bytes32 daoId)
        public
        view
        returns (
            uint256 startBlock,
            uint256 mintableRound,
            uint256 nftMaxSupply,
            address daoFeePool,
            uint96 royaltyFeeRatioInBps,
            uint256 daoIndex,
            string memory daoUri,
            uint256 tokenMaxSupply
        )
    {
        DaoStorage.DaoInfo storage pi = DaoStorage.layout().daoInfos[daoId];
        startBlock = pi.startBlock;
        mintableRound = pi.mintableRound;
        nftMaxSupply = pi.nftMaxSupply;
        daoFeePool = pi.daoFeePool;
        royaltyFeeRatioInBps = pi.royaltyFeeRatioInBps;
        daoIndex = pi.daoIndex;
        daoUri = pi.daoUri;
        tokenMaxSupply = pi.tokenMaxSupply;
    }

    function getProjectFloorPrice(bytes32 daoId) public view returns (uint256) {
        return PriceStorage.layout().daoFloorPrices[daoId];
    }

    function getProjectTokens(bytes32 daoId) public view returns (address token, address nft) {
        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        token = daoInfo.token;
        nft = daoInfo.nft;
    }

    function getCanvasNFTCount(bytes32 canvasId) public view returns (uint256) {
        return CanvasStorage.layout().canvasInfos[canvasId].tokenIds.length;
    }

    function getTokenIDAt(bytes32 canvasId, uint256 index) public view returns (uint256) {
        return CanvasStorage.layout().canvasInfos[canvasId].tokenIds[index];
    }

    function getCanvasProject(bytes32 canvasId) public view returns (bytes32) {
        return CanvasStorage.layout().canvasInfos[canvasId].daoId;
    }

    function getCanvasURI(bytes32 canvasId) public view returns (string memory) {
        return CanvasStorage.layout().canvasInfos[canvasId].canvasUri;
    }

    function getProjectCanvasCount(bytes32 daoId) public view returns (uint256) {
        return DaoStorage.layout().daoInfos[daoId].canvases.length;
    }

    // new functions
    // DAO related functions
    function getDaoStartBlock(bytes32 daoId) external view returns (uint256 startBlock) {
        return DaoStorage.layout().daoInfos[daoId].startBlock;
    }

    function getDaoMintableRound(bytes32 daoId) external view returns (uint256 mintableRound) {
        return DaoStorage.layout().daoInfos[daoId].mintableRound;
    }

    function getDaoIndex(bytes32 daoId) external view returns (uint256 index) {
        return DaoStorage.layout().daoInfos[daoId].daoIndex;
    }

    function getDaoUri(bytes32 daoId) external view returns (string memory daoUri) {
        return DaoStorage.layout().daoInfos[daoId].daoUri;
    }

    function getDaoFeePool(bytes32 daoId) external view returns (address daoFeePool) {
        //daofeepool = redeem pool;
        return DaoStorage.layout().daoInfos[daoId].daoFeePool;
    }

    function getDaoToken(bytes32 daoId) external view returns (address token) {
        return DaoStorage.layout().daoInfos[daoId].token;
    }

    function getDaoTokenMaxSupply(bytes32 daoId) external view returns (uint256 tokenMaxSupply) {
        return DaoStorage.layout().daoInfos[daoId].tokenMaxSupply;
    }

    function getDaoNft(bytes32 daoId) external view returns (address nft) {
        return DaoStorage.layout().daoInfos[daoId].nft;
    }

    function getDaoNftMaxSupply(bytes32 daoId) external view returns (uint256 nftMaxSupply) {
        return DaoStorage.layout().daoInfos[daoId].nftMaxSupply;
    }

    function getDaoNftTotalSupply(bytes32 daoId) external view returns (uint256 nftTotalSupply) {
        return DaoStorage.layout().daoInfos[daoId].nftTotalSupply;
    }

    function getDaoNftRoyaltyFeeRatioInBps(bytes32 daoId) external view returns (uint96 royaltyFeeRatioInBps) {
        return DaoStorage.layout().daoInfos[daoId].royaltyFeeRatioInBps;
    }

    function getDaoExist(bytes32 daoId) external view returns (bool exist) {
        return DaoStorage.layout().daoInfos[daoId].daoExist;
    }

    function getDaoCanvases(bytes32 daoId) external view returns (bytes32[] memory canvases) {
        return DaoStorage.layout().daoInfos[daoId].canvases;
    }

    function getDaoPriceTemplate(bytes32 daoId) external view returns (address priceTemplate) {
        return SettingsStorage.layout().priceTemplates[uint8(DaoStorage.layout().daoInfos[daoId].priceTemplateType)];
    }

    function getDaoPriceFactor(bytes32 daoId) external view returns (uint256 priceFactor) {
        return DaoStorage.layout().daoInfos[daoId].nftPriceFactor;
    }

    function getDaoRewardTemplate(bytes32 daoId) external view returns (address rewardTemplate) {
        return SettingsStorage.layout().rewardTemplates[uint8(DaoStorage.layout().daoInfos[daoId].rewardTemplateType)];
    }

    function getDaoMintCap(bytes32 daoId) public view returns (uint32) {
        return DaoStorage.layout().daoInfos[daoId].daoMintInfo.daoMintCap;
    }

    function getDaoNftHolderMintCap(bytes32 daoId) public view returns (uint32) {
        return DaoStorage.layout().daoInfos[daoId].daoMintInfo.NFTHolderMintCap;
    }

    function getUserMintInfo(bytes32 daoId, address account) public view returns (uint32 minted, uint32 userMintCap) {
        minted = DaoStorage.layout().daoInfos[daoId].daoMintInfo.userMintInfos[account].minted;
        userMintCap = DaoStorage.layout().daoInfos[daoId].daoMintInfo.userMintInfos[account].mintCap;
    }

    function getDaoTag(bytes32 daoId) public view returns (string memory) {
        DaoTag tag = DaoStorage.layout().daoInfos[daoId].daoTag;
        if (tag == DaoTag.D4A_DAO) return "D4A DAO";
        else if (tag == DaoTag.BASIC_DAO) return "BASIC DAO";
        else return "";
    }

    // canvas related functions
    function getCanvasDaoId(bytes32 canvasId) external view returns (bytes32 daoId) {
        return CanvasStorage.layout().canvasInfos[canvasId].daoId;
    }

    function getCanvasTokenIds(bytes32 canvasId) external view returns (uint256[] memory tokenIds) {
        return CanvasStorage.layout().canvasInfos[canvasId].tokenIds;
    }

    function getCanvasIndex(bytes32 canvasId) public view returns (uint256) {
        return CanvasStorage.layout().canvasInfos[canvasId].index;
    }

    function getCanvasUri(bytes32 canvasId) external view returns (string memory canvasUri) {
        return CanvasStorage.layout().canvasInfos[canvasId].canvasUri;
    }

    function getCanvasRebateRatioInBps(bytes32 canvasId) public view returns (uint256) {
        return CanvasStorage.layout().canvasInfos[canvasId].canvasRebateRatioInBps;
    }

    function getCanvasExist(bytes32 canvasId) external view returns (bool exist) {
        return CanvasStorage.layout().canvasInfos[canvasId].canvasExist;
    }

    // prices related functions
    function getCanvasLastPrice(bytes32 canvasId) public view returns (uint256 round, uint256 price) {
        PriceStorage.MintInfo storage mintInfo = PriceStorage.layout().canvasLastMintInfos[canvasId];
        return (mintInfo.round, mintInfo.price);
    }

    function getCanvasNextPrice(bytes32 canvasId) public view returns (uint256) {
        bytes32 daoId = CanvasStorage.layout().canvasInfos[canvasId].daoId;
        uint256 daoFloorPrice = PriceStorage.layout().daoFloorPrices[daoId];
        PriceStorage.MintInfo memory maxPrice = PriceStorage.layout().daoMaxPrices[daoId];
        PriceStorage.MintInfo memory mintInfo = PriceStorage.layout().canvasLastMintInfos[canvasId];
        DaoStorage.DaoInfo storage pi = DaoStorage.layout().daoInfos[daoId];
        SettingsStorage.Layout storage settingsStorage = SettingsStorage.layout();
        return IPriceTemplate(
            settingsStorage.priceTemplates[uint8(DaoStorage.layout().daoInfos[daoId].priceTemplateType)]
        ).getCanvasNextPrice(
            RoundStorage.layout().roundInfos[daoId].lastRestartRoundMinusOne + 1,
            IPDRound(address(this)).getDaoCurrentRound(daoId),
            pi.nftPriceFactor,
            daoFloorPrice,
            maxPrice,
            mintInfo
        );
    }

    function getDaoMaxPriceInfo(bytes32 daoId) external view returns (uint256 round, uint256 price) {
        PriceStorage.MintInfo memory maxPrice = PriceStorage.layout().daoMaxPrices[daoId];
        return (maxPrice.round, maxPrice.price);
    }

    function getDaoFloorPrice(bytes32 daoId) external view returns (uint256 floorPrice) {
        return PriceStorage.layout().daoFloorPrices[daoId];
    }

    // reward related functions
    // function getDaoRewardStartRound(
    //     bytes32 daoId,
    //     uint256 rewardCheckpointIndex
    // )
    //     external
    //     view
    //     returns (uint256 startRound)
    // {
    //     return RewardStorage.layout().rewardInfos[daoId].rewardCheckpoints[rewardCheckpointIndex].startRound;
    // }

    // function getDaoRewardTotalRound(
    //     bytes32 daoId,
    //     uint256 rewardCheckpointIndex
    // )
    //     external
    //     view
    //     returns (uint256 totalRound)
    // {
    //     return RewardStorage.layout().rewardInfos[daoId].rewardCheckpoints[rewardCheckpointIndex].totalRound;
    // }

    // function getDaoTotalReward(
    //     bytes32 daoId,
    //     uint256 rewardCheckpointIndex
    // )
    //     external
    //     view
    //     returns (uint256 totalReward)
    // {
    //     return RewardStorage.layout().rewardInfos[daoId].rewardCheckpoints[rewardCheckpointIndex].totalReward;
    // }

    // function getDaoRewardDecayFactor(bytes32 daoId) external view returns (uint256 rewardDecayFactor) {
    //     return RewardStorage.layout().rewardInfos[daoId].rewardDecayFactor;
    // }

    function getDaoIsProgressiveJackpot(bytes32 daoId) external view returns (bool isProgressiveJackpot) {
        return RewardStorage.layout().rewardInfos[daoId].isProgressiveJackpot;
    }

    // function getDaoRewardLastActiveRound(
    //     bytes32 daoId,
    //     uint256 rewardCheckpointIndex
    // )
    //     external
    //     view
    //     returns (uint256 lastActiveRound)
    // {
    //     return RewardStorage.layout().rewardInfos[daoId].rewardCheckpoints[rewardCheckpointIndex].lastActiveRound;
    // }

    function getDaoActiveRounds(bytes32 daoId) external view returns (uint256[] memory activeRounds) {
        return RewardStorage.layout().rewardInfos[daoId].activeRounds;
    }

    function getDaoCreatorClaimableRound(bytes32 daoId) external view returns (uint256 claimableRound) {
        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];
        return rewardInfo.activeRounds[rewardInfo.daoCreatorClaimableRoundIndex];
    }

    function getCanvasCreatorClaimableRound(
        bytes32 daoId,
        bytes32 canvasId
    )
        external
        view
        returns (uint256 claimableRound)
    {
        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];
        return rewardInfo.activeRounds[rewardInfo.canvasCreatorClaimableRoundIndexes[canvasId]];
    }

    function getNftMinterClaimableRound(
        bytes32 daoId,
        address nftMinter
    )
        external
        view
        returns (uint256 claimableRound)
    {
        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];
        return rewardInfo.activeRounds[rewardInfo.nftMinterClaimableRoundIndexes[nftMinter]];
    }

    function getTotalWeight(bytes32 daoId, uint256 round) external view returns (uint256 totalWeight) {
        return RewardStorage.layout().rewardInfos[daoId].totalWeights[round];
    }

    function getProtocolWeights(
        bytes32 daoId,
        uint256 round
    )
        external
        view
        returns (uint256 protocolWeight, uint256 protocolWeightETH)
    {
        return (
            RewardStorage.layout().rewardInfos[daoId].protocolOutputWeight[round],
            RewardStorage.layout().rewardInfos[daoId].protocolInputWeight[round]
        );
    }

    function getDaoCreatorWeights(
        bytes32 daoId,
        uint256 round
    )
        external
        view
        returns (uint256 creatorWeight, uint256 creatorWeightETH)
    {
        return (
            RewardStorage.layout().rewardInfos[daoId].daoCreatorOutputWeights[round],
            RewardStorage.layout().rewardInfos[daoId].daoCreatorInputWeights[round]
        );
    }

    function getCanvasCreatorWeights(
        bytes32 daoId,
        uint256 round,
        bytes32 canvasId
    )
        external
        view
        returns (uint256 creatorWeight, uint256 creatorWeightETH)
    {
        return (
            RewardStorage.layout().rewardInfos[daoId].canvasCreatorOutputWeights[round][canvasId],
            RewardStorage.layout().rewardInfos[daoId].canvasCreatorInputWeights[round][canvasId]
        );
    }

    function getNftMinterWeights(
        bytes32 daoId,
        uint256 round,
        address nftMinter
    )
        external
        view
        returns (uint256 minterWeight, uint256 minterWeightETH)
    {
        return (
            RewardStorage.layout().rewardInfos[daoId].nftMinterOutputWeights[round][nftMinter],
            RewardStorage.layout().rewardInfos[daoId].nftMinterInputWeights[round][nftMinter]
        );
    }

    function getDaoRoundMintCap(bytes32 daoId) public view returns (uint256) {
        BasicDaoStorage.Layout storage basicDaoStorage = BasicDaoStorage.layout();
        return basicDaoStorage.basicDaoInfos[daoId].roundMintCap;
    }

    function getDaoUnifiedPriceModeOff(bytes32 daoId) public view returns (bool) {
        BasicDaoStorage.Layout storage basicDaoStorage = BasicDaoStorage.layout();
        return basicDaoStorage.basicDaoInfos[daoId].unifiedPriceModeOff;
    }

    //9999 = 0, 0 = 0.01,
    function getDaoUnifiedPrice(bytes32 daoId) public view returns (uint256) {
        BasicDaoStorage.BasicDaoInfo storage basicDaoInfo = BasicDaoStorage.layout().basicDaoInfos[daoId];
        // if (basicDaoInfo.unifiedPrice == 9999 ether) {
        //     return 0;
        // } else {
        return basicDaoInfo.unifiedPrice;
    }

    function getDaoReserveNftNumber(bytes32 daoId) public view returns (uint256) {
        BasicDaoStorage.BasicDaoInfo storage basicDaoInfo = BasicDaoStorage.layout().basicDaoInfos[daoId];
        return basicDaoInfo.reserveNftNumber == 0 ? BASIC_DAO_RESERVE_NFT_NUMBER : basicDaoInfo.reserveNftNumber;
    }

    // function _getRoundReward(bytes32 daoId, uint256 round) internal returns (uint256) {
    //     address rewardTemplate =
    //         SettingsStorage.layout().rewardTemplates[uint8(DaoStorage.layout().daoInfos[daoId].rewardTemplateType)];

    //     (bool succ, bytes memory data) =
    //         rewardTemplate.delegatecall(abi.encodeWithSelector(IRewardTemplate.getRoundReward.selector, daoId,
    // round));
    //     if (!succ) {
    //         /// @solidity memory-safe-assembly
    //         assembly {
    //             returndatacopy(0, 0, returndatasize())
    //             revert(0, returndatasize())
    //         }
    //     }
    //     return abi.decode(data, (uint256));
    // }

    function _castGetRoundRewardToView(function(bytes32, uint256) internal returns (uint256) fnIn)
        internal
        pure
        returns (function(bytes32, uint256) internal view returns (uint256) fnOut)
    {
        assembly {
            fnOut := fnIn
        }
    }
}

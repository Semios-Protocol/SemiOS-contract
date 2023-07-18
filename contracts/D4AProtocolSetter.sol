// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { FixedPointMathLib as Math } from "solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { BASIS_POINT } from "contracts/interface/D4AConstants.sol";
import { UserMintCapParam, TemplateParam, DaoMintInfo, Whitelist, Blacklist } from "contracts/interface/D4AStructs.sol";
import { PriceTemplateType } from "contracts/interface/D4AEnums.sol";
import "contracts/interface/D4AErrors.sol";
import { DaoStorage } from "contracts/storages/DaoStorage.sol";
import { CanvasStorage } from "contracts/storages/CanvasStorage.sol";
import { PriceStorage } from "contracts/storages/PriceStorage.sol";
import { RewardStorage } from "./storages/RewardStorage.sol";
import { SettingsStorage } from "./storages/SettingsStorage.sol";
import { ID4AProtocolSetter } from "contracts/interface/ID4AProtocolSetter.sol";
import { IPermissionControl } from "contracts/interface/IPermissionControl.sol";
import { IRewardTemplate } from "contracts/interface/IRewardTemplate.sol";
import { D4AProtocolReadable } from "contracts/D4AProtocolReadable.sol";

contract D4AProtocolSetter is ID4AProtocolSetter {
    function setMintCapAndPermission(
        bytes32 daoId,
        uint32 daoMintCap,
        UserMintCapParam[] calldata userMintCapParams,
        Whitelist memory whitelist,
        Blacklist memory blacklist,
        Blacklist memory unblacklist
    )
        public
    {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.createProjectProxy && msg.sender != l.ownerProxy.ownerOf(daoId)) {
            revert NotDaoOwner();
        }
        DaoMintInfo storage daoMintInfo = DaoStorage.layout().daoInfos[daoId].daoMintInfo;
        daoMintInfo.daoMintCap = daoMintCap;
        uint256 length = userMintCapParams.length;
        for (uint256 i = 0; i < length;) {
            daoMintInfo.userMintInfos[userMintCapParams[i].minter].mintCap = userMintCapParams[i].mintCap;
            unchecked {
                ++i;
            }
        }

        emit MintCapSet(daoId, daoMintCap, userMintCapParams);

        l.permissionControl.modifyPermission(daoId, whitelist, blacklist, unblacklist);
    }

    function setDaoParams(
        bytes32 daoId,
        uint256 nftMaxSupplyRank,
        uint256 mintableRoundRank,
        uint256 daoFloorPriceRank,
        PriceTemplateType priceTemplateType,
        uint256 nftPriceFactor,
        uint256 daoCreatorERC20Ratio,
        uint256 canvasCreatorERC20Ratio,
        uint256 nftMinterERC20Ratio,
        uint256 daoFeePoolETHRatio,
        uint256 daoFeePoolETHRatioFlatPrice
    )
        public
    {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.ownerProxy.ownerOf(daoId)) revert NotDaoOwner();

        setDaoNftMaxSupply(daoId, l.nftMaxSupplies[nftMaxSupplyRank]);
        setDaoMintableRound(daoId, l.mintableRounds[mintableRoundRank]);
        setDaoFloorPrice(daoId, daoFloorPriceRank == 9999 ? 0 : l.daoFloorPrices[daoFloorPriceRank]);
        setDaoPriceTemplate(daoId, priceTemplateType, nftPriceFactor);
        setRatio(
            daoId,
            daoCreatorERC20Ratio,
            canvasCreatorERC20Ratio,
            nftMinterERC20Ratio,
            daoFeePoolETHRatio,
            daoFeePoolETHRatioFlatPrice
        );
    }

    function setDaoNftMaxSupply(bytes32 daoId, uint256 newMaxSupply) public {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.ownerProxy.ownerOf(daoId)) revert NotDaoOwner();

        DaoStorage.layout().daoInfos[daoId].nftMaxSupply = newMaxSupply;

        emit DaoNftMaxSupplySet(daoId, newMaxSupply);
    }

    function setDaoMintableRound(bytes32 daoId, uint256 newMintableRound) public {
        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        if (daoInfo.mintableRound == newMintableRound) return;

        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.ownerProxy.ownerOf(daoId)) revert NotDaoOwner();

        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];
        RewardStorage.RewardCheckpoint storage rewardCheckpoint =
            rewardInfo.rewardCheckpoints[rewardInfo.rewardCheckpoints.length - 1];
        uint256 currentRound = l.drb.currentRound();
        uint256 oldMintableRound = daoInfo.mintableRound;
        int256 mintableRoundDelta = SafeCastLib.toInt256(newMintableRound) - SafeCastLib.toInt256(oldMintableRound);
        if (
            currentRound >= rewardCheckpoint.startRound + rewardCheckpoint.totalRound
                || SafeCastLib.toInt256(rewardCheckpoint.startRound + rewardCheckpoint.totalRound) + mintableRoundDelta
                    < SafeCastLib.toInt256(currentRound) || newMintableRound > l.maxMintableRound
        ) revert ExceedMaxMintableRound();

        daoInfo.mintableRound = newMintableRound;

        (bool succ,) = l.rewardTemplates[uint8(daoInfo.rewardTemplateType)].delegatecall(
            abi.encodeWithSelector(IRewardTemplate.setRewardCheckpoint.selector, daoId, mintableRoundDelta)
        );
        require(succ);

        emit DaoMintableRoundSet(daoId, newMintableRound);
    }

    function setDaoFloorPrice(bytes32 daoId, uint256 newFloorPrice) public {
        PriceStorage.Layout storage priceStorage = PriceStorage.layout();
        if (priceStorage.daoFloorPrices[daoId] == newFloorPrice) return;

        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.ownerProxy.ownerOf(daoId)) revert NotDaoOwner();

        bytes32[] memory canvases = DaoStorage.layout().daoInfos[daoId].canvases;
        uint256 length = canvases.length;
        for (uint256 i; i < length;) {
            uint256 canvasNextPrice = D4AProtocolReadable(address(this)).getCanvasNextPrice(canvases[i]);
            if (canvasNextPrice >= newFloorPrice) {
                priceStorage.canvasLastMintInfos[canvases[i]] =
                    PriceStorage.MintInfo({ round: l.drb.currentRound(), price: canvasNextPrice / 2 });
            }
            unchecked {
                ++i;
            }
        }

        priceStorage.daoMaxPrices[daoId] = PriceStorage.MintInfo({ round: l.drb.currentRound(), price: newFloorPrice });
        priceStorage.daoFloorPrices[daoId] = newFloorPrice;

        emit DaoFloorPriceSet(daoId, newFloorPrice);
    }

    function setDaoPriceTemplate(bytes32 daoId, PriceTemplateType priceTemplateType, uint256 nftPriceFactor) public {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.ownerProxy.ownerOf(daoId)) revert NotDaoOwner();

        if (priceTemplateType == PriceTemplateType.EXPONENTIAL_PRICE_VARIATION) require(nftPriceFactor >= 10_000);

        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        daoInfo.priceTemplateType = priceTemplateType;
        daoInfo.nftPriceFactor = nftPriceFactor;

        emit DaoPriceTemplateSet(daoId, priceTemplateType, nftPriceFactor);
    }

    function setTemplate(bytes32 daoId, TemplateParam calldata templateParam) public {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.ownerProxy.ownerOf(daoId) && msg.sender != l.createProjectProxy) revert NotDaoOwner();

        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        daoInfo.priceTemplateType = templateParam.priceTemplateType;
        daoInfo.nftPriceFactor = templateParam.priceFactor;
        daoInfo.rewardTemplateType = templateParam.rewardTemplateType;

        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];
        rewardInfo.rewardDecayFactor = templateParam.rewardDecayFactor;
        rewardInfo.isProgressiveJackpot = templateParam.isProgressiveJackpot;

        (bool succ,) = l.rewardTemplates[uint8(daoInfo.rewardTemplateType)].delegatecall(
            abi.encodeWithSelector(IRewardTemplate.setRewardCheckpoint.selector, daoId, 0)
        );
        require(succ);

        emit DaoTemplateSet(daoId, templateParam);
    }

    function setRatio(
        bytes32 daoId,
        uint256 daoCreatorERC20Ratio,
        uint256 canvasCreatorERC20Ratio,
        uint256 nftMinterERC20Ratio,
        uint256 daoFeePoolETHRatio,
        uint256 daoFeePoolETHRatioFlatPrice
    )
        public
    {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.ownerProxy.ownerOf(daoId) && msg.sender != l.createProjectProxy) revert NotDaoOwner();

        if (
            daoFeePoolETHRatioFlatPrice > BASIS_POINT - l.protocolMintFeeRatioInBps
                || daoFeePoolETHRatio > daoFeePoolETHRatioFlatPrice
        ) revert InvalidETHRatio();

        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];
        uint256 sum = daoCreatorERC20Ratio + canvasCreatorERC20Ratio + nftMinterERC20Ratio;
        uint256 daoCreatorERC20RatioInBps = Math.fullMulDivUp(daoCreatorERC20Ratio, BASIS_POINT, sum);
        uint256 canvasCreatorERC20RatioInBps = Math.fullMulDivUp(canvasCreatorERC20Ratio, BASIS_POINT, sum);
        rewardInfo.daoCreatorERC20RatioInBps = daoCreatorERC20RatioInBps;
        rewardInfo.canvasCreatorERC20RatioInBps = canvasCreatorERC20RatioInBps;

        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        daoInfo.daoFeePoolETHRatioInBps = daoFeePoolETHRatio;
        daoInfo.daoFeePoolETHRatioInBpsFlatPrice = daoFeePoolETHRatioFlatPrice;

        emit DaoRatioSet(
            daoId,
            daoCreatorERC20Ratio,
            canvasCreatorERC20Ratio,
            nftMinterERC20Ratio,
            daoFeePoolETHRatio,
            daoFeePoolETHRatioFlatPrice
        );
    }

    function setCanvasRebateRatioInBps(bytes32 canvasId, uint256 newCanvasRebateRatioInBps) public payable {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (msg.sender != l.ownerProxy.ownerOf(canvasId)) revert NotCanvasOwner();

        require(newCanvasRebateRatioInBps <= 10_000);
        CanvasStorage.layout().canvasInfos[canvasId].canvasRebateRatioInBps = newCanvasRebateRatioInBps;

        emit CanvasRebateRatioInBpsSet(canvasId, newCanvasRebateRatioInBps);
    }
}

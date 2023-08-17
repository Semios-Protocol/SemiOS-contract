// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// external deps
import { ReentrancyGuard } from "@solidstate/contracts/security/reentrancy_guard/ReentrancyGuard.sol";
import { LibString } from "solady/utils/LibString.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

// D4A constants, structs, enums && errors
import { BASIS_POINT } from "contracts/interface/D4AConstants.sol";
import { DaoMetadataParam, BasicDaoParam } from "contracts/interface/D4AStructs.sol";
import { DaoTag } from "contracts/interface/D4AEnums.sol";
import "contracts/interface/D4AErrors.sol";

// interfaces
import { ID4AProtocolSetter } from "./interface/ID4AProtocolSetter.sol";
import { IPDCreate } from "./interface/IPDCreate.sol";
import { ID4AChangeAdmin } from "./interface/ID4AChangeAdmin.sol";

// D4A storages && contracts
import { ProtocolStorage } from "contracts/storages/ProtocolStorage.sol";
import { DaoStorage } from "contracts/storages/DaoStorage.sol";
import { CanvasStorage } from "contracts/storages/CanvasStorage.sol";
import { PriceStorage } from "contracts/storages/PriceStorage.sol";
import { SettingsStorage } from "./storages/SettingsStorage.sol";
import { BasicDaoStorage } from "contracts/storages/BasicDaoStorage.sol";
import { D4AERC20 } from "./D4AERC20.sol";
import { D4AERC721 } from "./D4AERC721.sol";
import { D4AFeePool } from "./feepool/D4AFeePool.sol";
import { ProtocolChecker } from "contracts/ProtocolChecker.sol";

contract PDCreate is IPDCreate, ProtocolChecker, ReentrancyGuard {
    function createBasicDao(
        DaoMetadataParam memory daoMetadataParam,
        BasicDaoParam memory basicDaoParam
    )
        public
        payable
        nonReentrant
        returns (bytes32 daoId)
    {
        _checkPauseStatus();
        _checkUriNotExist(daoMetadataParam.projectUri);
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        _checkCaller(l.createProjectProxy);
        ProtocolStorage.layout().uriExists[keccak256(abi.encodePacked(daoMetadataParam.projectUri))] = true;
        daoId = _createProject(
            daoMetadataParam.startDrb,
            daoMetadataParam.mintableRounds,
            daoMetadataParam.floorPriceRank,
            daoMetadataParam.maxNftRank,
            daoMetadataParam.royaltyFee,
            ProtocolStorage.layout().daoIndex,
            daoMetadataParam.projectUri,
            basicDaoParam.initTokenSupplyRatio,
            basicDaoParam.daoName
        );
        ProtocolStorage.layout().daoIndex++;

        DaoStorage.layout().daoInfos[daoId].daoMintInfo.NFTHolderMintCap = 5;
        DaoStorage.layout().daoInfos[daoId].daoTag = DaoTag.BASIC_DAO;

        ProtocolStorage.layout().uriExists[keccak256(abi.encodePacked(basicDaoParam.canvasUri))] = true;

        _createCanvas(
            CanvasStorage.layout().canvasInfos,
            daoId,
            basicDaoParam.canvasId,
            DaoStorage.layout().daoInfos[daoId].startRound,
            DaoStorage.layout().daoInfos[daoId].canvases.length,
            basicDaoParam.canvasUri,
            msg.sender
        );

        DaoStorage.layout().daoInfos[daoId].canvases.push(basicDaoParam.canvasId);
        BasicDaoStorage.layout().basicDaoInfos[daoId].canvasIdOfSpecialNft = basicDaoParam.canvasId;
    }

    function createCanvas(
        bytes32 daoId,
        bytes32 canvasId,
        string calldata canvasUri,
        bytes32[] calldata proof,
        uint256 canvasRebateRatioInBps,
        address to
    )
        external
        payable
        nonReentrant
    {
        _checkPauseStatus();
        _checkDaoExist(daoId);
        _checkPauseStatus(daoId);
        _checkUriNotExist(canvasUri);

        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (l.permissionControl.isCanvasCreatorBlacklisted(daoId, to)) revert Blacklisted();
        if (!l.permissionControl.inCanvasCreatorWhitelist(daoId, to, proof)) {
            revert NotInWhitelist();
        }

        ProtocolStorage.layout().uriExists[keccak256(abi.encodePacked(canvasUri))] = true;

        _createCanvas(
            CanvasStorage.layout().canvasInfos,
            daoId,
            canvasId,
            DaoStorage.layout().daoInfos[daoId].startRound,
            DaoStorage.layout().daoInfos[daoId].canvases.length,
            canvasUri,
            to
        );

        DaoStorage.layout().daoInfos[daoId].canvases.push(canvasId);

        (bool succ,) = address(this).delegatecall(
            abi.encodeWithSelector(
                ID4AProtocolSetter.setCanvasRebateRatioInBps.selector, canvasId, canvasRebateRatioInBps
            )
        );
        require(succ);
    }

    function _createProject(
        uint256 startRound,
        uint256 mintableRound,
        uint256 daoFloorPriceRank,
        uint256 nftMaxSupplyRank,
        uint96 royaltyFeeRatioInBps,
        uint256 daoIndex,
        string memory daoUri,
        uint256 initTokenSupplyRatio,
        string memory daoName
    )
        internal
        returns (bytes32 daoId)
    {
        SettingsStorage.Layout storage l = SettingsStorage.layout();

        if (mintableRound > l.maxMintableRound) revert ExceedMaxMintableRound();
        {
            uint256 protocolRoyaltyFeeRatioInBps = l.protocolRoyaltyFeeRatioInBps;
            if (
                royaltyFeeRatioInBps < l.minRoyaltyFeeRatioInBps + protocolRoyaltyFeeRatioInBps
                    || royaltyFeeRatioInBps > l.maxRoyaltyFeeRatioInBps + protocolRoyaltyFeeRatioInBps
            ) revert RoyaltyFeeRatioOutOfRange();
        }
        {
            uint256 createDaoFeeAmount = l.createDaoFeeAmount;
            if (msg.value < createDaoFeeAmount) revert NotEnoughEther();

            SafeTransferLib.safeTransferETH(l.protocolFeePool, createDaoFeeAmount);
            uint256 exchange = msg.value - createDaoFeeAmount;
            if (exchange > 0) SafeTransferLib.safeTransferETH(msg.sender, exchange);
        }

        daoId = keccak256(abi.encodePacked(block.number, msg.sender, msg.data, tx.origin));
        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];

        if (daoInfo.daoExist) revert D4AProjectAlreadyExist(daoId);
        {
            if (startRound < l.drb.currentRound()) revert StartRoundAlreadyPassed();
            daoInfo.startRound = startRound;
            daoInfo.mintableRound = mintableRound;
            daoInfo.nftMaxSupply = l.nftMaxSupplies[nftMaxSupplyRank];
            daoInfo.daoUri = daoUri;
            daoInfo.royaltyFeeRatioInBps = royaltyFeeRatioInBps;
            daoInfo.daoIndex = daoIndex;
            daoInfo.token = _createERC20Token(daoIndex, daoName);

            D4AERC20(daoInfo.token).grantRole(keccak256("MINTER"), address(this));
            D4AERC20(daoInfo.token).grantRole(keccak256("BURNER"), address(this));

            address daoFeePool = l.feePoolFactory.createD4AFeePool(
                string(abi.encodePacked("Asset Pool for DAO4Art Project ", LibString.toString(daoIndex)))
            );

            D4AFeePool(payable(daoFeePool)).grantRole(keccak256("AUTO_TRANSFER"), address(this));

            ID4AChangeAdmin(daoFeePool).changeAdmin(l.assetOwner);
            ID4AChangeAdmin(daoInfo.token).changeAdmin(l.assetOwner);

            daoInfo.daoFeePool = daoFeePool;

            l.ownerProxy.initOwnerOf(daoId, msg.sender);

            daoInfo.nft = _createERC721Token(daoIndex, daoName);
            D4AERC721(daoInfo.nft).grantRole(keccak256("ROYALTY"), msg.sender);
            D4AERC721(daoInfo.nft).grantRole(keccak256("MINTER"), address(this));

            D4AERC721(daoInfo.nft).setContractUri(daoUri);
            ID4AChangeAdmin(daoInfo.nft).changeAdmin(l.assetOwner);
            ID4AChangeAdmin(daoInfo.nft).transferOwnership(msg.sender);
            //We copy from setting in case setting may change later.
            daoInfo.tokenMaxSupply = (l.tokenMaxSupply * initTokenSupplyRatio) / BASIS_POINT;

            if (daoFloorPriceRank != 9999) {
                // 9999 is specified for 0 floor price
                PriceStorage.layout().daoFloorPrices[daoId] = l.daoFloorPrices[daoFloorPriceRank];
            }

            daoInfo.daoExist = true;
            emit NewProject(daoId, daoUri, daoFeePool, daoInfo.token, daoInfo.nft, royaltyFeeRatioInBps);
        }
    }

    function _createERC20Token(uint256 daoIndex, string memory daoName) internal returns (address) {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        string memory name = daoName;
        string memory sym = string(abi.encodePacked("D4A.T", LibString.toString(daoIndex)));
        return l.erc20Factory.createD4AERC20(name, sym, address(this));
    }

    function _createERC721Token(uint256 daoIndex, string memory daoName) internal returns (address) {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        string memory name = daoName;
        string memory sym = string(abi.encodePacked("D4A.N", LibString.toString(daoIndex)));
        return l.erc721Factory.createD4AERC721(name, sym);
    }

    function _createCanvas(
        mapping(bytes32 => CanvasStorage.CanvasInfo) storage canvasInfos,
        bytes32 daoId,
        bytes32 canvasId,
        uint256 daoStartRound,
        uint256 canvasIndex,
        string memory canvasUri,
        address to
    )
        internal
    {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        {
            uint256 cur_round = l.drb.currentRound();
            if (cur_round < daoStartRound) revert DaoNotStarted();
        }

        if (canvasInfos[canvasId].canvasExist) revert D4ACanvasAlreadyExist(canvasId);

        {
            CanvasStorage.CanvasInfo storage canvasInfo = canvasInfos[canvasId];
            canvasInfo.daoId = daoId;
            canvasInfo.canvasUri = canvasUri;
            canvasInfo.index = canvasIndex + 1;
            l.ownerProxy.initOwnerOf(canvasId, to);
            canvasInfo.canvasExist = true;
        }
        emit NewCanvas(daoId, canvasId, canvasUri);
    }
}
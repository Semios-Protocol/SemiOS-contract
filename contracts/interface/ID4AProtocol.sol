// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { DaoMetadataParam, UserMintCapParam, TemplateParam } from "./D4AStructs.sol";
import { IPermissionControl } from "contracts/interface/IPermissionControl.sol";

interface ID4AProtocol {
    event MintCapSet(bytes32 indexed daoId, uint32 daoMintCap, UserMintCapParam[] userMintCapParams);

    event D4AMintNFT(bytes32 daoId, bytes32 canvasId, uint256 tokenId, string tokenUri, uint256 price);

    event D4AClaimProjectERC20Reward(bytes32 daoId, address token, uint256 amount);

    event D4AClaimCanvasReward(bytes32 daoId, bytes32 canvasId, address token, uint256 amount);

    event D4AClaimNftMinterReward(bytes32 daoId, address token, uint256 amount);

    event D4AExchangeERC20ToETH(bytes32 daoId, address owner, address to, uint256 tokenAmount, uint256 ethAmount);

    event DaoNftPriceMultiplyFactorChanged(bytes32 daoId, uint256 newNftPriceMultiplyFactor);

    event CanvasRebateRatioInBpsSet(bytes32 indexed canvasId, uint256 newCanvasRebateRatioInBps);

    event D4AERC721MaxSupplySet(bytes32 indexed daoId, uint256 newMaxSupply);

    event DaoMintableRoundSet(bytes32 daoId, uint256 newMintableRounds);

    event DaoTemplateSet(bytes32 daoId, TemplateParam templateParam);

    event DaoRatioSet(
        bytes32 daoId,
        uint256 canvasCreatorERC20Ratio,
        uint256 nftMinterERC20Ratio,
        uint256 daoFeePoolETHRatio,
        uint256 daoFeePoolETHRatioFlatPrice
    );

    function createProject(
        uint256 startRound,
        uint256 mintableRound,
        uint256 daoFloorPriceRank,
        uint256 maxNftRank,
        uint96 royaltyFeeInBps,
        string memory daoUri
    )
        external
        payable
        returns (bytes32 daoId);

    function createOwnerProject(DaoMetadataParam calldata daoMetadata) external payable returns (bytes32 daoId);

    function claimProjectERC20Reward(bytes32 daoId) external returns (uint256);

    function claimCanvasReward(bytes32 canvasId) external returns (uint256);

    function claimNftMinterReward(bytes32 daoId, address minter) external returns (uint256);

    function exchangeERC20ToETH(bytes32 daoId, uint256 amount, address to) external returns (uint256);

    function setRatio(
        bytes32 daoId,
        uint256 canvasCreatorERC20Ratio,
        uint256 nftMinterERC20Ratio,
        uint256 daoFeePoolETHRatio,
        uint256 daoFeePoolETHRatioFlatPrice
    )
        external;

    function setTemplate(bytes32 daoId, TemplateParam calldata templateParam) external;

    function setMintCapAndPermission(
        bytes32 daoId,
        uint32 daoMintCap,
        UserMintCapParam[] calldata userMintCapParams,
        IPermissionControl.Whitelist memory whitelist,
        IPermissionControl.Blacklist memory blacklist,
        IPermissionControl.Blacklist memory unblacklist
    )
        external;

    function getProjectCanvasAt(bytes32 daoId, uint256 index) external view returns (bytes32);

    function getProjectInfo(bytes32 daoId)
        external
        view
        returns (
            uint256 startRound,
            uint256 mintableRound,
            uint256 maxNftAmount,
            address daoFeePool,
            uint96 royaltyFeeInBps,
            uint256 index,
            string memory daoUri,
            uint256 erc20TotalSupply
        );

    function getProjectFloorPrice(bytes32 daoId) external view returns (uint256);

    function getProjectTokens(bytes32 daoId) external view returns (address token, address nft);

    function getCanvasNFTCount(bytes32 canvasId) external view returns (uint256);

    function getTokenIDAt(bytes32 canvasId, uint256 index) external view returns (uint256);

    function getCanvasProject(bytes32 canvasId) external view returns (bytes32);

    function getCanvasIndex(bytes32 canvasId) external view returns (uint256);

    function getCanvasURI(bytes32 canvasId) external view returns (string memory);

    function getCanvasLastPrice(bytes32 canvasId) external view returns (uint256 round, uint256 price);

    function getCanvasNextPrice(bytes32 canvasId) external view returns (uint256);

    function getCanvasCreatorERC20Ratio(bytes32 daoId) external view returns (uint256);

    function getNftMinterERC20Ratio(bytes32 daoId) external view returns (uint256);

    function getDaoFeePoolETHRatio(bytes32 daoId) external view returns (uint256);

    function getDaoFeePoolETHRatioFlatPrice(bytes32 daoId) external view returns (uint256);
}

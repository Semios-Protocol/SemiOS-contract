// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {
    DaoMetadataParam,
    BasicDaoParam,
    ContinuousDaoParam,
    Whitelist,
    Blacklist,
    DaoMintCapParam,
    DaoETHAndERC20SplitRatioParam,
    TemplateParam
} from "contracts/interface/D4AStructs.sol";

interface IPDCreateFunding {
    // ============================== Events =============================
    event CreateProjectParamEmitted(
        bytes32 daoId,
        address daoFeePool,
        address token,
        address nft,
        DaoMetadataParam daoMetadataParam,
        Whitelist whitelist,
        Blacklist blacklist,
        DaoMintCapParam daoMintCapParam,
        DaoETHAndERC20SplitRatioParam splitRatioParam,
        TemplateParam templateParam,
        BasicDaoParam basicDaoParam,
        uint256 actionType
    );

    event CreateContinuousProjectParamEmitted(
        bytes32 existDaoId,
        bytes32 daoId,
        uint256 dailyMintCap,
        bool needMintableWork,
        bool unifiedPriceModeOff,
        uint256 unifiedPrice,
        uint256 reserveNftNumber
    );

    // ============================== Write Functions =============================
    function createBasicDao(
        DaoMetadataParam calldata daoMetadataParam,
        Whitelist memory whitelist,
        Blacklist calldata blacklist,
        DaoMintCapParam calldata daoMintCapParam,
        DaoETHAndERC20SplitRatioParam calldata splitRatioParam,
        TemplateParam calldata templateParam,
        BasicDaoParam calldata basicDaoParam,
        uint256 actionType
    )
        external
        payable
        returns (bytes32 daoId);

    function createContinuousDao(
        bytes32 existDaoId,
        DaoMetadataParam calldata daoMetadataParam,
        Whitelist memory whitelist,
        Blacklist calldata blacklist,
        DaoMintCapParam calldata daoMintCapParam,
        DaoETHAndERC20SplitRatioParam calldata splitRatioParam,
        TemplateParam calldata templateParam,
        BasicDaoParam calldata basicDaoParam,
        ContinuousDaoParam calldata continuousDaoParam,
        uint256 actionType
    )
        external
        payable
        returns (bytes32 daoId);
}
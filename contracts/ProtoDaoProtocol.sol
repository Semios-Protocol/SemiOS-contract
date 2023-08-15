// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

// external deps
import { IAccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { LibString } from "solady/utils/LibString.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";

// D4A constants, structs, enums && errors
import { BASIS_POINT, SIGNER_ROLE } from "contracts/interface/D4AConstants.sol";
import {
    DaoMetadataParam,
    TemplateParam,
    UpdateRewardParam,
    UserMintCapParam,
    DaoMintInfo,
    UserMintInfo,
    MintNftInfo,
    Whitelist,
    BasicDaoParam
} from "contracts/interface/D4AStructs.sol";
import "contracts/interface/D4AErrors.sol";

// interfaces
import { IPriceTemplate } from "./interface/IPriceTemplate.sol";
import { IRewardTemplate } from "./interface/IRewardTemplate.sol";
import { IPermissionControl } from "./interface/IPermissionControl.sol";
import { ID4AProtocolReadable } from "./interface/ID4AProtocolReadable.sol";
import { ID4AProtocolSetter } from "./interface/ID4AProtocolSetter.sol";
import { IProtoDaoProtocol } from "./interface/IProtoDaoProtocol.sol";
import { ID4AChangeAdmin } from "./interface/ID4AChangeAdmin.sol";

// D4A storages && contracts
import { DaoStorage } from "contracts/storages/DaoStorage.sol";
import { CanvasStorage } from "contracts/storages/CanvasStorage.sol";
import { PriceStorage } from "contracts/storages/PriceStorage.sol";
import { RewardStorage } from "./storages/RewardStorage.sol";
import { SettingsStorage } from "./storages/SettingsStorage.sol";
import { GrantStorage } from "contracts/storages/GrantStorage.sol";
import { BasicDaoStorage } from "contracts/storages/BasicDaoStorage.sol";
import { D4AERC20 } from "./D4AERC20.sol";
import { D4AERC721 } from "./D4AERC721.sol";
import { D4AFeePool } from "./feepool/D4AFeePool.sol";
import { D4AVestingWallet } from "contracts/feepool/D4AVestingWallet.sol";

contract ProtoDaoProtocol is
    IProtoDaoProtocol,
    Initializable,
    Multicallable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable
{
    bytes32 internal constant _MINTNFT_TYPEHASH =
        keccak256("MintNFT(bytes32 canvasID,bytes32 tokenURIHash,uint256 flatPrice)");

    mapping(bytes32 => bytes32) internal _nftHashToCanvasId;

    mapping(bytes32 => bool) public uriExists;

    uint256 internal _daoIndex;

    uint256 internal _daoIndexBitMap;

    uint256[46] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public reinitializer(2) {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        __ReentrancyGuard_init();
        _daoIndex = l.reservedDaoAmount;
        __EIP712_init("ProtoDaoProtocol", "2");
    }

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
        uriExists[keccak256(abi.encodePacked(daoMetadataParam.projectUri))] = true;
        daoId = _createProject(
            daoMetadataParam.startDrb,
            daoMetadataParam.mintableRounds,
            daoMetadataParam.floorPriceRank,
            daoMetadataParam.maxNftRank,
            daoMetadataParam.royaltyFee,
            _daoIndex,
            daoMetadataParam.projectUri,
            basicDaoParam.initTokenSupplyRatio,
            basicDaoParam.daoName
        );
        _daoIndex++;

        DaoStorage.layout().daoInfos[daoId].daoMintInfo.NFTHolderMintCap = 5;

        uriExists[keccak256(abi.encodePacked(basicDaoParam.canvasUri))] = true;

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

        uriExists[keccak256(abi.encodePacked(canvasUri))] = true;

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

    function mintNFT(
        bytes32 daoId,
        bytes32 canvasId,
        string calldata tokenUri,
        bytes32[] calldata proof,
        uint256 nftFlatPrice,
        bytes calldata signature
    )
        external
        payable
        nonReentrant
        returns (uint256)
    {
        {
            _checkMintEligibility(daoId, msg.sender, proof, 1);
        }
        _verifySignature(daoId, canvasId, tokenUri, nftFlatPrice, signature);
        DaoStorage.layout().daoInfos[daoId].daoMintInfo.userMintInfos[msg.sender].minted += 1;
        return _mintNft(canvasId, tokenUri, nftFlatPrice);
    }

    function batchMint(
        bytes32 daoId,
        bytes32 canvasId,
        bytes32[] calldata proof,
        MintNftInfo[] calldata mintNftInfos,
        bytes[] calldata signatures
    )
        external
        payable
        nonReentrant
        returns (uint256[] memory)
    {
        uint256 length = mintNftInfos.length;
        {
            _checkMintEligibility(daoId, msg.sender, proof, length);
            for (uint256 i; i < length;) {
                _verifySignature(daoId, canvasId, mintNftInfos[i].tokenUri, mintNftInfos[i].flatPrice, signatures[i]);
                unchecked {
                    ++i;
                }
            }
        }
        DaoStorage.layout().daoInfos[daoId].daoMintInfo.userMintInfos[msg.sender].minted += uint32(length);
        return _batchMint(daoId, canvasId, mintNftInfos);
    }

    function claimProjectERC20Reward(bytes32 daoId) public nonReentrant returns (uint256 daoCreatorReward) {
        _checkPauseStatus();
        _checkPauseStatus(daoId);
        _checkDaoExist(daoId);
        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        (bool succ, bytes memory data) = l.rewardTemplates[uint8(daoInfo.rewardTemplateType)].delegatecall(
            abi.encodeWithSelector(
                IRewardTemplate.claimDaoCreatorReward.selector,
                daoId,
                l.protocolFeePool,
                l.ownerProxy.ownerOf(daoId),
                l.drb.currentRound(),
                daoInfo.token
            )
        );
        require(succ);
        (, daoCreatorReward) = abi.decode(data, (uint256, uint256));

        emit D4AClaimProjectERC20Reward(daoId, daoInfo.token, daoCreatorReward);
    }

    function claimCanvasReward(bytes32 canvasId) public nonReentrant returns (uint256) {
        _checkPauseStatus();
        _checkPauseStatus(canvasId);
        _checkCanvasExist(canvasId);
        bytes32 daoId = CanvasStorage.layout().canvasInfos[canvasId].daoId;
        _checkDaoExist(daoId);
        _checkPauseStatus(daoId);

        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        (bool succ, bytes memory data) = l.rewardTemplates[uint8(daoInfo.rewardTemplateType)].delegatecall(
            abi.encodeWithSelector(
                IRewardTemplate.claimCanvasCreatorReward.selector,
                daoId,
                canvasId,
                l.ownerProxy.ownerOf(canvasId),
                l.drb.currentRound(),
                daoInfo.token
            )
        );
        require(succ);
        uint256 amount = abi.decode(data, (uint256));

        emit D4AClaimCanvasReward(daoId, canvasId, daoInfo.token, amount);

        return amount;
    }

    function claimNftMinterReward(bytes32 daoId, address minter) public nonReentrant returns (uint256) {
        _checkPauseStatus();
        _checkDaoExist(daoId);
        _checkPauseStatus(daoId);
        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        (bool succ, bytes memory data) = l.rewardTemplates[uint8(daoInfo.rewardTemplateType)].delegatecall(
            abi.encodeWithSelector(
                IRewardTemplate.claimNftMinterReward.selector, daoId, minter, l.drb.currentRound(), daoInfo.token
            )
        );
        require(succ);
        uint256 amount = abi.decode(data, (uint256));

        emit D4AClaimNftMinterReward(daoId, daoInfo.token, amount);

        return amount;
    }

    struct ExchangeERC20ToETHLocalVars {
        uint256 tokenCirculation;
        uint256 tokenAmount;
    }

    function exchangeERC20ToETH(bytes32 daoId, uint256 tokenAmount, address to) public nonReentrant returns (uint256) {
        _checkPauseStatus();
        _checkPauseStatus(daoId);

        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        address token = daoInfo.token;
        address daoFeePool = daoInfo.daoFeePool;

        D4AERC20(token).burn(msg.sender, tokenAmount);
        D4AERC20(token).mint(daoFeePool, tokenAmount);

        RewardStorage.RewardInfo storage rewardInfo = RewardStorage.layout().rewardInfos[daoId];
        if (rewardInfo.rewardIssuePendingRound != 0) {
            uint256 roundReward =
                ID4AProtocolReadable(address(this)).getRoundReward(daoId, rewardInfo.rewardIssuePendingRound);
            rewardInfo.rewardIssuePendingRound = 0;
            D4AERC20(token).mint(address(this), roundReward);
        }

        ExchangeERC20ToETHLocalVars memory vars;
        vars.tokenCirculation = D4AERC20(token).totalSupply() + tokenAmount - D4AERC20(token).balanceOf(daoFeePool);

        if (vars.tokenCirculation == 0) return 0;

        GrantStorage.Layout storage grantStorage = GrantStorage.layout();
        D4AVestingWallet vestingWallet = D4AVestingWallet(payable(grantStorage.vestingWallets[daoId]));
        vars.tokenAmount = tokenAmount;
        if (address(vestingWallet) != address(0)) {
            vestingWallet.release();
            address[] memory allowedTokenList = grantStorage.allowedTokenList;
            for (uint256 i; i < allowedTokenList.length;) {
                vestingWallet.release(allowedTokenList[i]);
                uint256 grantTokenAmount =
                    (vars.tokenAmount * IERC20(allowedTokenList[i]).balanceOf(daoFeePool)) / vars.tokenCirculation;
                if (grantTokenAmount > 0) {
                    emit D4AExchangeERC20ToERC20(
                        daoId, msg.sender, to, allowedTokenList[i], vars.tokenAmount, grantTokenAmount
                    );
                    D4AFeePool(payable(daoFeePool)).transfer(allowedTokenList[i], payable(to), grantTokenAmount);
                }
                unchecked {
                    ++i;
                }
            }
        }

        uint256 availableETH = daoFeePool.balance
            - (
                PriceStorage.layout().daoFloorPrices[daoId] == 0
                    ? 0
                    : rewardInfo.totalWeights[SettingsStorage.layout().drb.currentRound()]
            );
        uint256 ethAmount = (tokenAmount * availableETH) / vars.tokenCirculation;

        if (ethAmount != 0) D4AFeePool(payable(daoFeePool)).transfer(address(0x0), payable(to), ethAmount);

        emit D4AExchangeERC20ToETH(daoId, msg.sender, to, tokenAmount, ethAmount);

        return ethAmount;
    }

    ///////////////////////////////////////////
    // Getters
    ///////////////////////////////////////////

    function getNFTTokenCanvas(bytes32 daoId, uint256 tokenId) public view returns (bytes32) {
        return _nftHashToCanvasId[keccak256(abi.encodePacked(daoId, tokenId))];
    }

    function _checkDaoExist(bytes32 daoId) internal view {
        if (!DaoStorage.layout().daoInfos[daoId].daoExist) revert DaoNotExist();
    }

    function _checkCanvasExist(bytes32 canvasId) internal view {
        if (!CanvasStorage.layout().canvasInfos[canvasId].canvasExist) revert CanvasNotExist();
    }

    function _checkCaller(address caller) internal view {
        if (caller != msg.sender) {
            revert NotCaller(caller);
        }
    }

    function _checkPauseStatus() internal view {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (l.isProtocolPaused) {
            revert D4APaused();
        }
    }

    function _checkPauseStatus(bytes32 id) internal view {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        if (l.pauseStatuses[id]) {
            revert Paused(id);
        }
    }

    function _uriExist(string memory uri) internal view returns (bool) {
        return uriExists[keccak256(abi.encodePacked(uri))];
    }

    function _checkUriExist(string calldata uri) internal view {
        if (!_uriExist(uri)) {
            revert UriNotExist(uri);
        }
    }

    function _checkUriNotExist(string memory uri) internal view {
        if (_uriExist(uri)) {
            revert UriAlreadyExist(uri);
        }
    }

    function _checkMintEligibility(
        bytes32 daoId,
        address account,
        bytes32[] calldata proof,
        uint256 amount
    )
        internal
        view
    {
        if (!_ableToMint(daoId, account, proof, amount)) revert ExceedMinterMaxMintAmount();
    }

    function _ableToMint(
        bytes32 daoId,
        address account,
        bytes32[] calldata proof,
        uint256 amount
    )
        internal
        view
        returns (bool)
    {
        /*
        Checking priority
        1. blacklist
        2. if whitelist on, designated user mint cap
        3. NFT holder pass mint cap
        4. dao mint cap
        */
        IPermissionControl permissionControl = SettingsStorage.layout().permissionControl;
        if (permissionControl.isMinterBlacklisted(daoId, account)) {
            revert Blacklisted();
        }
        DaoMintInfo storage daoMintInfo = DaoStorage.layout().daoInfos[daoId].daoMintInfo;
        uint32 daoMintCap = daoMintInfo.daoMintCap;
        uint32 NFTHolderMintCap = daoMintInfo.NFTHolderMintCap;
        UserMintInfo memory userMintInfo = daoMintInfo.userMintInfos[account];

        Whitelist memory whitelist = permissionControl.getWhitelist(daoId);
        bool isWhitelistOff = whitelist.minterMerkleRoot == bytes32(0) && whitelist.minterNFTHolderPasses.length == 0;

        uint256 expectedMinted = userMintInfo.minted + amount;
        // no whitelist
        if (isWhitelistOff) {
            return daoMintCap == 0 ? true : expectedMinted <= daoMintCap;
        }

        // whitelist on && not in whitelist
        if (!permissionControl.inMinterWhitelist(daoId, account, proof)) {
            revert NotInWhitelist();
        }

        if (userMintInfo.mintCap != 0) return expectedMinted <= userMintInfo.mintCap;
        if (NFTHolderMintCap != 0 && permissionControl.inMinterNFTHolderPasses(whitelist, account)) {
            return expectedMinted <= NFTHolderMintCap;
        }
        if (daoMintCap != 0) return expectedMinted <= daoMintCap;
        return true;
    }

    function _verifySignature(
        bytes32 daoId,
        bytes32 canvasId,
        string calldata tokenUri,
        uint256 nftFlatPrice,
        bytes calldata signature
    )
        internal
        view
    {
        // check for special token URIs first
        if (_isSpecialTokenUri(daoId, tokenUri)) return;

        SettingsStorage.Layout storage l = SettingsStorage.layout();
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(_MINTNFT_TYPEHASH, canvasId, keccak256(bytes(tokenUri)), nftFlatPrice))
        );
        address signer = ECDSAUpgradeable.recover(digest, signature);
        if (
            !IAccessControlUpgradeable(address(this)).hasRole(SIGNER_ROLE, signer)
                && signer != l.ownerProxy.ownerOf(canvasId)
        ) revert InvalidSignature();
    }

    function _isSpecialTokenUri(bytes32 daoId, string calldata tokenUri) internal view returns (bool) {
        string memory specialTokenUriPrefix = BasicDaoStorage.layout().specialTokenUriPrefix;
        string memory daoIndex = LibString.toString(DaoStorage.layout().daoInfos[daoId].daoIndex);
        if (!LibString.startsWith(tokenUri, LibString.concat(specialTokenUriPrefix, daoIndex))) return false;
        // strip prefix, daoIndex at the start and `.json` at the end
        string memory tokenIndexString =
            tokenUri[bytes(specialTokenUriPrefix).length + bytes(daoIndex).length:bytes(tokenUri).length - 5];
        // try parse tokenIndex from string to uint256;
        uint256 tokenIndex;
        for (uint256 i; i < bytes(tokenIndexString).length; ++i) {
            if (bytes(tokenIndexString)[i] <= "0" || bytes(tokenIndexString)[i] >= "9") return false;
            tokenIndex = tokenIndex * 10 + (uint8(bytes(tokenIndexString)[i]) - 48);
        }
        if (tokenIndex > 999) return false;
        return true;
    }

    function _mintNft(
        bytes32 canvasId,
        string calldata tokenUri,
        uint256 flatPrice
    )
        internal
        returns (uint256 tokenId)
    {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        {
            _checkPauseStatus();
            _checkPauseStatus(canvasId);
            _checkCanvasExist(canvasId);
            _checkUriNotExist(tokenUri);
        }
        bytes32 daoId = CanvasStorage.layout().canvasInfos[canvasId].daoId;

        _checkPauseStatus(daoId);

        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        if (daoInfo.nftTotalSupply >= daoInfo.nftMaxSupply) revert NftExceedMaxAmount();

        uriExists[keccak256(abi.encodePacked(tokenUri))] = true;

        // get next mint price
        uint256 price;
        {
            uint256 currentRound = l.drb.currentRound();
            uint256 nftPriceFactor = daoInfo.nftPriceFactor;
            price = _getCanvasNextPrice(daoId, canvasId, flatPrice, daoInfo.startRound, currentRound, nftPriceFactor);
            _updatePrice(currentRound, daoId, canvasId, price, flatPrice, nftPriceFactor);
        }

        // split fee
        uint256 daoFee;
        bytes32 tempCanvasId = canvasId;
        CanvasStorage.CanvasInfo storage canvasInfo = CanvasStorage.layout().canvasInfos[canvasId];
        uint256 canvasRebateRatioInBps;
        {
            address protocolFeePool = l.protocolFeePool;
            address daoFeePool = daoInfo.daoFeePool;
            address canvasOwner = l.ownerProxy.ownerOf(tempCanvasId);
            uint256 daoShare = (
                flatPrice == 0
                    ? ID4AProtocolReadable(address(this)).getDaoFeePoolETHRatio(daoId)
                    : ID4AProtocolReadable(address(this)).getDaoFeePoolETHRatioFlatPrice(daoId)
            ) * price;

            if (
                (price - daoShare / BASIS_POINT - (price * l.protocolMintFeeRatioInBps) / BASIS_POINT) != 0
                    && ID4AProtocolReadable(address(this)).getNftMinterERC20Ratio(daoId) != 0
            ) canvasRebateRatioInBps = canvasInfo.canvasRebateRatioInBps;
            daoFee = _splitFee(protocolFeePool, daoFeePool, canvasOwner, price, daoShare, canvasRebateRatioInBps);
        }

        _updateReward(
            daoId, canvasId, PriceStorage.layout().daoFloorPrices[daoId] == 0 ? 1 ether : daoFee, canvasRebateRatioInBps
        );

        // mint
        tokenId = D4AERC721(daoInfo.nft).mintItem(msg.sender, tokenUri);
        {
            daoInfo.nftTotalSupply++;
            canvasInfo.tokenIds.push(tokenId);
            _nftHashToCanvasId[keccak256(abi.encodePacked(daoId, tokenId))] = canvasId;
        }

        emit D4AMintNFT(daoId, canvasId, tokenId, tokenUri, price);
    }

    function _updatePrice(
        uint256 currentRound,
        bytes32 daoId,
        bytes32 canvasId,
        uint256 price,
        uint256 flatPrice,
        uint256 nftPriceMultiplyFactor
    )
        internal
    {
        if (flatPrice == 0) {
            (bool succ,) = SettingsStorage.layout().priceTemplates[uint8(
                DaoStorage.layout().daoInfos[daoId].priceTemplateType
            )].delegatecall(
                abi.encodeWithSelector(
                    IPriceTemplate.updateCanvasPrice.selector,
                    daoId,
                    canvasId,
                    currentRound,
                    price,
                    nftPriceMultiplyFactor
                )
            );
            require(succ);
        }
    }

    struct BatchMintLocalVars {
        uint256 length;
        uint256 currentRound;
        uint256 nftPriceFactor;
        uint256 daoTotalShare;
        uint256 totalPrice;
    }

    function _batchMint(
        bytes32 daoId,
        bytes32 canvasId,
        MintNftInfo[] memory mintNftInfos
    )
        internal
        returns (uint256[] memory)
    {
        _checkPauseStatus();
        _checkPauseStatus(daoId);
        _checkCanvasExist(canvasId);
        _checkPauseStatus(canvasId);

        BatchMintLocalVars memory vars;
        vars.length = mintNftInfos.length;
        for (uint256 i; i < vars.length;) {
            _checkUriNotExist(mintNftInfos[i].tokenUri);
            unchecked {
                ++i;
            }
        }

        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        CanvasStorage.CanvasInfo storage canvasInfo = CanvasStorage.layout().canvasInfos[canvasId];
        if (daoInfo.nftTotalSupply + vars.length > daoInfo.nftMaxSupply) revert NftExceedMaxAmount();

        vars.currentRound = SettingsStorage.layout().drb.currentRound();
        vars.nftPriceFactor = daoInfo.nftPriceFactor;

        uint256[] memory tokenIds = new uint256[](vars.length);
        daoInfo.nftTotalSupply += vars.length;
        for (uint256 i; i < vars.length;) {
            uriExists[keccak256(abi.encodePacked(mintNftInfos[i].tokenUri))] = true;
            tokenIds[i] = D4AERC721(daoInfo.nft).mintItem(msg.sender, mintNftInfos[i].tokenUri);
            canvasInfo.tokenIds.push(tokenIds[i]);
            _nftHashToCanvasId[keccak256(abi.encodePacked(daoId, tokenIds[i]))] = canvasId;
            uint256 flatPrice = mintNftInfos[i].flatPrice;
            if (flatPrice == 0) {
                uint256 price =
                    _getCanvasNextPrice(daoId, canvasId, 0, daoInfo.startRound, vars.currentRound, vars.nftPriceFactor);
                vars.daoTotalShare += ID4AProtocolReadable(address(this)).getDaoFeePoolETHRatio(daoId) * price;
                vars.totalPrice += price;
                emit D4AMintNFT(daoId, canvasId, tokenIds[i], mintNftInfos[i].tokenUri, price);
                _updatePrice(vars.currentRound, daoId, canvasId, price, 0, vars.nftPriceFactor);
            } else {
                vars.daoTotalShare +=
                    ID4AProtocolReadable(address(this)).getDaoFeePoolETHRatioFlatPrice(daoId) * flatPrice;
                vars.totalPrice += flatPrice;
                emit D4AMintNFT(daoId, canvasId, tokenIds[i], mintNftInfos[i].tokenUri, flatPrice);
            }
            unchecked {
                ++i;
            }
        }

        SettingsStorage.Layout storage l = SettingsStorage.layout();
        uint256 canvasRebateRatioInBps;
        if (
            vars.totalPrice - vars.daoTotalShare / BASIS_POINT
                - (vars.totalPrice * l.protocolMintFeeRatioInBps) / BASIS_POINT != 0
                && ID4AProtocolReadable(address(this)).getNftMinterERC20Ratio(daoId) != 0
        ) canvasRebateRatioInBps = canvasInfo.canvasRebateRatioInBps;
        uint256 daoFee = _splitFee(
            l.protocolFeePool,
            daoInfo.daoFeePool,
            l.ownerProxy.ownerOf(canvasId),
            vars.totalPrice,
            vars.daoTotalShare,
            canvasRebateRatioInBps
        );

        _updateReward(
            daoId,
            canvasId,
            PriceStorage.layout().daoFloorPrices[daoId] == 0 ? 1 ether * vars.length : daoFee,
            canvasRebateRatioInBps
        );

        return tokenIds;
    }

    function _getCanvasNextPrice(
        bytes32 daoId,
        bytes32 canvasId,
        uint256 flatPrice,
        uint256 startRound,
        uint256 currentRound,
        uint256 priceFactor
    )
        internal
        view
        returns (uint256 price)
    {
        PriceStorage.Layout storage priceStorage = PriceStorage.layout();
        uint256 daoFloorPrice = priceStorage.daoFloorPrices[daoId];
        PriceStorage.MintInfo memory maxPrice = priceStorage.daoMaxPrices[daoId];
        PriceStorage.MintInfo memory mintInfo = priceStorage.canvasLastMintInfos[canvasId];
        if (flatPrice == 0) {
            price = IPriceTemplate(
                SettingsStorage.layout().priceTemplates[uint8(DaoStorage.layout().daoInfos[daoId].priceTemplateType)]
            ).getCanvasNextPrice(startRound, currentRound, priceFactor, daoFloorPrice, maxPrice, mintInfo);
        } else {
            price = flatPrice;
        }
    }

    function _updateReward(
        bytes32 daoId,
        bytes32 canvasId,
        uint256 daoFeeAmount,
        uint256 canvasRebateRatioInBps
    )
        internal
    {
        DaoStorage.DaoInfo storage daoInfo = DaoStorage.layout().daoInfos[daoId];
        SettingsStorage.Layout storage l = SettingsStorage.layout();

        (bool succ,) = SettingsStorage.layout().rewardTemplates[uint8(
            DaoStorage.layout().daoInfos[daoId].rewardTemplateType
        )].delegatecall(
            abi.encodeWithSelector(
                IRewardTemplate.updateReward.selector,
                UpdateRewardParam(
                    daoId,
                    canvasId,
                    daoInfo.token,
                    daoInfo.startRound,
                    l.drb.currentRound(),
                    daoInfo.mintableRound,
                    daoFeeAmount,
                    l.protocolERC20RatioInBps,
                    ID4AProtocolReadable(address(this)).getDaoCreatorERC20Ratio(daoId),
                    ID4AProtocolReadable(address(this)).getCanvasCreatorERC20Ratio(daoId),
                    ID4AProtocolReadable(address(this)).getNftMinterERC20Ratio(daoId),
                    canvasRebateRatioInBps
                )
            )
        );
        if (!succ) {
            /// @solidity memory-safe-assembly
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function _splitFee(
        address protocolFeePool,
        address daoFeePool,
        address canvasOwner,
        uint256 price,
        uint256 daoShare,
        uint256 canvasRebateRatioInBps
    )
        internal
        returns (uint256 daoFee)
    {
        SettingsStorage.Layout storage l = SettingsStorage.layout();

        daoFee = daoShare / BASIS_POINT;
        uint256 protocolFee = (price * l.protocolMintFeeRatioInBps) / BASIS_POINT;
        uint256 canvasFee = price - daoFee - protocolFee;
        uint256 rebateAmount = (canvasFee * canvasRebateRatioInBps) / BASIS_POINT;
        canvasFee -= rebateAmount;
        if (msg.value < price - rebateAmount) revert NotEnoughEther();
        uint256 dust = msg.value + rebateAmount - price;

        if (protocolFee > 0) SafeTransferLib.safeTransferETH(protocolFeePool, protocolFee);
        if (daoFee > 0) SafeTransferLib.safeTransferETH(daoFeePool, daoFee);
        if (canvasFee > 0) SafeTransferLib.safeTransferETH(canvasOwner, canvasFee);
        if (dust > 0) SafeTransferLib.safeTransferETH(msg.sender, dust);
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
                string(abi.encodePacked("Asset Pool for DAO4Art Project ", StringsUpgradeable.toString(daoIndex)))
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
        string memory sym = string(abi.encodePacked("D4A.T", StringsUpgradeable.toString(daoIndex)));
        return l.erc20Factory.createD4AERC20(name, sym, address(this));
    }

    function _createERC721Token(uint256 daoIndex, string memory daoName) internal returns (address) {
        SettingsStorage.Layout storage l = SettingsStorage.layout();
        string memory name = daoName;
        string memory sym = string(abi.encodePacked("D4A.N", StringsUpgradeable.toString(daoIndex)));
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
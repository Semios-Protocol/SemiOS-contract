// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { FixedPointMathLib as Math } from "solmate/utils/FixedPointMathLib.sol";

import { DeployHelper } from "test/foundry/utils/DeployHelper.sol";
import { MintNftSigUtils } from "test/foundry/utils/MintNftSigUtils.sol";

import "contracts/interface/D4AStructs.sol";
import "contracts/interface/D4AErrors.sol";
import { ID4AProtocolReadable } from "contracts/interface/ID4AProtocolReadable.sol";
import { D4AERC20 } from "contracts/D4AERC20.sol";

contract GetRewardTillRoundTest is DeployHelper {
    MintNftSigUtils public sigUtils;

    bytes32 public daoId;
    bytes32 public canvasId;

    function setUp() public {
        setUpEnv();
        sigUtils = new MintNftSigUtils(address(protocol));
    }

    function test_getRewardTillRound_Exponential_reward_issuance_1dot26x_decayFactor_ProgressiveJackpot_30_mintableRounds(
    )
        public
    {
        _createDaoAndCanvas(30, RewardTemplateType.EXPONENTIAL_REWARD_ISSUANCE, 12_600, true);

        assertEq(ID4AProtocolReadable(address(protocol)).getRewardTillRound(daoId, 1), 0);
        assertEq(ID4AProtocolReadable(address(protocol)).getRewardTillRound(daoId, 2), 0);

        {
            drb.changeRound(2);
            string memory tokenUri = "test token uri 1";
            uint256 flatPrice = 0;
            bytes32 digest = sigUtils.getTypedDataHash(canvasId, tokenUri, flatPrice);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(canvasCreator.key, digest);
            startHoax(nftMinter.addr);
            protocol.mintNFT{ value: ID4AProtocolReadable(address(protocol)).getCanvasNextPrice(canvasId) }(
                daoId, canvasId, tokenUri, new bytes32[](0), flatPrice, abi.encodePacked(r, s, v)
            );
            vm.stopPrank();
        }

        assertEq(
            ID4AProtocolReadable(address(protocol)).getRewardTillRound(daoId, 3), 370_479_534_683_558_798_115_818_789
        );
        assertEq(
            ID4AProtocolReadable(address(protocol)).getRewardTillRound(daoId, 23), 370_479_534_683_558_798_115_818_789
        );
        assertEq(
            ID4AProtocolReadable(address(protocol)).getRewardTillRound(daoId, 30), 370_479_534_683_558_798_115_818_789
        );

        {
            drb.changeRound(23);
            string memory tokenUri = "test token uri 2";
            uint256 flatPrice = 0;
            bytes32 digest = sigUtils.getTypedDataHash(canvasId, tokenUri, flatPrice);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(canvasCreator.key, digest);
            startHoax(nftMinter.addr);
            protocol.mintNFT{ value: ID4AProtocolReadable(address(protocol)).getCanvasNextPrice(canvasId) }(
                daoId, canvasId, tokenUri, new bytes32[](0), flatPrice, abi.encodePacked(r, s, v)
            );
            vm.stopPrank();
        }

        assertEq(
            ID4AProtocolReadable(address(protocol)).getRewardTillRound(daoId, 3), 370_479_534_683_558_798_115_818_789
        );
        assertEq(
            ID4AProtocolReadable(address(protocol)).getRewardTillRound(daoId, 23), 996_056_405_767_309_103_476_334_563
        );
        assertEq(
            ID4AProtocolReadable(address(protocol)).getRewardTillRound(daoId, 30), 996_056_405_767_309_103_476_334_563
        );
    }

    function _createDaoAndCanvas(
        uint256 mintableRound,
        RewardTemplateType rewardTemplateType,
        uint256 rewardDecayFactor,
        bool isProgressiveJackpot
    )
        internal
    {
        hoax(daoCreator.addr);
        daoId = daoProxy.createProject{ value: 0.1 ether }(
            DaoMetadataParam({
                startDrb: 1,
                mintableRounds: mintableRound,
                floorPriceRank: 0,
                maxNftRank: 0,
                royaltyFee: 750,
                projectUri: "test dao uri",
                projectIndex: 0
            }),
            Whitelist({
                minterMerkleRoot: bytes32(0),
                minterNFTHolderPasses: new address[](0),
                canvasCreatorMerkleRoot: bytes32(0),
                canvasCreatorNFTHolderPasses: new address[](0)
            }),
            Blacklist({ minterAccounts: new address[](0), canvasCreatorAccounts: new address[](0) }),
            DaoMintCapParam({ daoMintCap: 0, userMintCapParams: new UserMintCapParam[](0) }),
            DaoETHAndERC20SplitRatioParam({
                daoCreatorERC20Ratio: 300,
                canvasCreatorERC20Ratio: 9500,
                nftMinterERC20Ratio: 3000,
                daoFeePoolETHRatio: 3000,
                daoFeePoolETHRatioFlatPrice: 3500
            }),
            TemplateParam({
                priceTemplateType: PriceTemplateType.EXPONENTIAL_PRICE_VARIATION,
                priceFactor: 20_000,
                rewardTemplateType: rewardTemplateType,
                rewardDecayFactor: rewardDecayFactor,
                isProgressiveJackpot: isProgressiveJackpot
            }),
            0
        );
        drb.changeRound(1);
        hoax(canvasCreator.addr);
        canvasId = protocol.createCanvas{ value: 0.01 ether }(daoId, "test canvas uri", new bytes32[](0), 3000);
    }
}
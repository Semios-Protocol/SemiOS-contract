// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import { DeployHelper } from "test/foundry/utils/DeployHelper.sol";

import "contracts/interface/D4AStructs.sol";
import "contracts/interface/D4AErrors.sol";

import "forge-std/Test.sol";

contract PDInfiniteModeTest is DeployHelper {
    function setUp() public {
        setUpEnv();
    }

    function test_daoInfiniteModeBasic() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.topUpMode = false;
        param.infiniteMode = true;
        param.noPermission = true;
        param.mintableRound = 10;

        bytes32 daoId = super._createDaoForFunding(param, address(this));
        param.isBasicDao = false;
        param.existDaoId = daoId;
        param.daoUri = "test dao uri 2";
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp + 1));
        bytes32 daoId2 = super._createDaoForFunding(param, daoCreator.addr);

        SetChildrenParam memory vars;
        vars.childrenDaoId = new bytes32[](1);
        vars.childrenDaoId[0] = daoId2;
        vars.erc20Ratios = new uint256[](1);
        vars.erc20Ratios[0] = 5000;
        vars.ethRatios = new uint256[](1);
        vars.ethRatios[0] = 5000;
        vars.selfRewardRatioERC20 = 5000;
        vars.selfRewardRatioETH = 5000;
        protocol.setChildren(daoId, vars);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            50_000_000 ether
        );
        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        vm.roll(2);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            0
        );
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId, address(0), protocol.getDaoCurrentRound(daoId), protocol.getDaoRemainingRound(daoId)
            ),
            0.0035 ether
        );
        protocol.setDaoUnifiedPrice(daoId, 0.02 ether);
        protocol.mintNFTAndTransfer{ value: 0.02 ether }(
            daoId, canvasId1, "nft2", new bytes32[](0), 0.02 ether, hex"11", nftMinter.addr
        );
        vm.roll(3);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId, address(0), protocol.getDaoCurrentRound(daoId), protocol.getDaoRemainingRound(daoId)
            ),
            0.007 ether
        );
    }

    function test_daoMintThenTurnOnInfiniteMode() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.topUpMode = false;
        param.noPermission = true;
        param.mintableRound = 10;
        param.selfRewardRatioERC20 = 10_000;

        bytes32 daoId = super._createDaoForFunding(param, address(this));
        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        protocol.changeDaoInfiniteMode(daoId, 0);
        protocol.setDaoUnifiedPrice(daoId, 0.02 ether);
        protocol.mintNFTAndTransfer{ value: 0.02 ether }(
            daoId, canvasId1, "nft2", new bytes32[](0), 0.02 ether, hex"11", nftMinter.addr
        );
        vm.roll(2);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            45_000_000 ether
        );
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId, address(0), protocol.getDaoCurrentRound(daoId), protocol.getDaoRemainingRound(daoId)
            ),
            0.0105 ether
        );
    }

    function test_daoMintThenTurnOnInfiniteMode_jackpot() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.topUpMode = false;
        param.noPermission = true;
        param.mintableRound = 10;
        param.selfRewardRatioERC20 = 10_000;
        param.isProgressiveJackpot = true;

        bytes32 daoId = super._createDaoForFunding(param, address(this));
        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        protocol.changeDaoInfiniteMode(daoId, 0);
        protocol.setDaoUnifiedPrice(daoId, 0.02 ether);
        protocol.mintNFTAndTransfer{ value: 0.02 ether }(
            daoId, canvasId1, "nft2", new bytes32[](0), 0.02 ether, hex"11", nftMinter.addr
        );
        vm.roll(2);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            45_000_000 ether
        );
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId, address(0), protocol.getDaoCurrentRound(daoId), protocol.getDaoRemainingRound(daoId)
            ),
            0.0105 ether
        );
    }

    function test_daoMintThenTurnOnInfiniteMode_jackpot2() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.topUpMode = false;
        param.noPermission = true;
        param.mintableRound = 10;
        param.selfRewardRatioERC20 = 10_000;
        param.isProgressiveJackpot = true;

        bytes32 daoId = super._createDaoForFunding(param, address(this));
        vm.roll(2);

        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        protocol.changeDaoInfiniteMode(daoId, 0);
        protocol.setDaoUnifiedPrice(daoId, 0.02 ether);
        protocol.mintNFTAndTransfer{ value: 0.02 ether }(
            daoId, canvasId1, "nft2", new bytes32[](0), 0.02 ether, hex"11", nftMinter.addr
        );
        vm.roll(3);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            40_000_000 ether
        );
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId, address(0), protocol.getDaoCurrentRound(daoId), protocol.getDaoRemainingRound(daoId)
            ),
            0.0105 ether
        );
    }

    function test_daoMintTurnOnThenTurnOffInfiniteMode() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.topUpMode = false;
        param.noPermission = true;
        param.mintableRound = 10;
        param.selfRewardRatioERC20 = 10_000;
        param.isProgressiveJackpot = false;

        bytes32 daoId = super._createDaoForFunding(param, address(this));
        vm.roll(3);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            5_000_000 ether
        );
        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        protocol.changeDaoInfiniteMode(daoId, 0);

        vm.roll(5);

        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            45_000_000 ether
        );

        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft2", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );

        vm.roll(8);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            0 ether
        );

        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft3", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        vm.roll(13);
        protocol.changeDaoInfiniteMode(daoId, 20);
        protocol.setInitialTokenSupplyForSubDao(daoId, 10_000_000 ether);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            500_000 ether
        );
        //0.035 * 3 / 20
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId, address(0), protocol.getDaoCurrentRound(daoId), protocol.getDaoRemainingRound(daoId)
            ),
            525_000_000_000_000
        );
    }

    function test_daoMintTurnOnThenTurnOffInfiniteModeJackPot() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.topUpMode = false;
        param.noPermission = true;
        param.mintableRound = 10;
        param.selfRewardRatioERC20 = 10_000;
        param.isProgressiveJackpot = true;

        bytes32 daoId = super._createDaoForFunding(param, address(this));
        vm.roll(3);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            15_000_000 ether
        );
        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        protocol.changeDaoInfiniteMode(daoId, 0);

        vm.roll(5);

        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            35_000_000 ether
        );

        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft2", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );

        vm.roll(8);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            0 ether
        );

        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft3", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        vm.roll(13);
        protocol.changeDaoInfiniteMode(daoId, 20);

        protocol.setInitialTokenSupplyForSubDao(daoId, 10_000_000 ether);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            500_000 ether
        );
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId, address(0), protocol.getDaoCurrentRound(daoId), protocol.getDaoRemainingRound(daoId)
            ),
            525_000_000_000_000
        );
        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft4", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        vm.roll(15);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            1_000_000 ether
        );
    }

    function test_daoMintInLastRoundThenTurnOffInfiniteModeJackPot() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.topUpMode = false;
        param.noPermission = true;
        param.mintableRound = 10;
        param.infiniteMode = true;
        param.selfRewardRatioERC20 = 10_000;
        param.isProgressiveJackpot = true;

        bytes32 daoId = super._createDaoForFunding(param, address(this));
        vm.roll(3);

        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        protocol.changeDaoInfiniteMode(daoId, 20);
        assertEq(protocol.getDaoRemainingRound(daoId), 20);
        protocol.setInitialTokenSupplyForSubDao(daoId, 10_000_000 ether);

        vm.roll(5);
        assertEq(protocol.getDaoRemainingRound(daoId), 18);
        //since round 3 is active, so denominator is 19, numerator is 2
        uint256 a = uint256(10_000_000 ether * 2) / 19;
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            a
        );
    }

    function test_daoMintRoundBeforeLastThenTurnOffInfiniteModeJackPot() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.topUpMode = false;
        param.noPermission = true;
        param.mintableRound = 10;
        param.infiniteMode = true;
        param.selfRewardRatioERC20 = 10_000;
        param.isProgressiveJackpot = true;

        bytes32 daoId = super._createDaoForFunding(param, address(this));
        vm.roll(3);

        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, canvasId1, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        vm.roll(4);
        protocol.changeDaoInfiniteMode(daoId, 20);
        assertEq(protocol.getDaoRemainingRound(daoId), 20);
        protocol.setInitialTokenSupplyForSubDao(daoId, 10_000_000 ether);

        vm.roll(5);
        assertEq(protocol.getDaoRemainingRound(daoId), 19);
        assertEq(
            protocol.getDaoRoundDistributeAmount(
                daoId,
                protocol.getDaoToken(daoId),
                protocol.getDaoCurrentRound(daoId),
                protocol.getDaoRemainingRound(daoId)
            ),
            1_000_000 ether
        );
    }

    function test_daoDeadThenTurnOnInfiniteMode_roundShouldRestart() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.isBasicDao = true;
        param.noPermission = true;
        param.mintableRound = 1;
        param.duration = 3 ether;
        param.infiniteMode = false;
        param.selfRewardRatioERC20 = 10_000;

        bytes32 daoId = super._createDaoForFunding(param, address(this));

        vm.roll(31);
        assertEq(protocol.getDaoRemainingRound(daoId), 1, "a11");
        protocol.mintNFTAndTransfer{ value: 0.01 ether }(
            daoId, param.canvasId, "nft1", new bytes32[](0), 0.01 ether, hex"11", nftMinter.addr
        );
        vm.roll(35);
        protocol.changeDaoInfiniteMode(daoId, 0);
        assertEq(protocol.getDaoPassedRound(daoId), 0, "a13");
        assertEq(protocol.getDaoCurrentRound(daoId), 1, "a14");
        assertEq(protocol.getDaoRemainingRound(daoId), 1, "a15");
        vm.roll(37);
        assertEq(protocol.getDaoPassedRound(daoId), 0, "a21");
        assertEq(protocol.getDaoCurrentRound(daoId), 1, "a22");
        assertEq(protocol.getDaoRemainingRound(daoId), 1, "a23");
        vm.roll(38);
        assertEq(protocol.getDaoPassedRound(daoId), 0, "a31");
        assertEq(protocol.getDaoCurrentRound(daoId), 2, "a32");
        assertEq(protocol.getDaoRemainingRound(daoId), 1, "a33");
        vm.roll(65);
        protocol.changeDaoInfiniteMode(daoId, 10);
        assertEq(protocol.getDaoPassedRound(daoId), 0, "a42");
        assertEq(protocol.getDaoCurrentRound(daoId), 11, "a43");
        assertEq(protocol.getDaoRemainingRound(daoId), 10, "a44");
    }

    function test_daoDeadThenTurnOnInfiniteMode_roundShouldRestartJackPot() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        param.isBasicDao = true;
        param.noPermission = true;
        param.mintableRound = 10;
        param.duration = 3 ether;
        param.infiniteMode = false;
        param.selfRewardRatioERC20 = 10_000;
        param.isProgressiveJackpot = true;

        bytes32 daoId = super._createDaoForFunding(param, address(this));

        vm.roll(31);
        assertEq(protocol.getDaoRemainingRound(daoId), 0, "a11");
        vm.roll(35);
        protocol.changeDaoInfiniteMode(daoId, 0);
        assertEq(protocol.getDaoPassedRound(daoId), 0, "a13");
        assertEq(protocol.getDaoCurrentRound(daoId), 1, "a14");
        assertEq(protocol.getDaoRemainingRound(daoId), 1, "a15");
        vm.roll(37);
        assertEq(protocol.getDaoPassedRound(daoId), 0, "a21");
        assertEq(protocol.getDaoCurrentRound(daoId), 1, "a22");
        assertEq(protocol.getDaoRemainingRound(daoId), 1, "a23");
        vm.roll(38);
        assertEq(protocol.getDaoPassedRound(daoId), 1, "a31");
        assertEq(protocol.getDaoCurrentRound(daoId), 2, "a32");
        assertEq(protocol.getDaoRemainingRound(daoId), 1, "a33");
        vm.roll(65);
        protocol.changeDaoInfiniteMode(daoId, 10);
        assertEq(protocol.getDaoPassedRound(daoId), 10, "a42");
        assertEq(protocol.getDaoCurrentRound(daoId), 11, "a43");
        assertEq(protocol.getDaoRemainingRound(daoId), 10, "a44");
    }

    function test_infiniteModeShouldNotAffectPriceInfo() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.noPermission = true;
        param.mintableRound = 10;
        param.infiniteMode = false;
        param.selfRewardRatioERC20 = 10_000;
        param.uniPriceModeOff = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
            ),
            0,
            daoCreator.key,
            nftMinter.addr
        );
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(2)), ".json"
            ),
            0,
            daoCreator.key,
            nftMinter.addr
        );
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(3)), ".json"
            ),
            0,
            daoCreator.key,
            nftMinter.addr
        );
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.08 ether);
        vm.prank(daoCreator.addr);
        protocol.changeDaoInfiniteMode(daoId, 0);
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.08 ether);
        vm.roll(2);
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.04 ether);
        vm.roll(3);
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.02 ether);
        vm.prank(daoCreator.addr);

        protocol.changeDaoInfiniteMode(daoId, 10);
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.02 ether);
        vm.roll(4);
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.01 ether);
        console2.log(address(this));
        console2.log(msg.sender);
    }

    function test_daoDeadThenTurnOnInfiniteMode_shouldAffectPriceInfo() public {
        CreateDaoParam memory param;
        param.canvasId = keccak256(abi.encode(daoCreator.addr, block.timestamp));
        bytes32 canvasId1 = param.canvasId;
        param.isBasicDao = true;
        param.noPermission = true;
        param.mintableRound = 1;
        param.infiniteMode = false;
        param.selfRewardRatioERC20 = 10_000;
        param.uniPriceModeOff = true;
        bytes32 daoId = super._createDaoForFunding(param, daoCreator.addr);
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(1)), ".json"
            ),
            0,
            daoCreator.key,
            nftMinter.addr
        );
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(2)), ".json"
            ),
            0,
            daoCreator.key,
            nftMinter.addr
        );
        super._mintNft(
            daoId,
            canvasId1,
            string.concat(
                tokenUriPrefix, vm.toString(protocol.getDaoIndex(daoId)), "-", vm.toString(uint256(3)), ".json"
            ),
            0,
            daoCreator.key,
            nftMinter.addr
        );
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.08 ether);
        vm.roll(2);
        vm.prank(daoCreator.addr);
        protocol.changeDaoInfiniteMode(daoId, 0);
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.01 ether);
        vm.roll(3);
        assertEq(protocol.getCanvasNextPrice(canvasId1), 0.005 ether);
    }

    receive() external payable { }
}
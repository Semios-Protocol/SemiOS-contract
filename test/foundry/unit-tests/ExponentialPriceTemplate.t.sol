// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { ExponentialPriceVariationHarness } from "test/foundry/harness/ExponentialPriceVariationHarness.sol";

import { BASIS_POINT } from "contracts/interface/D4AConstants.sol";
import { PriceStorage } from "contracts/storages/PriceStorage.sol";

contract exponentialPriceVariationTest is Test {
    ExponentialPriceVariationHarness public exponentialPriceVariation;
    bytes32 public daoId = "daoId";
    bytes32 public canvasId1 = "canvasId1";
    bytes32 public canvasId2 = "canvasId2";
    bytes32 public canvasId3 = "canvasId3";
    uint256 public floorPrice = 0.1 ether;
    uint256 public priceMultiplier = 20_000;
    uint256 public round0 = 0;
    uint256 public round1 = 1;
    uint256 public x1 = 10_000;
    uint256 public x2 = 20_000;
    uint256 public x1_5 = 15_000;

    function setUp() public {
        exponentialPriceVariation = new ExponentialPriceVariationHarness();
        vm.store(
            address(exponentialPriceVariation),
            keccak256(abi.encode(daoId, bytes32(uint256(keccak256("D4Av2.contracts.storage.PriceStorage")) + 2))),
            bytes32(floorPrice)
        );
    }

    // At round 0, will get floor price
    function test_getCanvasNextPrice_MaxPriceZeroRoundAndStartDrb() public {
        uint256 round = 0;
        uint256 price = exponentialPriceVariation.getCanvasNextPrice(
            round,
            round,
            priceMultiplier,
            floorPrice,
            PriceStorage.layout().daoMaxPrices[daoId],
            PriceStorage.layout().canvasLastMintInfos[canvasId1]
        );
        assertEq(price, floorPrice);
    }

    function testFuzz_getCanvasNextPrice_MaxPriceZeroRoundAndStartDrb(uint256 round) public {
        uint256 price = exponentialPriceVariation.getCanvasNextPrice(
            round,
            round,
            priceMultiplier,
            floorPrice,
            PriceStorage.layout().daoMaxPrices[daoId],
            PriceStorage.layout().canvasLastMintInfos[canvasId1]
        );
        assertEq(price, floorPrice);
    }

    function test_getCanvasNextPrice_MaxPriceZeroRoundNotStartDrb() public {
        uint256 startRound = 0;
        uint256 round = 1;
        uint256 price = exponentialPriceVariation.getCanvasNextPrice(
            startRound,
            round,
            priceMultiplier,
            floorPrice,
            PriceStorage.layout().daoMaxPrices[daoId],
            PriceStorage.layout().canvasLastMintInfos[canvasId1]
        );
        assertEq(price, floorPrice >> 1);
    }

    function testFuzz_getCanvasNextPrice_MaxPriceZeroRoundNotStartDrb(uint256 startRound, uint256 round) public {
        vm.assume(startRound < round);
        uint256 price = exponentialPriceVariation.getCanvasNextPrice(
            startRound,
            round,
            priceMultiplier,
            floorPrice,
            PriceStorage.layout().daoMaxPrices[daoId],
            PriceStorage.layout().canvasLastMintInfos[canvasId1]
        );
        assertEq(price, floorPrice >> 1);
    }
}

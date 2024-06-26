// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { BASIS_POINT } from "contracts/interface/D4AConstants.sol";
import { SettingsStorage } from "contracts/storages/SettingsStorage.sol";
import { ID4ASettingsReadable } from "./ID4ASettingsReadable.sol";
import { IPermissionControl } from "contracts/interface/IPermissionControl.sol";
import { ID4AOwnerProxy } from "contracts/interface/ID4AOwnerProxy.sol";

contract D4ASettingsReadable is ID4ASettingsReadable {
    function permissionControl() public view returns (IPermissionControl) {
        return SettingsStorage.layout().permissionControl;
    }

    function ownerProxy() public view returns (ID4AOwnerProxy) {
        return SettingsStorage.layout().ownerProxy;
    }

    function mintProtocolFeeRatio() public view returns (uint256) {
        return SettingsStorage.layout().protocolMintFeeRatioInBps;
    }

    function protocolFeePool() public view returns (address) {
        return SettingsStorage.layout().protocolFeePool;
    }

    function tradeProtocolFeeRatio() public view returns (uint256) {
        return SettingsStorage.layout().protocolRoyaltyFeeRatioInBps;
    }

    function ratioBase() public pure returns (uint256) {
        return BASIS_POINT;
    }

    function getPriceTemplates() public view returns (address[] memory priceTemplates) {
        priceTemplates = new address[](256);
        SettingsStorage.Layout storage settingsStorage = SettingsStorage.layout();

        uint256 i;
        for (; i < settingsStorage.priceTemplates.length; i++) {
            if (settingsStorage.priceTemplates[i] == address(0)) break;
            priceTemplates[i] = settingsStorage.priceTemplates[i];
        }

        /// @solidity memory-safe-assembly
        assembly {
            mstore(priceTemplates, i)
        }
    }

    function getRewardTemplates() public view returns (address[] memory rewardTemplates) {
        rewardTemplates = new address[](256);
        SettingsStorage.Layout storage settingsStorage = SettingsStorage.layout();

        uint256 i;
        for (; i < settingsStorage.rewardTemplates.length; i++) {
            if (settingsStorage.rewardTemplates[i] == address(0)) break;
            rewardTemplates[i] = settingsStorage.rewardTemplates[i];
        }

        /// @solidity memory-safe-assembly
        assembly {
            mstore(rewardTemplates, i)
        }
    }
}

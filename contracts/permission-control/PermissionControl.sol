// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IAccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { MerkleProofUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import { Whitelist, Blacklist } from "contracts/interface/D4AStructs.sol";
import { IPermissionControl } from "contracts/interface/IPermissionControl.sol";
import { ID4AOwnerProxy } from "contracts/interface/ID4AOwnerProxy.sol";

//import "forge-std/Test.sol";

contract PermissionControl is IPermissionControl, Initializable, EIP712Upgradeable {
    mapping(bytes32 => Whitelist) internal _whitelists;
    // 0th bit set to 1 when initialized to save gas
    // 1st bit set to 1 when blacklisted as minter
    // 2nd bit set to 1 when blacklisted as canvas creator
    mapping(bytes32 => mapping(address => uint256)) internal _blacklisted;
    ID4AOwnerProxy public ownerProxy;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable protocol;

    bytes32 internal constant ADDPERMISSION_TYPEHASH = keccak256(
        abi.encodePacked(
            abi.encodePacked("AddPermission(bytes32 daoId,Whitelist whitelist,Blacklist blacklist)"),
            abi.encodePacked("Blacklist(address[] minterAccounts,address[] canvasCreatorAccounts)"),
            abi.encodePacked(
                "Whitelist(",
                "bytes32 minterMerkleRoot,",
                "address[] minterNFTHolderPasses,",
                "NftIdentifer[] minterNFTIdHolderPasses,",
                "bytes32 canvasCreatorMerkleRoot,",
                "address[] canvasCreatorNFTHolderPasses,",
                "NftIdentifier[] canvasCreatorNFTIdHolderPasses",
                ")"
            )
        )
    );
    bytes32 internal constant BLACKLIST_TYPEHASH = keccak256(
        abi.encodePacked(abi.encodePacked("Blacklist(address[] minterAccounts,address[] canvasCreatorAccounts)"))
    );
    bytes32 internal constant WHITELIST_TYPEHASH = keccak256(
        abi.encodePacked(
            abi.encodePacked(
                "Whitelist(",
                "bytes32 minterMerkleRoot,",
                "address[] minterNFTHolderPasses,",
                "NftIdentifer[] minterNFTIdHolderPasses,",
                "bytes32 canvasCreatorMerkleRoot,",
                "address[] canvasCreatorNFTHolderPasses,",
                "NftIdentifier[] canvasCreatorNFTIdHolderPasses",
                ")"
            )
        )
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address protocol_) {
        protocol = protocol_;
        _disableInitializers();
    }

    function initialize(ID4AOwnerProxy _ownerProxy) external initializer {
        ownerProxy = _ownerProxy;
        __EIP712_init("D4APermissionControl", "2");
    }

    function addPermissionWithSignature(
        bytes32 daoId,
        Whitelist calldata whitelist,
        Blacklist calldata blacklist,
        bytes calldata signature
    )
        external
    {
        _verifySignature(daoId, whitelist, blacklist, signature);
        _addPermission(daoId, whitelist, blacklist);
    }

    function addPermission(bytes32 daoId, Whitelist calldata whitelist, Blacklist calldata blacklist) external {
        require(msg.sender == ownerProxy.ownerOf(daoId) || msg.sender == protocol, "PermissionControl: not DAO owner");
        _addPermission(daoId, whitelist, blacklist);
    }

    function _addPermission(bytes32 daoId, Whitelist calldata whitelist, Blacklist calldata blacklist) internal {
        // add whitelist
        _whitelists[daoId] = whitelist;
        emit WhitelistModified(daoId, whitelist);

        // add blacklist
        uint256 length = blacklist.minterAccounts.length;
        for (uint256 i = 0; i < length;) {
            _blacklisted[daoId][blacklist.minterAccounts[i]] |= 0x011;

            emit MinterBlacklisted(daoId, blacklist.minterAccounts[i]);

            unchecked {
                ++i;
            }
        }
        length = blacklist.canvasCreatorAccounts.length;
        for (uint256 i = 0; i < length;) {
            _blacklisted[daoId][blacklist.canvasCreatorAccounts[i]] |= 0x101;

            emit CanvasCreatorBlacklisted(daoId, blacklist.canvasCreatorAccounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev After the DAO is created, can modify whitelist and blacklist directly
     */
    function modifyPermission(
        bytes32 daoId,
        Whitelist calldata whitelist,
        Blacklist calldata blacklist,
        Blacklist calldata unblacklist
    )
        external
    {
        require(msg.sender == ownerProxy.ownerOf(daoId) || msg.sender == protocol, "PermissionControl: not DAO owner");

        // modify whitelist
        _whitelists[daoId] = whitelist;
        emit WhitelistModified(daoId, whitelist);

        // add blacklist
        uint256 length = blacklist.minterAccounts.length;
        for (uint256 i = 0; i < length;) {
            _blacklisted[daoId][blacklist.minterAccounts[i]] |= 0x011;

            emit MinterBlacklisted(daoId, blacklist.minterAccounts[i]);

            unchecked {
                ++i;
            }
        }
        length = blacklist.canvasCreatorAccounts.length;
        for (uint256 i = 0; i < length;) {
            _blacklisted[daoId][blacklist.canvasCreatorAccounts[i]] |= 0x101;

            emit CanvasCreatorBlacklisted(daoId, blacklist.canvasCreatorAccounts[i]);

            unchecked {
                ++i;
            }
        }

        // unblacklist
        length = unblacklist.minterAccounts.length;
        for (uint256 i = 0; i < length;) {
            _blacklisted[daoId][unblacklist.minterAccounts[i]] &= 0x101;

            emit MinterUnBlacklisted(daoId, unblacklist.minterAccounts[i]);

            unchecked {
                ++i;
            }
        }
        length = unblacklist.canvasCreatorAccounts.length;
        for (uint256 i = 0; i < length;) {
            _blacklisted[daoId][unblacklist.canvasCreatorAccounts[i]] &= 0x011;

            emit CanvasCreatorUnBlacklisted(daoId, unblacklist.canvasCreatorAccounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    function _verifySignature(
        bytes32 daoId,
        Whitelist calldata whitelist,
        Blacklist calldata blacklist,
        bytes calldata signature
    )
        internal
        view
    {
        bytes32 digest = _hashTypedDataV4(
            // hashStruct(value) is encoded as keccak256(typeHash ‖ encodeData(s))
            keccak256(
                abi.encode(
                    ADDPERMISSION_TYPEHASH,
                    daoId,
                    // struct values are encoded recursively as hashStruct(value)
                    keccak256(
                        abi.encode(
                            WHITELIST_TYPEHASH,
                            whitelist.minterMerkleRoot,
                            keccak256(abi.encodePacked(whitelist.minterNFTHolderPasses)),
                            whitelist.canvasCreatorMerkleRoot,
                            keccak256(abi.encodePacked(whitelist.canvasCreatorNFTHolderPasses))
                        )
                    ),
                    keccak256(
                        abi.encode(
                            BLACKLIST_TYPEHASH,
                            // array values are encoded as the keccak256 hash
                            // of the concatenated encodeData of their contents
                            keccak256(abi.encodePacked(blacklist.minterAccounts)),
                            keccak256(abi.encodePacked(blacklist.canvasCreatorAccounts))
                        )
                    )
                )
            )
        );
        address signer = ECDSAUpgradeable.recover(digest, signature);
        require(signer != address(0) && signer == ownerProxy.ownerOf(daoId), "PermissionControl: not DAO owner");
    }

    /**
     * @dev Checks if account is blacklisted as minter
     * @param daoId DAO id
     * @param _account The address to check
     */
    function isMinterBlacklisted(bytes32 daoId, address _account) external view returns (bool) {
        if ((_blacklisted[daoId][_account] & 0x10) != 0) return true;
        return false;
    }

    /**
     * @dev Checks if account is blacklisted as canvas creator
     * @param daoId DAO id
     * @param _account The address to check
     */
    function isCanvasCreatorBlacklisted(bytes32 daoId, address _account) external view returns (bool) {
        if ((_blacklisted[daoId][_account] & 0x100) != 0) return true;
        return false;
    }

    function inMinterWhitelist(
        bytes32 daoId,
        address _account,
        bytes32[] calldata _proof
    )
        external
        view
        returns (bool)
    {
        Whitelist memory whitelist = _whitelists[daoId];

        if (whitelist.minterMerkleRoot == bytes32(0)) return false;
        if (
            MerkleProofUpgradeable.verifyCalldata(
                _proof, whitelist.minterMerkleRoot, keccak256(bytes.concat(keccak256(abi.encode(_account))))
            )
        ) {
            return true;
        }
        return false;
    }

    function inMinterNFTHolderPasses(Whitelist memory whitelist, address account) public view returns (bool) {
        uint256 length = whitelist.minterNFTHolderPasses.length;
        for (uint256 i = 0; i < length;) {
            if (IERC721Upgradeable(whitelist.minterNFTHolderPasses[i]).balanceOf(account) > 0) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function inMinterNFTIdHolderPasses(Whitelist memory whitelist, address account) public view returns (bool) {
        uint256 length = whitelist.minterNFTIdHolderPasses.length;
        for (uint256 i = 0; i < length;) {
            if (
                IERC721Upgradeable(whitelist.minterNFTIdHolderPasses[i].erc721Address).ownerOf(
                    whitelist.minterNFTIdHolderPasses[i].tokenId
                ) == account
            ) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    /**
     * @dev Throws if _merkleRoot is not correct
     *      If merkleRoot of DAO is set, return `false` if given _merkle proof is not correct
     *      If NFTHolderPasses of DAO is set, return `false` if given _account is not the owner of the NFT
     * @param daoId DAO id
     * @param _account The address to check
     * @param _proof The merkle proof
     */
    function inCanvasCreatorWhitelist(
        bytes32 daoId,
        address _account,
        bytes32[] calldata _proof
    )
        external
        view
        returns (bool)
    {
        Whitelist memory whitelist = _whitelists[daoId];

        if (
            whitelist.canvasCreatorMerkleRoot == bytes32(0) && whitelist.canvasCreatorNFTHolderPasses.length == 0
                && whitelist.canvasCreatorNFTIdHolderPasses.length == 0
        ) {
            return true;
        }
        if (
            MerkleProofUpgradeable.verifyCalldata(
                _proof, whitelist.canvasCreatorMerkleRoot, keccak256(bytes.concat(keccak256(abi.encode(_account))))
            )
        ) {
            return true;
        }
        if (whitelist.canvasCreatorNFTHolderPasses.length != 0 && inCanvasCreatorNFTHolderPasses(whitelist, _account)) {
            return true;
        }
        if (
            whitelist.canvasCreatorNFTIdHolderPasses.length != 0
                && inCanvasCreatorNFTIdHolderPasses(whitelist, _account)
        ) {
            return true;
        }

        return false;
    }

    function inCanvasCreatorNFTIdHolderPasses(Whitelist memory whitelist, address account) public view returns (bool) {
        uint256 length = whitelist.canvasCreatorNFTIdHolderPasses.length;
        for (uint256 i = 0; i < length;) {
            if (
                IERC721Upgradeable(whitelist.canvasCreatorNFTIdHolderPasses[i].erc721Address).ownerOf(
                    whitelist.canvasCreatorNFTIdHolderPasses[i].tokenId
                ) == account
            ) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function inCanvasCreatorNFTHolderPasses(Whitelist memory whitelist, address account) public view returns (bool) {
        uint256 length = whitelist.canvasCreatorNFTHolderPasses.length;
        for (uint256 i = 0; i < length;) {
            if (IERC721Upgradeable(whitelist.canvasCreatorNFTHolderPasses[i]).balanceOf(account) > 0) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function getWhitelist(bytes32 daoId) external view returns (Whitelist memory) {
        return _whitelists[daoId];
    }

    /**
     * @dev Set owner proxy
     * @param _ownerProxy The address of owner proxy
     */
    function setOwnerProxy(ID4AOwnerProxy _ownerProxy) external {
        require(IAccessControlUpgradeable(address(ownerProxy)).hasRole(bytes32(0), msg.sender), "Not owner");
        ownerProxy = _ownerProxy;
    }
}

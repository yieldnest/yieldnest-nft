// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ERC721Upgradeable, Strings} from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract YieldNestNFT is Initializable, ERC721Upgradeable, AccessControlUpgradeable, EIP712Upgradeable {
    using Strings for uint8;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNATURE_VERSION = "1";
    uint256 private _nextTokenId;
    string private _baseTokenURI;

    mapping(uint256 => uint8) public stages;

    struct MintVoucher {
        address receipient;
        uint256 expiresAt;
        bytes signature;
    }

    struct UpgradeVoucher {
        uint256 tokenId;
        uint8 stage;
        address receipient;
        uint256 expiresAt;
        bytes signature;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address minter,
        string memory tokenName,
        string memory tokenSymbol,
        string memory baseTokenURI
    ) public initializer {
        __ERC721_init(tokenName, tokenSymbol);
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);

        _baseTokenURI = baseTokenURI;
    }

    function setMintFactory(address factory) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!hasRole(MINTER_ROLE, factory), "Already has role");
        _grantRole(MINTER_ROLE, factory);
    }

    function removeMintFactory(address factory) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(MINTER_ROLE, factory), "This is not a minter factory");
        _revokeRole(MINTER_ROLE, factory);
    }

    function recoverMintVoucher(MintVoucher memory voucher) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("MintVoucher(address receipient,uint256 expiresAt)"),
                    voucher.receipient,
                    voucher.expiresAt
                )
            )
        );
        address signer = ECDSA.recover(digest, voucher.signature);
        return signer;
    }

    function recoverUpgradeVoucher(UpgradeVoucher memory voucher) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("UpgradeVoucher(uint256 tokenId,uint8 stage,address receipient,uint256 expiresAt)"),
                    voucher.tokenId,
                    voucher.stage,
                    voucher.receipient,
                    voucher.expiresAt
                )
            )
        );
        address signer = ECDSA.recover(digest, voucher.signature);
        return signer;
    }

    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        _safeMint(to, ++_nextTokenId);
    }

    function safeMint(address receipient, uint256 expiresAt, bytes calldata signature) public payable {
        MintVoucher memory voucher = MintVoucher(receipient, expiresAt, signature);
        require(hasRole(MINTER_ROLE, recoverMintVoucher(voucher)), "Wrong signature");
        require(block.timestamp <= voucher.expiresAt, "Signature has expired");
        _safeMint(voucher.receipient, ++_nextTokenId);
    }

    function safeUpgrade(uint256 tokenId, uint8 stage, address receipient, uint256 expiresAt, bytes calldata signature)
        public
        payable
    {
        UpgradeVoucher memory voucher = UpgradeVoucher(tokenId, stage, receipient, expiresAt, signature);
        require(hasRole(MINTER_ROLE, recoverUpgradeVoucher(voucher)), "Wrong signature");
        require(block.timestamp <= voucher.expiresAt, "Signature has expired");
        require(stages[tokenId] < voucher.stage, "Invalid stage");
        stages[tokenId] = voucher.stage;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, stages[tokenId].toString()) : "";
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ERC721Upgradeable, Strings} from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IYieldNestNFT} from "./interfaces/IYieldNestNFT.sol";

contract YieldNestNFT is
    IYieldNestNFT,
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    EIP712Upgradeable
{
    using Strings for uint8;

    //--------------------------------------------------------------------------------------
    //--------------------------------------  ROLES  ---------------------------------------
    //--------------------------------------------------------------------------------------

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    //--------------------------------------------------------------------------------------
    //------------------------------------  CONSTANTS  -------------------------------------
    //--------------------------------------------------------------------------------------

    string public constant SIGNING_DOMAIN = "Voucher-Domain";
    string public constant SIGNATURE_VERSION = "1";

    //--------------------------------------------------------------------------------------
    //------------------------------------  VARIABLES  -------------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public nextTokenId;
    string public baseTokenURI;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  MAPPINGS  -------------------------------------
    //--------------------------------------------------------------------------------------

    mapping(uint256 => uint8) public stages;

    //--------------------------------------------------------------------------------------
    //----------------------------------  INITIALIZATION  ----------------------------------
    //--------------------------------------------------------------------------------------

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address minter,
        string memory tokenName,
        string memory tokenSymbol,
        string memory _baseTokenURI
    ) public initializer {
        __ERC721_init(tokenName, tokenSymbol);
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);

        baseTokenURI = _baseTokenURI;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MINTING  ----------------------------------------
    //--------------------------------------------------------------------------------------

    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        _safeMint(to, ++nextTokenId);

        emit Minted(to, nextTokenId);
    }

    function safeMint(MintVoucher memory voucher, bytes calldata signature) public {
        if (!hasRole(MINTER_ROLE, recoverMintVoucher(voucher, signature))) revert InvalidSignature();
        if (block.timestamp > voucher.expiresAt) revert ExpiredVoucher();

        _safeMint(voucher.recipient, ++nextTokenId);

        emit Minted(voucher.recipient, nextTokenId);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  UPGRADING  --------------------------------------
    //--------------------------------------------------------------------------------------

    function safeUpgrade(UpgradeVoucher memory voucher, bytes calldata signature) public {
        _requireOwned(voucher.tokenId);
        if (!hasRole(MINTER_ROLE, recoverUpgradeVoucher(voucher, signature))) revert InvalidSignature();
        if (block.timestamp > voucher.expiresAt) revert ExpiredVoucher();
        if (stages[voucher.tokenId] >= voucher.stage) revert InvalidStage();

        stages[voucher.tokenId] = voucher.stage;

        emit Upgraded(voucher.tokenId, voucher.stage);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  ADMIN  ----------------------------------------
    //--------------------------------------------------------------------------------------

    function setBaseURI(string memory _baseTokenURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseTokenURI = _baseTokenURI;
    }

    //--------------------------------------------------------------------------------------
    //------------------------------- SIGNATURE VERIFICATION -------------------------------
    //--------------------------------------------------------------------------------------

    function recoverMintVoucher(MintVoucher memory voucher, bytes calldata signature) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("MintVoucher(address recipient,uint256 expiresAt)"), voucher.recipient, voucher.expiresAt
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        return signer;
    }

    function recoverUpgradeVoucher(UpgradeVoucher memory voucher, bytes calldata signature)
        public
        view
        returns (address)
    {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("UpgradeVoucher(uint256 tokenId,uint8 stage,uint256 expiresAt)"),
                    voucher.tokenId,
                    voucher.stage,
                    voucher.expiresAt
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        return signer;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  VIEWS  ----------------------------------------
    //--------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
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

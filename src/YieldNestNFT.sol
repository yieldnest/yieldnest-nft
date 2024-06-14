// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {Strings} from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/NoncesUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IYieldNestNFT} from "./interfaces/IYieldNestNFT.sol";

contract YieldNestNFT is
    IYieldNestNFT,
    Initializable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    EIP712Upgradeable,
    NoncesUpgradeable
{
    using Strings for uint8;
    using Strings for uint256;

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
    mapping(uint256 => uint256) public avatars;

    //--------------------------------------------------------------------------------------
    //----------------------------------  INITIALIZATION  ----------------------------------
    //--------------------------------------------------------------------------------------

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address minter,
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata _baseTokenURI
    ) external initializer {
        __ERC721_init(tokenName, tokenSymbol);
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
        __AccessControl_init();
        __Nonces_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);

        baseTokenURI = _baseTokenURI;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MINTING  ----------------------------------------
    //--------------------------------------------------------------------------------------

    function safeMint(address to) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = ++nextTokenId;
        _safeMint(to, tokenId);

        emit Minted(to, tokenId);
    }

    function safeMint(MintVoucher calldata voucher, bytes calldata signature) external {
        if (!hasRole(MINTER_ROLE, recoverMintVoucher(voucher, signature))) revert InvalidSignature();
        if (voucher.recipientNonce != _useNonce(voucher.recipient)) revert InvalidNonce();
        if (block.timestamp >= voucher.expiresAt) revert ExpiredVoucher();

        uint256 tokenId = ++nextTokenId;
        _safeMint(voucher.recipient, tokenId);

        emit Minted(voucher.recipient, tokenId);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  UPGRADING  --------------------------------------
    //--------------------------------------------------------------------------------------

    function safeUpgrade(UpgradeVoucher calldata voucher, bytes calldata signature) external {
        _requireOwned(voucher.tokenId);
        if (!hasRole(MINTER_ROLE, recoverUpgradeVoucher(voucher, signature))) revert InvalidSignature();
        if (block.timestamp >= voucher.expiresAt) revert ExpiredVoucher();
        if (stages[voucher.tokenId] >= voucher.stage) revert InvalidStage();

        stages[voucher.tokenId] = voucher.stage;
        avatars[voucher.tokenId] = voucher.avatar;

        emit Upgraded(voucher.tokenId, voucher.stage);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  ADMIN  ----------------------------------------
    //--------------------------------------------------------------------------------------

    function setBaseURI(string calldata _baseTokenURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (keccak256(bytes(_baseTokenURI)) == keccak256(bytes(baseTokenURI))) revert NoChanges();

        baseTokenURI = _baseTokenURI;

        emit BaseURIChanged(_baseTokenURI);
    }

    //--------------------------------------------------------------------------------------
    //------------------------------- SIGNATURE VERIFICATION -------------------------------
    //--------------------------------------------------------------------------------------

    function recoverMintVoucher(MintVoucher calldata voucher, bytes calldata signature) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("MintVoucher(address recipient,uint256 recipientNonce,uint256 expiresAt)"),
                    voucher.recipient,
                    voucher.recipientNonce,
                    voucher.expiresAt
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        return signer;
    }

    function recoverUpgradeVoucher(UpgradeVoucher calldata voucher, bytes calldata signature)
        public
        view
        returns (address)
    {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("UpgradeVoucher(uint256 tokenId,uint8 stage,uint256 avatar,uint256 expiresAt)"),
                    voucher.tokenId,
                    voucher.stage,
                    voucher.avatar,
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
        if (bytes(baseURI).length == 0) return "";
        if (stages[tokenId] == 0) return string.concat(baseURI, "0");
        return string.concat(baseURI, avatars[tokenId].toString(), "/", stages[tokenId].toString());
    }

    function nonces(address recipient) public view virtual override returns (uint256) {
        return super.nonces(recipient);
    }

    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    function tokensForOwner(address owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory tokens = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                tokens[i] = tokenOfOwnerByIndex(owner, i);
            }
            return tokens;
        }
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

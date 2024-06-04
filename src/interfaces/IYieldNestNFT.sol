// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

interface IYieldNestNFT {
    event Minted(address indexed recipient, uint256 indexed tokenId);
    event Upgraded(uint256 indexed tokenId, uint8 indexed stage);

    struct MintVoucher {
        address recipient;
        uint256 expiresAt;
    }

    struct UpgradeVoucher {
        uint256 tokenId;
        uint8 stage;
        uint256 expiresAt;
    }

    /**
     * @notice Initialize the contract
     * @param defaultAdmin The default admin role
     * @param minter The minter role
     * @param tokenName The token name
     * @param tokenSymbol The token symbol
     * @param baseTokenURI The base token URI
     */
    function initialize(
        address defaultAdmin,
        address minter,
        string memory tokenName,
        string memory tokenSymbol,
        string memory baseTokenURI
    ) external;

    /**
     * @notice recover the signer of a mint voucher
     * @param voucher The mint voucher
     */
    function recoverMintVoucher(MintVoucher memory voucher, bytes calldata signature) external view returns (address);

    /**
     * @notice recover the signer of an upgrade voucher
     * @param voucher The upgrade voucher
     */
    function recoverUpgradeVoucher(UpgradeVoucher memory voucher, bytes calldata signature)
        external
        view
        returns (address);

    /**
     * @notice mint a new NFT with minter role
     * @param to The recipient of the NFT
     */
    function safeMint(address to) external;

    /**
     * @notice mint a new NFT with a mint voucher
     * @param voucher The mint voucher
     */
    function safeMint(MintVoucher memory voucher, bytes calldata signature) external;

    /**
     * @notice upgrade an NFT with an upgrade voucher
     * @param voucher The upgrade voucher
     */
    function safeUpgrade(UpgradeVoucher memory voucher, bytes calldata signature) external;
}

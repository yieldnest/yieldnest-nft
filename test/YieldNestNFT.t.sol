// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldNestNFT} from "../src/YieldNestNFT.sol";
import {IYieldNestNFT} from "../src/interfaces/IYieldNestNFT.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {SigUtils} from "./utils/SigUtils.sol";

contract YieldNestNFTTest is Test {
    //--------------------------------------------------------------------------------------
    //-----------------------------------  VARIABLES  --------------------------------------
    //--------------------------------------------------------------------------------------

    YieldNestNFT internal nft;
    YieldNestNFT internal implementation;
    TransparentUpgradeableProxy internal proxy;
    SigUtils internal sigUtils;

    IYieldNestNFT.MintVoucher internal mintVoucher;
    IYieldNestNFT.UpgradeVoucher internal upgradeVoucher;

    uint256 internal adminPrivateKey;
    uint256 internal minterPrivateKey;
    uint256 internal bobPrivateKey;

    address internal admin;
    address internal minter;
    address internal bob;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETUP  ----------------------------------------
    //--------------------------------------------------------------------------------------

    function setUp() public {
        // Make private keys
        adminPrivateKey = 0x1337;
        minterPrivateKey = 0xB00B5;
        bobPrivateKey = 0xB0B;

        // Make addresses
        admin = vm.addr(adminPrivateKey);
        minter = vm.addr(minterPrivateKey);
        bob = vm.addr(bobPrivateKey);

        // Deploy the implementation and initialize the proxy
        implementation = new YieldNestNFT();
        proxy = new TransparentUpgradeableProxy(address(implementation), address(this), new bytes(0));
        nft = YieldNestNFT(address(proxy));
        nft.initialize(admin, minter, "YieldNestNFT", "ynNFT", "ipfs://nft.yieldnest.finance/");

        // Setup SigUtils
        sigUtils = new SigUtils(nft.DOMAIN_SEPARATOR());

        // Make vouchers
        mintVoucher = IYieldNestNFT.MintVoucher({
            recipient: bob,
            recipientNonce: nft.nonces(bob),
            expiresAt: block.timestamp + 15 minutes
        });
        upgradeVoucher =
            IYieldNestNFT.UpgradeVoucher({tokenId: 1, stage: 1, avatar: 1000, expiresAt: block.timestamp + 15 minutes});

        // Mint a token for upgrade testing
        vm.prank(minter);
        nft.safeMint(admin);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  TESTS  ----------------------------------------
    //--------------------------------------------------------------------------------------

    function test_MintWithMinterRole_NotMinter() public {
        // Calling safeMint without minter role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), nft.MINTER_ROLE()
            )
        );
        nft.safeMint(bob);
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_MintWithMinterRole_Minter() public {
        // Calling safeMint with minter role
        vm.prank(minter);
        nft.safeMint(bob);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_MintWithVoucher_NoSignature() public {
        // Calling safeMint with no signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        nft.safeMint(mintVoucher, new bytes(0));
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_MintWithVoucher_InvalidSignature() public {
        // Calling safeMint with bob's signature instead of minter's
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        vm.expectRevert(IYieldNestNFT.InvalidSignature.selector);
        mintNft(mintVoucher, digest, bobPrivateKey);
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_MintWithVoucher_ExpiredVoucher() public {
        // Calling safeMint with an expired voucher
        mintVoucher.expiresAt = block.timestamp - 1 seconds;
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        vm.expectRevert(IYieldNestNFT.ExpiredVoucher.selector);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_MintWithVoucher_CorrectSignature() public {
        // Calling safeMint with the minter's signature
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_MintWithVoucher_VoucherCanOnlyBeUsedOnce() public {
        // Calling safeMint with the same voucher twice
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 1);
        vm.expectRevert(IYieldNestNFT.InvalidNonce.selector);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_MintWithVoucher_SameUserCanMintMultipleTokensWithDifferentVouchers() public {
        // Calling safeMint with different vouchers as the same user
        uint256 firstNonce = mintVoucher.recipientNonce;
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 1);
        mintVoucher.recipientNonce = nft.nonces(bob);
        uint256 secondNonce = mintVoucher.recipientNonce;
        digest = sigUtils.getTypedDataHash(mintVoucher);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 2);
        assertNotEq(firstNonce, secondNonce);
    }

    function test_MintWithVoucer_InvalidNonce() public {
        // Calling safeMint with an invalid nonce
        mintVoucher.recipientNonce = 1;
        assertNotEq(mintVoucher.recipientNonce, nft.nonces(bob));
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        vm.expectRevert(IYieldNestNFT.InvalidNonce.selector);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_upgradeWithVoucher_NonexistentToken() public {
        // Calling safeUpgrade for a tokenId that's not yet minted
        upgradeVoucher.tokenId = 2;
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 2));
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(2), 0);
    }

    function test_upgradeWithVoucher_NoSignature() public {
        // Calling safeUpgrade with no signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        nft.safeUpgrade(upgradeVoucher, new bytes(0));
        assertEq(nft.stages(1), 0);
    }

    function test_upgradeWithVoucher_InvalidSignature() public {
        // Calling safeUpgrade with bob's signature instead of minter's
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        vm.expectRevert(IYieldNestNFT.InvalidSignature.selector);
        upgradeNft(upgradeVoucher, digest, bobPrivateKey);
        assertEq(nft.stages(1), 0);
    }

    function test_upgradeWithVoucher_ExpiredVoucher() public {
        // Calling safeUpgrade with an expired voucher
        upgradeVoucher.expiresAt = block.timestamp - 1 seconds;
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        vm.expectRevert(IYieldNestNFT.ExpiredVoucher.selector);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 0);
    }

    function test_upgradeWithVoucher_CorrectSignature() public {
        // Calling safeUpgrade with the minter's signature
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
    }

    function test_upgradeWithVoucher_SameStage() public {
        // Calling safeUpgrade with the same voucher twice (same stage)
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
        vm.expectRevert(IYieldNestNFT.InvalidStage.selector);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
    }

    function test_upgradeWithVoucher_IncreaseStage() public {
        // Calling safeUpgrade with stage 1 and then stage 2
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
        upgradeVoucher.stage = 2;
        digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 2);
    }

    function test_upgradeWithVoucher_DecreaseStage() public {
        // Calling safeUpgrade with stage 1 and then stage 0
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
        upgradeVoucher.stage = 0;
        digest = sigUtils.getTypedDataHash(upgradeVoucher);
        vm.expectRevert(IYieldNestNFT.InvalidStage.selector);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
    }


    function test_enumeratingAllTokensOfAUser() public {
        // Mint 3 tokens for Bob
        mintVoucher.recipient = bob;
        mintVoucher.recipientNonce = 0;
        mintVoucher.expiresAt = block.timestamp + 1 days;
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        mintNft(mintVoucher, digest, minterPrivateKey);
        mintVoucher.recipientNonce = 1;
        digest = sigUtils.getTypedDataHash(mintVoucher);
        mintNft(mintVoucher, digest, minterPrivateKey);
        mintVoucher.recipientNonce = 2;
        digest = sigUtils.getTypedDataHash(mintVoucher);
        mintNft(mintVoucher, digest, minterPrivateKey);

        // Check if all tokens are correctly enumerated for Bob
        uint256[] memory bobTokens = nft.tokensForOwner(bob);
        assertEq(bobTokens.length, 3, "Bob should have exactly 3 tokens");

        for (uint256 i = 0; i < bobTokens.length; i++) {
            assertEq(nft.ownerOf(bobTokens[i]), bob, "Bob should be the owner of the token");
        }
    }

    function test_enumeratingNoTokensOfAUser() view public {
        // Check if no tokens are correctly enumerated for Bob
        uint256[] memory bobTokens = nft.tokensForOwner(bob);
        assertEq(bobTokens.length, 0, "Bob should have exactly 0 tokens");
    }

    
    //--------------------------------------------------------------------------------------
    //-----------------------------------  INTERNAL  ---------------------------------------
    //--------------------------------------------------------------------------------------

    function mintNft(IYieldNestNFT.MintVoucher memory voucher, bytes32 digest, uint256 privateKey) internal {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        nft.safeMint(voucher, abi.encodePacked(r, s, v));
    }

    function upgradeNft(IYieldNestNFT.UpgradeVoucher memory voucher, bytes32 digest, uint256 privateKey) internal {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        nft.safeUpgrade(voucher, abi.encodePacked(r, s, v));
    }
}

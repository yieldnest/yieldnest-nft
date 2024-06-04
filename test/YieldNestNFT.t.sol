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

    bytes32 internal DOMAIN_SEPARATOR;

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
        (, string memory name, string memory version, uint256 chainId, address verifyingContract,,) = nft.eip712Domain();
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract
            )
        );
        sigUtils = new SigUtils(DOMAIN_SEPARATOR);

        // Make vouchers
        mintVoucher = IYieldNestNFT.MintVoucher({recipient: bob, expiresAt: block.timestamp + 15 minutes});
        upgradeVoucher = IYieldNestNFT.UpgradeVoucher({tokenId: 1, stage: 1, expiresAt: block.timestamp + 15 minutes});

        // Mint a token for upgrade testing
        vm.prank(minter);
        nft.safeMint(admin);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  TESTS  ----------------------------------------
    //--------------------------------------------------------------------------------------

    function test_MintWithMinterRole_NotMinter() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), nft.MINTER_ROLE()
            )
        );
        nft.safeMint(bob);
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_MintWithMinterRole_Minter() public {
        vm.prank(minter);
        nft.safeMint(bob);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_MintWithVoucher_NoSignature() public {
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        nft.safeMint(mintVoucher, new bytes(0));
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_MintWithVoucher_InvalidSignature() public {
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        vm.expectRevert(IYieldNestNFT.InvalidSignature.selector);
        mintNft(mintVoucher, digest, bobPrivateKey);
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_MintWithVoucher_ExpiredVoucher() public {
        mintVoucher.expiresAt = block.timestamp - 1 seconds;
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        vm.expectRevert(IYieldNestNFT.ExpiredVoucher.selector);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 0);
    }

    function test_MintWithVoucher_CorrectSignature() public {
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        mintNft(mintVoucher, digest, minterPrivateKey);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_upgradeWithVoucher_NonexistentToken() public {
        upgradeVoucher.tokenId = 2;
        bytes32 digest = sigUtils.getTypedDataHash(mintVoucher);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 2));
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(2), 0);
    }

    function test_upgradeWithVoucher_NoSignature() public {
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        nft.safeUpgrade(upgradeVoucher, new bytes(0));
        assertEq(nft.stages(1), 0);
    }

    function test_upgradeWithVoucher_InvalidSignature() public {
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        vm.expectRevert(IYieldNestNFT.InvalidSignature.selector);
        upgradeNft(upgradeVoucher, digest, bobPrivateKey);
        assertEq(nft.stages(1), 0);
    }

    function test_upgradeWithVoucher_ExpiredVoucher() public {
        upgradeVoucher.expiresAt = block.timestamp - 1 seconds;
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        vm.expectRevert(IYieldNestNFT.ExpiredVoucher.selector);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 0);
    }

    function test_upgradeWithVoucher_CorrectSignature() public {
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
    }

    function test_upgradeWithVoucher_SameStage() public {
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
        vm.expectRevert(IYieldNestNFT.InvalidStage.selector);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
    }

    function test_upgradeWithVoucher_IncreaseStage() public {
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
        upgradeVoucher.stage = 2;
        digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 2);
    }

    function test_upgradeWithVoucher_DecreaseStage() public {
        bytes32 digest = sigUtils.getTypedDataHash(upgradeVoucher);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
        upgradeVoucher.stage = 0;
        digest = sigUtils.getTypedDataHash(upgradeVoucher);
        vm.expectRevert(IYieldNestNFT.InvalidStage.selector);
        upgradeNft(upgradeVoucher, digest, minterPrivateKey);
        assertEq(nft.stages(1), 1);
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

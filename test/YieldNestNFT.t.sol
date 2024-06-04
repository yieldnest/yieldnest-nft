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
    YieldNestNFT internal nft;
    YieldNestNFT internal implementation;
    TransparentUpgradeableProxy internal proxy;

    uint256 internal adminPrivateKey;
    uint256 internal minterPrivateKey;
    uint256 internal bobPrivateKey;

    address internal admin;
    address internal minter;
    address internal bob;

    bytes32 internal DOMAIN_SEPARATOR;

    SigUtils internal sigUtils;

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
        nft.initialize(admin, minter, "YieldNestNFT", "YieldNestNFT", "https://nft.yieldnest.finance/");

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
    }

    function test_MintWithMinterRole() public {
        // Not minter
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), nft.MINTER_ROLE()
            )
        );
        nft.safeMint(bob);
        assertEq(nft.balanceOf(bob), 0);

        // Minter
        vm.prank(minter);
        nft.safeMint(bob);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_MintWithVoucher() public {
        IYieldNestNFT.MintVoucher memory voucher =
            IYieldNestNFT.MintVoucher({recipient: bob, expiresAt: block.timestamp + 15 minutes});

        // No signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        nft.safeMint(voucher, new bytes(0));
        assertEq(nft.balanceOf(bob), 0);

        // Wrong signature
        bytes32 digest = sigUtils.getTypedDataHash(voucher);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        vm.expectRevert("Wrong signature");
        nft.safeMint(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.balanceOf(bob), 0);

        // Correct but expired signature
        voucher.expiresAt = block.timestamp - 1 seconds;
        digest = sigUtils.getTypedDataHash(voucher);
        (v, r, s) = vm.sign(minterPrivateKey, digest);
        vm.expectRevert("Signature has expired");
        nft.safeMint(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.balanceOf(bob), 0);

        // Correct signature
        voucher.expiresAt = block.timestamp + 15 minutes;
        digest = sigUtils.getTypedDataHash(voucher);
        (v, r, s) = vm.sign(minterPrivateKey, digest);
        nft.safeMint(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_upgradeWithVoucher() public {
        IYieldNestNFT.UpgradeVoucher memory voucher =
            IYieldNestNFT.UpgradeVoucher({tokenId: 1, stage: 1, expiresAt: block.timestamp + 15 minutes});

        // Non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        nft.safeUpgrade(voucher, new bytes(0));

        // Mint a token
        vm.prank(minter);
        nft.safeMint(bob);

        // No signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 0));
        nft.safeUpgrade(voucher, new bytes(0));
        assertEq(nft.stages(1), 0);

        // Wrong signature
        bytes32 digest = sigUtils.getTypedDataHash(voucher);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        vm.expectRevert("Wrong signature");
        nft.safeUpgrade(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.stages(1), 0);

        // Expired signature
        voucher.expiresAt = block.timestamp - 1 seconds;
        digest = sigUtils.getTypedDataHash(voucher);
        (v, r, s) = vm.sign(minterPrivateKey, digest);
        vm.expectRevert("Signature has expired");
        nft.safeUpgrade(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.stages(1), 0);

        // Correct signature
        voucher.expiresAt = block.timestamp + 15 minutes;
        digest = sigUtils.getTypedDataHash(voucher);
        (v, r, s) = vm.sign(minterPrivateKey, digest);
        nft.safeUpgrade(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.stages(1), 1);

        // Invalid stage (same stage)
        digest = sigUtils.getTypedDataHash(voucher);
        (v, r, s) = vm.sign(minterPrivateKey, digest);
        vm.expectRevert("Invalid stage");
        nft.safeUpgrade(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.stages(1), 1);

        // Increase stage
        voucher.stage = 2;
        digest = sigUtils.getTypedDataHash(voucher);
        (v, r, s) = vm.sign(minterPrivateKey, digest);
        nft.safeUpgrade(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.stages(1), 2);

        // Decrease stage
        voucher.stage = 1;
        digest = sigUtils.getTypedDataHash(voucher);
        (v, r, s) = vm.sign(minterPrivateKey, digest);
        vm.expectRevert("Invalid stage");
        nft.safeUpgrade(voucher, abi.encodePacked(r, s, v));
        assertEq(nft.stages(1), 2);
    }
}

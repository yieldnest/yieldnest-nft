// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {IYieldNestNFT} from "../../src/interfaces/IYieldNestNFT.sol";

contract SigUtils {
    bytes32 internal immutable DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    function getStructHash(IYieldNestNFT.MintVoucher memory voucher) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("MintVoucher(address recipient,uint256 recipientNonce,uint256 expiresAt)"),
                voucher.recipient,
                voucher.recipientNonce,
                voucher.expiresAt
            )
        );
    }

    function getTypedDataHash(IYieldNestNFT.MintVoucher memory voucher) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(voucher)));
    }

    function getStructHash(IYieldNestNFT.UpgradeVoucher memory voucher) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("UpgradeVoucher(uint256 tokenId,uint8 stage,uint256 avatar,uint256 expiresAt)"),
                voucher.tokenId,
                voucher.stage,
                voucher.avatar,
                voucher.expiresAt
            )
        );
    }

    function getTypedDataHash(IYieldNestNFT.UpgradeVoucher memory voucher) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(voucher)));
    }
}

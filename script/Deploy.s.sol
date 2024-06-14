// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {YieldNestNFT} from "../src/YieldNestNFT.sol";
import {ActorAddresses} from "script/Actors.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";

contract DeployYieldNestNFT is Script {
    YieldNestNFT internal nft;
    YieldNestNFT internal implementation;
    TransparentUpgradeableProxy internal proxy;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        ActorAddresses.Actors memory actors = (new ActorAddresses()).getActors(block.chainid);

        address _broadcaster = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Admin Address:", actors.admin.ADMIN);
        console.log("Minter Address:", actors.admin.MINTER);
        console.log("Default Signer Address:", _broadcaster);
        console.log("Current Block Number:", block.number);
        console.log("Current Chain ID:", block.chainid);

        implementation = new YieldNestNFT();
        proxy = new TransparentUpgradeableProxy(address(implementation), actors.admin.PROXY_ADMIN_OWNER, new bytes(0));
        nft = YieldNestNFT(address(proxy));
        nft.initialize(
            actors.admin.ADMIN, actors.admin.MINTER, "YieldNest Pioneer", "ynNFT", "https://assets.yieldnest.finance/pioneer/"
        );

        vm.stopBroadcast();
    }
}

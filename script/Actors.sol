// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

contract ActorAddresses {
    struct AdminActors {
        address ADMIN;
        address MINTER;
        address PROXY_ADMIN_OWNER;
    }

    struct Wallets {
        address YNSecurityCouncil;
        address Minter;
    }

    struct Actors {
        AdminActors admin;
        Wallets wallets;
    }

    mapping(uint256 => Actors) public actors;

    constructor() {
        Wallets memory holeskyWallets = Wallets({
            YNSecurityCouncil: 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913,
            Minter: 0xeF444ABe7cf8fFd94dcBE5e4e1F461C2b4c817E3
        });

        actors[17000] = Actors({
            admin: AdminActors({
                PROXY_ADMIN_OWNER: holeskyWallets.YNSecurityCouncil,
                ADMIN: holeskyWallets.YNSecurityCouncil,
                MINTER: holeskyWallets.Minter
            }),
            wallets: holeskyWallets
        });

        Wallets memory mainnetWallets = Wallets({
            YNSecurityCouncil: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            Minter: 0x0927fBD231be6A2d305f566e6D2999449B1f3f85
        });

        actors[1] = Actors({
            admin: AdminActors({
                PROXY_ADMIN_OWNER: mainnetWallets.YNSecurityCouncil,
                ADMIN: mainnetWallets.YNSecurityCouncil,
                MINTER: mainnetWallets.Minter
            }),
            wallets: mainnetWallets
        });
    }

    function getActors(uint256 chainId) external view returns (Actors memory) {
        return actors[chainId];
    }
}

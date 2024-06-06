// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;
contract ActorAddresses {
    struct EOAActors {
        address DEFAULT_SIGNER;
        address DEPOSIT_BOOTSTRAPPER;
    }

    struct AdminActors {
        address ADMIN;
        address MINTER;
        address PROXY_ADMIN_OWNER;
    }

    struct Wallets {
        address YNSecurityCouncil;
        address YNDev;
    }

    struct Actors {
        EOAActors eoa;
        AdminActors admin;
        Wallets wallets;
    }

    mapping(uint256 => Actors) public actors;

    constructor() {

        Wallets memory holeskyWallets = Wallets({
            YNSecurityCouncil: 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913,
            YNDev: 0x9Dd8F69b62ddFd990241530F47dcEd0Dad7f7d39
        });

        actors[17000] = Actors({
            eoa: EOAActors({
                DEFAULT_SIGNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
                DEPOSIT_BOOTSTRAPPER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5
            }),
            admin: AdminActors({
                PROXY_ADMIN_OWNER: holeskyWallets.YNSecurityCouncil,
                ADMIN: holeskyWallets.YNSecurityCouncil,
                MINTER: holeskyWallets.YNDev
            }),
            wallets: holeskyWallets
        });

        Wallets memory mainnetWallets = Wallets({
            YNSecurityCouncil: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            YNDev: 0xa08F39d30dc865CC11a49b6e5cBd27630D6141C3
        });

        actors[1] = Actors({
            eoa: EOAActors({
                DEFAULT_SIGNER: 0xa1E340bd1e3ea09B3981164BBB4AfeDdF0e7bA0D,
                DEPOSIT_BOOTSTRAPPER: 0x67a114e733b52CAC50A168F02b5626f500801C62
            }),
            admin: AdminActors({
                PROXY_ADMIN_OWNER: holeskyWallets.YNSecurityCouncil,
                ADMIN: mainnetWallets.YNSecurityCouncil,
                MINTER: mainnetWallets.YNDev
            }),
            wallets: mainnetWallets
        });
    }

    function getActors(uint256 chainId) external view returns (Actors memory) {
        return actors[chainId];
    }
}
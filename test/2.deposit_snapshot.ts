import { expect } from './shared/expect'
import { ethers } from 'hardhat'
import { BigNumber, Signer } from 'ethers'

import {
    tonStakingV2Fixture,
    lastSeigBlock,
    globalWithdrawalDelay,
    seigManagerInfo,
    jsonFixtures
} from './shared/fixtures'

import { TonStakingV2Fixtures, JSONFixture } from './shared/fixtureInterfaces'
import { padLeft } from 'web3-utils'
import { marshalString, unmarshalString } from './shared/marshal';

function roundDown(val: BigNumber, decimals: number) {
    return ethers.utils.formatUnits(val, decimals).split(".")[0]
}

async function execAllowance(contract: any, fromSigner: Signer, toAddress: string, amount: BigNumber) {
    let fromAddress = await fromSigner.getAddress();
    let allowance = await contract.allowance(fromAddress, toAddress);
    if (allowance.lt(amount)) {
        await contract.connect(fromSigner).approve(toAddress, amount);
    }
}

describe('New Simple Staking Test', () => {
    let deployer: Signer, addr1: Signer, addr2: Signer;
    let deployed: TonStakingV2Fixtures
    let jsonInfo: JSONFixture
    let layer2Info_level19: any;
    let layer2Info_tokamak: any;
    let Operator: any;
    let Candidate: any;
    let snapshotInfo: any;

    before('create fixture loader', async () => {
        deployed = await tonStakingV2Fixture()
        jsonInfo = await jsonFixtures()

        deployer = deployed.deployer;
        addr1 = deployed.addr1;
        addr2 = deployed.addr2;
        layer2Info_level19 = {
            operatorAdmin: deployed.level19Admin,
            isLayer2Candidate: false,
            name: "level19_V2",
            committee: deployed.daoCommittee.address,
            layer2: null,
            operator: null,
            layerContract: null,
            coinageContract: null
        }

        layer2Info_tokamak = {
            operatorAdmin: deployed.tokamakAdmin,
            isLayer2Candidate: false,
            name: "tokamak_V2",
            committee: deployed.daoCommittee.address,
            layer2: null,
            operator: null,
            layerContract: null,
            coinageContract: null
        }

        snapshotInfo = {
            account: null,
            snapshotId: null,
            totTotalSupply: ethers.constants.Zero,
            accountBalanceOfLayer2: ethers.constants.Zero,
            accountBalanceOfTotal: ethers.constants.Zero,
        }

        console.log('deployed.daoCommittee.address:', deployed.daoCommittee.address);
        console.log('deployed.level19Admin:', deployed.level19Admin);
        console.log('deployed.tokamakAdmin:', deployed.tokamakAdmin);

    })


    describe('New SeigManager ', () => {
        it('check storages', async () => {
            expect(await deployed.seigManagerV2.factory()).to.be.eq(deployed.coinageFactoryV2.address)
            expect(await deployed.seigManagerV2.registry()).to.be.eq(deployed.layer2RegistryProxy.address)
            expect(await deployed.seigManagerV2.depositManager()).to.be.eq(deployed.depositManagerV2.address)
            expect(await deployed.seigManagerV2.ton()).to.be.eq(deployed.TON.address)
            expect(await deployed.seigManagerV2.wton()).to.be.eq(deployed.WTON.address)

            expect(await deployed.seigManagerV2.powerton()).to.be.eq(deployed.powerTonAddress)
            expect(await deployed.seigManagerV2.minimumAmount()).to.be.eq(seigManagerInfo.minimumAmount)
            expect(await deployed.seigManagerV2.powerTONSeigRate()).to.be.eq(seigManagerInfo.powerTONSeigRate)
            expect(await deployed.seigManagerV2.daoSeigRate()).to.be.eq(seigManagerInfo.daoSeigRate)
            expect(await deployed.seigManagerV2.relativeSeigRate()).to.be.eq(seigManagerInfo.relativeSeigRate)
            expect(await deployed.seigManagerV2.paused()).to.be.eq(false)

            expect(await deployed.seigManagerV2.tot()).to.be.not.eq(ethers.constants.AddressZero)
            expect(await deployed.seigManagerV2.seigPerBlock()).to.be.eq(seigManagerInfo.seigPerBlock)
            expect(await deployed.seigManagerV2.lastSeigBlock()).to.be.eq(lastSeigBlock)
        })
    });

    describe('New DepositManager', () => {
        it('check storages', async () => {
            expect(await deployed.depositManagerV2.wton()).to.equal(deployed.WTON.address);
            expect(await deployed.depositManagerV2.registry()).to.equal(deployed.layer2RegistryV2.address);
            expect(await deployed.depositManagerV2.seigManager()).to.equal(deployed.seigManagerV2.address);
            expect(await deployed.depositManagerV2.globalWithdrawalDelay()).to.equal(globalWithdrawalDelay);
        });
    });

    describe('New Layer2Registry ', () => {
        it('check storages', async () => {
            expect(await deployed.layer2RegistryV2.numLayer2s()).to.be.eq(ethers.constants.Zero)
        })
    });

    describe('DepositManager v1 ', () => {
        it('deposit will be reverted ', async () => {
            let layer2Address = deployed.level19Address
            let tonAmount = ethers.utils.parseEther("100")
            await deployed.TON.connect(deployer).transfer(await addr1.getAddress(), tonAmount);

            const data = marshalString(
                [deployed.depositManagerV1.address, layer2Address]
                    .map(unmarshalString)
                    .map(str => padLeft(str, 64))
                    .join(''),
            );

            await expect(
                deployed.TON.connect(addr1).approveAndCall(
                    deployed.WTON.address,
                    tonAmount,
                    data,
                    { from: await addr1.getAddress() }
                )).to.be.reverted;
        });

        it('deposit(address,uint256) will be reverted ', async () => {
            let layer2Address = deployed.level19Address;
            let wtonAmount = ethers.utils.parseEther("100" + "0".repeat(9));
            await deployed.WTON.connect(deployer).transfer(await addr1.getAddress(), wtonAmount);

            const beforeBalance = await deployed.WTON.balanceOf(await addr1.getAddress());
            expect(beforeBalance).to.be.gte(wtonAmount);

            await execAllowance(deployed.WTON, addr1, deployed.depositManagerV2.address, wtonAmount);

            await expect(
                deployed.depositManagerV2.connect(addr1)["deposit(address,uint256)"](
                    layer2Address,
                    wtonAmount
                )
            ).to.be.reverted;
        });
    });

    describe('candidate', () => {
        it('create candidate of level19 by daoCommitteeAdmin', async () => {
            try {
                const receipt = await (await deployed.daoCommittee.connect(
                    deployed.daoCommitteeAdmin
                )["createCandidate(string,address)"](
                    layer2Info_level19.name,
                    layer2Info_level19.operatorAdmin,
                    { gasLimit: 5000000 } // Specify a manual gas limit
                )).wait();

                const topic = ethers.utils.id('CandidateContractCreated(address,address,string)');
                const log = receipt.logs.find((x: { topics: string | any[]; }) => x.topics.indexOf(topic) >= 0);
                if (!log) {
                    throw new Error("CandidateContractCreated event not found in logs");
                }
                const iface = new ethers.utils.Interface([
                    "event CandidateContractCreated(address indexed candidateContract, address indexed candidate, string memo)"
                ]);
                const deployedEvent = iface.parseLog(log);
                layer2Info_level19.layer2 = deployedEvent.args.candidateContract;
                layer2Info_level19.operator = deployedEvent.args.candidate;
                console.log('layer2Info_level19.layer2:', layer2Info_level19.layer2);
                console.log('layer2Info_level19.operator:', layer2Info_level19.operator);
                expect(deployedEvent.args.memo).to.be.eq(layer2Info_level19.name);
                expect(layer2Info_level19.operator).to.be.eq(layer2Info_level19.operatorAdmin);
                expect(await deployed.layer2RegistryV2.numLayer2s()).to.be.eq(ethers.constants.One);
            } catch (error) {
                if (error instanceof Error && error.message.includes('already migrated')) {
                    console.log('Contract already migrated, retrieving existing layer2 address.');
                    // Utiliser la méthode getLayer2ByName pour récupérer l'adresse existante
                    const existingLayer2 = await deployed.layer2RegistryV2.getLayer2ByName(layer2Info_level19.name);
                    layer2Info_level19.layer2 = existingLayer2;
                    console.log('Retrieved existing layer2Info_level19.layer2:', layer2Info_level19.layer2);
                } else {
                    throw error;
                }
            }
        });

        it('create candidate of tokamak', async () => {
            try {
                const receipt = await (await deployed.daoCommittee.connect(
                    deployed.daoCommitteeAdmin
                )["createCandidate(string,address)"](
                    layer2Info_tokamak.name,
                    layer2Info_tokamak.operatorAdmin,
                    { gasLimit: 5000000 } // Specify a manual gas limit
                )).wait();

                const topic = ethers.utils.id('CandidateContractCreated(address,address,string)');
                const log = receipt.logs.find((x: { topics: string | any[]; }) => x.topics.indexOf(topic) >= 0);
                if (!log) {
                    throw new Error("CandidateContractCreated event not found in logs");
                }
                const iface = new ethers.utils.Interface([
                    "event CandidateContractCreated(address indexed candidateContract, address indexed candidate, string memo)"
                ]);
                const deployedEvent = iface.parseLog(log);
                layer2Info_tokamak.layer2 = deployedEvent.args.candidateContract;
                layer2Info_tokamak.operator = deployedEvent.args.candidate;
                console.log('layer2Info_tokamak.layer2:', layer2Info_tokamak.layer2);
                console.log('layer2Info_tokamak.operator:', layer2Info_tokamak.operator);
                expect(deployedEvent.args.memo).to.be.eq(layer2Info_tokamak.name);
                expect(layer2Info_tokamak.operator).to.be.eq(layer2Info_tokamak.operatorAdmin);
                expect(await deployed.layer2RegistryV2.numLayer2s()).to.be.eq(BigNumber.from("2"));
            } catch (error) {
                if (error instanceof Error && error.message.includes('already migrated')) {
                    console.log('Contract already migrated, retrieving existing layer2 address.');
                    // Retrieve the existing layer2 address
                    const existingLayer2 = await deployed.layer2RegistryV2.getLayer2ByName(layer2Info_tokamak.name);
                    layer2Info_tokamak.layer2 = existingLayer2;
                    console.log('Retrieved existing layer2Info_tokamak.layer2:', layer2Info_tokamak.layer2);
                } else {
                    throw error;
                }
            }
        });
    });


    describe('basic functions ', () => {
        it('deposit to level19 using approveAndCall', async () => {
            console.log('layer2Info_level19.layer2 before deposit:', layer2Info_level19.layer2);
            let tonAmount = ethers.utils.parseEther("100");
            await deployed.TON.connect(deployer).transfer(await addr1.getAddress(), tonAmount);

            const beforeBalance = await deployed.TON.balanceOf(await addr1.getAddress());
            expect(beforeBalance).to.be.gte(tonAmount);

            let stakedA = await deployed.seigManagerV2["stakeOf(address,address)"](layer2Info_level19.layer2, addr1.getAddress());

            const data = marshalString(
                [deployed.depositManagerV2.address, layer2Info_level19.layer2]
                    .map(unmarshalString)
                    .map(str => padLeft(str, 64))
                    .join(''),
            );

            await deployed.TON.connect(addr1).approveAndCall(
                deployed.WTON.address,
                tonAmount,
                data,
                { from: await addr1.getAddress() }
            );

            const afterBalance = await deployed.TON.balanceOf(await addr1.getAddress());
            expect(afterBalance).to.be.eq(beforeBalance.sub(tonAmount));

            let stakedB = await deployed.seigManagerV2["stakeOf(address,address)"](layer2Info_level19.layer2, addr1.getAddress());

            expect(roundDown(BigNumber.from(stakedB).add(ethers.constants.Two), 1)).to.be.eq(
                roundDown(BigNumber.from(stakedA).add(tonAmount.mul(BigNumber.from("1000000000"))), 1)
            );
        })

        it('deposit to tokamak using approveAndCall', async () => {
            let tonAmount = ethers.utils.parseEther("100")
            await deployed.TON.connect(deployer).transfer(await addr1.getAddress(), tonAmount);

            const beforeBalance = await deployed.TON.balanceOf(await addr1.getAddress());
            expect(beforeBalance).to.be.gte(tonAmount)

            let stakedA = await deployed.seigManagerV2["stakeOf(address,address)"](layer2Info_tokamak.layer2, addr1.getAddress())

            const data = marshalString(
                [deployed.depositManagerV2.address, layer2Info_tokamak.layer2]
                    .map(unmarshalString)
                    .map(str => padLeft(str, 64))
                    .join(''),
            );

            await deployed.TON.connect(addr1).approveAndCall(
                deployed.WTON.address,
                tonAmount,
                data,
                { from: await addr1.getAddress() }
            );

            const afterBalance = await deployed.TON.balanceOf(await addr1.getAddress());
            expect(afterBalance).to.be.eq(beforeBalance.sub(tonAmount))

            let stakedB = await deployed.seigManagerV2["stakeOf(address,address)"](layer2Info_tokamak.layer2, addr1.getAddress())

            expect(roundDown(BigNumber.from(stakedB).add(ethers.constants.Two), 1)).to.be.eq(
                roundDown(BigNumber.from(stakedA).add(tonAmount.mul(BigNumber.from("1000000000"))), 1)
            )
        })

        it('deposit to level19', async () => {

            let layer2 = layer2Info_level19.layer2
            let account = addr1

            let wtonAmount = ethers.utils.parseEther("100" + "0".repeat(9))
            await deployed.WTON.connect(deployer).transfer(await account.getAddress(), wtonAmount);

            const beforeBalance = await deployed.WTON.balanceOf(await account.getAddress());
            expect(beforeBalance).to.be.gte(wtonAmount)

            await execAllowance(deployed.WTON, account, deployed.depositManagerV2.address, wtonAmount);

            let stakedA = await deployed.seigManagerV2["stakeOf(address,address)"](layer2Info_level19.layer2, addr1.getAddress())

            await deployed.depositManagerV2.connect(account)["deposit(address,uint256)"](
                layer2,
                wtonAmount
            );

            const afterBalance = await deployed.WTON.balanceOf(await account.getAddress());
            expect(afterBalance).to.be.eq(beforeBalance.sub(wtonAmount))

            let stakedB = await deployed.seigManagerV2["stakeOf(address,address)"](layer2Info_level19.layer2, addr1.getAddress())

            expect(roundDown(BigNumber.from(stakedB).add(ethers.constants.Two), 1)).to.be.eq(
                roundDown(BigNumber.from(stakedA).add(wtonAmount), 1)
            )
        })

        it('updateSeigniorage to level19 will fail when minimumAmount is insufficient.', async () => {
            await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 7]);
            await ethers.provider.send("evm_mine", []);

            layer2Info_level19.layerContract = new ethers.Contract(
                layer2Info_level19.layer2, jsonInfo.Candidate.abi, deployer
            );

            await expect(
                layer2Info_level19.layerContract.connect(addr1).updateSeigniorage()
            ).to.be.revertedWith("minimumAmount is insufficient");
        });

        it('requestWithdrawal from level19', async () => {
            let layer2 = layer2Info_level19.layer2
            let account = addr1

            let wtonAmount = ethers.utils.parseEther("100" + "0".repeat(9))
            await deployed.WTON.connect(deployer).transfer(await account.getAddress(), wtonAmount);

            const beforeBalance = await deployed.WTON.balanceOf(await account.getAddress());
            expect(beforeBalance).to.be.gte(wtonAmount)

            await execAllowance(deployed.WTON, account, deployed.depositManagerV2.address, wtonAmount);

            await (await deployed.depositManagerV2.connect(account).requestWithdrawal(
                layer2,
                wtonAmount
            )).wait();

            const afterBalance = await deployed.WTON.balanceOf(await account.getAddress());
            expect(afterBalance).to.be.eq(beforeBalance.sub(wtonAmount))
        });

        it('processRequest from level19 will fail due to withdrawal delay', async () => {
            let layer2 = layer2Info_level19.layer2
            let account = addr1

            let wtonAmount = ethers.utils.parseEther("100" + "0".repeat(9))
            await deployed.WTON.connect(deployer).transfer(await account.getAddress(), wtonAmount);

            const beforeBalance = await deployed.WTON.balanceOf(await account.getAddress());
            expect(beforeBalance).to.be.gte(wtonAmount)

            await execAllowance(deployed.WTON, account, deployed.depositManagerV2.address, wtonAmount);

            await deployed.depositManagerV2.connect(account)["deposit(address,uint256)"](
                layer2,
                wtonAmount
            );

            await (await deployed.depositManagerV2.connect(account).requestWithdrawal(
                layer2,
                wtonAmount
            )).wait();

            await expect(
                deployed.depositManagerV2.connect(account).processRequest(
                    layer2,
                    true
                )
            ).to.be.revertedWith("DepositManager: wait for withdrawal delay");
        });
    });
});


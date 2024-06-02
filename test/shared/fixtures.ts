import hre from 'hardhat';
import { ethers, deployments, getNamedAccounts, network } from 'hardhat';
import { readContracts, deployedContracts } from "../common_func";
import { Wallet, Signer, Contract, BigNumber } from 'ethers';
import { TonStakingV2Fixtures, NewTonStakingV2Fixtures2, TonStakingV2NoSnapshotFixtures, JSONFixture } from './fixtureInterfaces';
import { DepositManagerForMigration } from "../../typechain/contracts/stake/managers/DepositManagerForMigration.sol";
import { DepositManager } from "../../typechain/contracts/stake/managers/DepositManager.sol";
import { DepositManagerProxy } from "../../typechain/contracts/stake/managers/DepositManagerProxy";
import { SeigManager } from "../../typechain/contracts/stake/managers/SeigManager.sol";
import { SeigManagerV1_1 } from "../../typechain/contracts/stake/managers/SeigManagerV1_1.sol";
import { SeigManagerMigration } from "../../typechain/contracts/stake/managers/SeigManagerMigration.sol";
import { SeigManagerProxy } from "../../typechain/contracts/stake/managers/SeigManagerProxy";
import { Layer2Registry } from "../../typechain/contracts/stake/Layer2Registry.sol";
import { Layer2RegistryProxy } from "../../typechain/contracts/stake/Layer2RegistryProxy";
import { CoinageFactory } from "../../typechain/contracts/stake/factory/CoinageFactory.sol";
import { AutoRefactorCoinageFactory } from "../../typechain/contracts/stake/factory/AutoRefactorCoinageFactory.sol";
import { RefactorCoinageSnapshot } from "../../typechain/contracts/stake/tokens/RefactorCoinageSnapshot.sol";
import { AutoRefactorCoinage } from "../../typechain/contracts/stake/tokens/AutoRefactorCoinage";
import { Candidate } from "../../typechain/contracts/dao/Candidate.sol";
import { CandidateProxy } from "../../typechain/contracts/dao/CandidateProxy";
import { DAOCommitteeExtend } from "../../typechain/contracts/dao/DAOCommitteeExtend.sol";
import { CandidateFactory } from "../../typechain/contracts/dao/factory/CandidateFactory.sol";
import { CandidateFactoryProxy } from "../../typechain/contracts/dao/factory/CandidateFactoryProxy";
import { PowerTONUpgrade } from "../../typechain/contracts/stake/powerton/PowerTONUpgrade";
import DepositManager_Json from '../abi/DepositManager.json';
import SeigManager_Json from '../../artifacts/contracts/stake/managers/SeigManager.sol/SeigManager.json';
import L2Registry_Json from '../abi/Layer2Registry.json';
import CoinageFactory_Json from '../abi/CoinageFactory.json';
import Ton_Json from '../abi/TON.json';
import Wton_Json from '../abi/WTON.json';
import Tos_Json from '../abi/TOS.json';
import DAOCommitteeProxy_Json from '../abi/DAOCommitteeProxy.json';
import CandidateFactory_Json from '../abi/CandidateFactory.json';
import DAOAgendaManager_Json from '../abi/DAOAgendaManager.json';
import RefactorCoinageSnapshot_Json from '../../artifacts/contracts/stake/tokens/RefactorCoinageSnapshot.sol/RefactorCoinageSnapshot.json';
import DAOCommittee_Json from '../abi/DAOCommittee.json';
import DAOCommitteeExtend_Json from '../abi/DAOCommitteeExtend.json';
import Candidate_Json from '../../artifacts/contracts/dao/Candidate.sol/Candidate.json';
import PowerTON_Json from '../abi/PowerTONSwapperProxy.json';

export const lastSeigBlock = ethers.BigNumber.from("18169346");
export const globalWithdrawalDelay = ethers.BigNumber.from("93046");

export const seigManagerInfo = {
  minimumAmount: ethers.BigNumber.from("1000000000000000000000000000000"),
  powerTONSeigRate: ethers.BigNumber.from("100000000000000000000000000"),
  relativeSeigRate: ethers.BigNumber.from("400000000000000000000000000"),
  daoSeigRate: ethers.BigNumber.from("500000000000000000000000000"),
  seigPerBlock: ethers.BigNumber.from("3920000000000000000000000000"),
  adjustCommissionDelay: ethers.BigNumber.from("93096"),
};

export const jsonFixtures = async function (): Promise<JSONFixture> {
  return {
    DepositManager: DepositManager_Json,
    SeigManager: SeigManager_Json,
    L2Registry: L2Registry_Json,
    CoinageFactory: CoinageFactory_Json,
    TON: Ton_Json,
    WTON: Wton_Json,
    TOS: Tos_Json,
    DAOCommitteeProxy: DAOCommitteeProxy_Json,
    CandidateFactory: CandidateFactory_Json,
    DAOAgendaManager: DAOAgendaManager_Json,
    RefactorCoinageSnapshot: RefactorCoinageSnapshot_Json,
    Candidate: Candidate_Json,
    PowerTON: PowerTON_Json,
  };
};

export const tonStakingV2Fixture = async function (): Promise<TonStakingV2Fixtures> {
  const [deployer, addr1, addr2] = await ethers.getSigners();
  const {
    DepositManager, SeigManager, L2Registry, CoinageFactory, TON, WTON, TOS, DAOCommitteeProxy,
    CandidateFactory, DAOAgendaManager, AutoCoinageSnapshot2, DaoCommitteeAdminAddress,
    powerTonAddress, daoVaultAddress,
    level19Address, level19Admin, tokamakAddress, tokamakAdmin,
    powerTonAdminAddress,
  } = await hre.getNamedAccounts();

  const contractJson = await jsonFixtures();

  const deployerSigner = deployer as unknown as Signer;
  const addr1Signer = addr1 as unknown as Signer;
  const addr2Signer = addr2 as unknown as Signer;

  //-------------------------------
  const depositManagerV1 = new ethers.Contract(DepositManager, contractJson.DepositManager.abi, deployerSigner);
  const seigManagerV1 = new ethers.Contract(SeigManager, contractJson.SeigManager.abi, deployerSigner);
  const layer2RegistryV1 = new ethers.Contract(L2Registry, contractJson.L2Registry.abi, deployerSigner);
  const coinageFactoryV1 = new ethers.Contract(CoinageFactory, contractJson.CoinageFactory.abi, deployerSigner);
  const TONContract = new ethers.Contract(TON, contractJson.TON.abi, deployerSigner);
  const WTONContract = new ethers.Contract(WTON, contractJson.WTON.abi, deployerSigner);
  const TOSContract = new ethers.Contract(TOS, contractJson.TOS.abi, deployerSigner);
  const candidateFactoryV1 = new ethers.Contract(CandidateFactory, contractJson.CandidateFactory.abi, deployerSigner);
  const daoCommitteeProxy = new ethers.Contract(DAOCommitteeProxy, contractJson.DAOCommitteeProxy.abi, deployerSigner);
  const daoAgendaManager = new ethers.Contract(DAOAgendaManager, contractJson.DAOAgendaManager.abi, deployerSigner);
  const powerTonProxy = new ethers.Contract(powerTonAddress, contractJson.PowerTON.abi, deployerSigner);
  console.log('DAOCommitteeProxy', DAOCommitteeProxy);

  //==========================
  //-- DAOCommittee 로직 업데이트
  //--- 1. change  CandidateFactory in DAOCommittee
  await hre.network.provider.send("hardhat_impersonateAccount", [
    DaoCommitteeAdminAddress,
  ]);
  const daoCommitteeAdmin = await hre.ethers.getSigner(DaoCommitteeAdminAddress);
  const daoCommitteeAdminSigner = daoCommitteeAdmin as unknown as Signer;

  console.log('DaoCommitteeAdminAddress', DaoCommitteeAdminAddress);

  const daoCommitteeExtend = (await (await ethers.getContractFactory("DAOCommitteeExtend")).connect(deployer).deploy()) as unknown as DAOCommitteeExtend;
  await (await daoCommitteeProxy.connect(daoCommitteeAdminSigner).upgradeTo(daoCommitteeExtend.address)).wait();

  const daoCommittee = (await ethers.getContractAt("DAOCommitteeExtend", DAOCommitteeProxy, daoCommitteeAdminSigner)) as unknown as DAOCommitteeExtend;
  console.log('daoCommittee', daoCommittee.address);

  let daoImpl = await daoCommitteeProxy.implementation();
  console.log('daoImpl', daoImpl);

  let pauseProxy = await daoCommitteeProxy.pauseProxy();
  console.log('pauseProxy', pauseProxy);

  //-- 기존 디파짓 매니저의 세그매니저를 0으로 설정한다.
  await (await daoCommittee.connect(daoCommitteeAdminSigner).setTargetSeigManager(
    depositManagerV1.address, ethers.constants.AddressZero)).wait();

  //=====================
  //--파워톤 로직 업데이트
  await hre.network.provider.send("hardhat_impersonateAccount", [
    powerTonAdminAddress,
  ]);
  await hre.network.provider.send("hardhat_setBalance", [
    powerTonAdminAddress,
    "0x10000000000000000000000000",
  ]);
  const powerTonAdmin = await hre.ethers.getSigner(powerTonAdminAddress);
  const powerTonAdminSigner = powerTonAdmin as unknown as Signer;

  const powerTONUpgradeLogic = (await (await ethers.getContractFactory("PowerTONUpgrade")).connect(deployer).deploy()) as unknown as PowerTONUpgrade;
  await (await powerTonProxy.connect(powerTonAdminSigner).upgradeTo(powerTONUpgradeLogic.address)).wait();

  const powerTON = (await ethers.getContractAt("PowerTONUpgrade", powerTonProxy.address, daoCommitteeAdminSigner)) as unknown as PowerTONUpgrade;
  console.log('powerTON', powerTON.address);

  //----------- v2 배포
  const depositManagerV2Imp = (await (await ethers.getContractFactory("DepositManager")).connect(deployer).deploy()) as unknown as DepositManager;
  const depositManagerProxy = (await (await ethers.getContractFactory("DepositManagerProxy")).connect(deployer).deploy()) as unknown as DepositManagerProxy;
  await depositManagerProxy.connect(deployer).upgradeTo(depositManagerV2Imp.address);
  const depositManagerV2 = (await ethers.getContractAt("DepositManager", depositManagerProxy.address, deployerSigner)) as unknown as DepositManager;

  const seigManagerV2Imp = (await (await ethers.getContractFactory("SeigManager")).connect(deployer).deploy()) as unknown as SeigManager;
  const seigManagerProxy = (await (await ethers.getContractFactory("SeigManagerProxy")).connect(deployer).deploy()) as unknown as SeigManagerProxy;
  await seigManagerProxy.connect(deployer).upgradeTo(seigManagerV2Imp.address);
  const seigManagerV2 = (await ethers.getContractAt("SeigManager", seigManagerProxy.address, deployerSigner)) as unknown as SeigManager;

  const layer2RegistryV2Imp = (await (await ethers.getContractFactory("Layer2Registry")).connect(deployer).deploy()) as unknown as Layer2Registry;
  const layer2RegistryProxy = (await (await ethers.getContractFactory("Layer2RegistryProxy")).connect(deployer).deploy()) as unknown as Layer2RegistryProxy;
  await layer2RegistryProxy.connect(deployer).upgradeTo(layer2RegistryV2Imp.address);
  const layer2RegistryV2 = (await ethers.getContractAt("Layer2Registry", layer2RegistryProxy.address, deployerSigner)) as unknown as Layer2Registry;

  const candidateImp = (await (await ethers.getContractFactory("Candidate")).connect(deployer).deploy()) as unknown as Candidate;
  const candidateFactoryLogic = (await (await ethers.getContractFactory("CandidateFactory")).connect(deployer).deploy()) as unknown as CandidateFactory;
  const candidateFactoryProxy = (await (await ethers.getContractFactory("CandidateFactoryProxy")).connect(deployer).deploy()) as unknown as CandidateFactoryProxy;

  await candidateFactoryProxy.connect(deployer).upgradeTo(candidateFactoryLogic.address);
  const candidateFactory = (await ethers.getContractAt("CandidateFactory", candidateFactoryProxy.address, deployerSigner)) as unknown as CandidateFactory;

  await (await daoCommittee.connect(daoCommitteeAdminSigner).setCandidateFactory(candidateFactoryProxy.address)).wait();
  await (await daoCommittee.connect(daoCommitteeAdminSigner).setSeigManager(seigManagerProxy.address)).wait();
  await (await daoCommittee.connect(daoCommitteeAdminSigner).setLayer2Registry(layer2RegistryProxy.address)).wait();

  const refactorCoinageSnapshot = (await (await ethers.getContractFactory("RefactorCoinageSnapshot")).connect(deployer).deploy()) as unknown as RefactorCoinageSnapshot;
  const coinageFactoryV2 = (await (await ethers.getContractFactory("CoinageFactory")).connect(deployer).deploy()) as unknown as CoinageFactory;
  await (await coinageFactoryV2.connect(deployer).setAutoCoinageLogic(refactorCoinageSnapshot.address)).wait();

  console.log('coinageFactoryV2', coinageFactoryV2.address);
  console.log('refactorCoinageSnapshot', refactorCoinageSnapshot.address);

  //====== set v2 ==================

  await (await depositManagerV2.connect(deployer).initialize(
    WTONContract.address,
    layer2RegistryProxy.address,
    seigManagerV2.address,
    globalWithdrawalDelay,
    DepositManager
  )).wait();

  console.log('depositManagerV2 initialized');
  await (await seigManagerV2.connect(deployer).initialize(
    TONContract.address,
    WTONContract.address,
    layer2RegistryProxy.address,
    depositManagerV2.address,
    seigManagerInfo.seigPerBlock,
    coinageFactoryV2.address,
    lastSeigBlock
  )).wait();
  console.log('seigManagerV2 initialized');

  await (await seigManagerV2.connect(deployer).setData(
    powerTonAddress,
    daoVaultAddress,
    seigManagerInfo.powerTONSeigRate,
    seigManagerInfo.daoSeigRate,
    seigManagerInfo.relativeSeigRate,
    seigManagerInfo.adjustCommissionDelay,
    seigManagerInfo.minimumAmount
  )).wait();
  console.log('seigManagerV2 setData');

  await (await layer2RegistryV2.connect(deployer).addMinter(
    daoCommittee.address
  )).wait();

  await (await seigManagerV2.connect(deployer).addMinter(
    layer2RegistryV2.address
  )).wait();

  //==========================
  await hre.network.provider.send("hardhat_impersonateAccount", [
    DAOCommitteeProxy,
  ]);

  await hre.network.provider.send("hardhat_setBalance", [
    DAOCommitteeProxy,
    "0x10000000000000000000000000",
  ]);

  const daoAdmin = await hre.ethers.getSigner(DAOCommitteeProxy);
  const daoAdminSigner = daoAdmin as unknown as Signer;

  // for version 2
  await (await WTONContract.connect(daoAdminSigner).addMinter(seigManagerV2.address)).wait();

  // for test :
  await (await TONContract.connect(daoAdminSigner).mint(deployer.address, ethers.utils.parseEther("10000"))).wait();
  await (await WTONContract.connect(daoAdminSigner).mint(deployer.address, ethers.utils.parseEther("10000" + "0".repeat(9)))).wait();

  //-- v2 배포후에 설정
  await (await candidateFactory.connect(deployer).setAddress(
    depositManagerV2.address,
    DAOCommitteeProxy,
    candidateImp.address,
    TONContract.address,
    WTONContract.address
  )).wait();
  console.log('candidateFactory setAddress');

  return {
    deployer: deployerSigner,
    addr1: addr1Signer,
    addr2: addr2Signer,
    depositManagerV1: depositManagerV1,
    seigManagerV1: seigManagerV1,
    layer2RegistryV1: layer2RegistryV1,
    coinageFactoryV1: coinageFactoryV1,
    powerTonProxy: powerTonProxy,
    TON: TONContract,
    WTON: WTONContract,
    daoCommitteeProxy: daoCommitteeProxy,
    daoAgendaManager: daoAgendaManager,
    candidateFactoryV1: candidateFactoryV1,
    daoCommitteeExtend: daoCommitteeExtend,
    daoCommitteeAdmin: daoCommitteeAdminSigner,
    daoCommittee: daoCommittee,
    depositManagerV2: depositManagerV2,
    depositManagerProxy: depositManagerProxy,
    seigManagerV2: seigManagerV2,
    seigManagerProxy: seigManagerProxy,
    layer2RegistryV2: layer2RegistryV2,
    layer2RegistryProxy: layer2RegistryProxy,
    candidateFactoryV2: candidateFactory,
    candidateFactoryProxy: candidateFactoryProxy,
    candidateImp: candidateImp,
    refactorCoinageSnapshot: refactorCoinageSnapshot,
    coinageFactoryV2: coinageFactoryV2,
    powerTonAddress: powerTonAddress,
    daoVaultAddress: daoVaultAddress,
    level19Address: level19Address,
    tokamakAddress: tokamakAddress,
    level19Admin: level19Admin,
    tokamakAdmin: tokamakAdmin,
    daoAdmin: daoAdminSigner,
    powerTON: powerTON
  };
};


import { expect } from "chai";
import { ethers } from "hardhat";
import { GEMAccessControl } from "../typechain/contracts/tkGEM/GEMAccessControl";

describe("GEMAccessControl", function () {
    let gemAccessControl: GEMAccessControl;
    let deployer: any;
    let addr1: any;
    let addr2: any;

    beforeEach(async function () {
        [deployer, addr1, addr2] = await ethers.getSigners();

        const GEMAccessControlFactory = await ethers.getContractFactory("GEMAccessControl");
        gemAccessControl = await GEMAccessControlFactory.deploy() as GEMAccessControl;
        await gemAccessControl.deployed();
    });

    it("Should set CEO correctly", async function () {
        await gemAccessControl.connect(deployer).setCEO(addr1.address);
        expect(await gemAccessControl.ceoAddress()).to.equal(addr1.address);
    });

    it("Should set CFO correctly", async function () {
        await gemAccessControl.connect(deployer).setCFO(addr1.address);
        expect(await gemAccessControl.cfoAddress()).to.equal(addr1.address);
    });

    it("Should set COO correctly", async function () {
        await gemAccessControl.connect(deployer).setCOO(addr1.address);
        expect(await gemAccessControl.cooAddress()).to.equal(addr1.address);
    });

    it("Should pause and unpause correctly", async function () {
        await gemAccessControl.connect(deployer).pause();
        expect(await gemAccessControl.paused()).to.be.true;

        await gemAccessControl.connect(deployer).unpause();
        expect(await gemAccessControl.paused()).to.be.false;
    });

    it("Should only allow CEO to set CEO", async function () {
        await expect(gemAccessControl.connect(addr1).setCEO(addr2.address)).to.be.reverted;
        await gemAccessControl.connect(deployer).setCEO(addr1.address);
        expect(await gemAccessControl.ceoAddress()).to.equal(addr1.address);
    });

    it("Should only allow CEO to set CFO", async function () {
        await expect(gemAccessControl.connect(addr1).setCFO(addr2.address)).to.be.reverted;
        await gemAccessControl.connect(deployer).setCFO(addr1.address);
        expect(await gemAccessControl.cfoAddress()).to.equal(addr1.address);
    });

    it("Should only allow CEO to set COO", async function () {
        await expect(gemAccessControl.connect(addr1).setCOO(addr2.address)).to.be.reverted;
        await gemAccessControl.connect(deployer).setCOO(addr1.address);
        expect(await gemAccessControl.cooAddress()).to.equal(addr1.address);
    });

    it("Should only allow C-level roles to pause", async function () {
        await expect(gemAccessControl.connect(addr1).pause()).to.be.reverted;
        await gemAccessControl.connect(deployer).setCOO(addr1.address);
        await gemAccessControl.connect(addr1).pause();
        expect(await gemAccessControl.paused()).to.be.true;
    });

    it("Should only allow CEO to unpause", async function () {
        await gemAccessControl.connect(deployer).pause();
        await expect(gemAccessControl.connect(addr1).unpause()).to.be.reverted;
        await gemAccessControl.connect(deployer).unpause();
        expect(await gemAccessControl.paused()).to.be.false;
    });
});

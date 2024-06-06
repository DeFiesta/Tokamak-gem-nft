import { ethers } from "hardhat";
import { expect } from "chai";
import { GEMOwnership, GEMCore, ERC721Metadata } from "../typechain";

describe("GEMOwnership", function () {
    let gemOwnership: GEMOwnership;
    let gemCore: GEMCore;
    let erc721Metadata: ERC721Metadata;
    let owner: any;
    let addr1: any;
    let addr2: any;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        const ERC721MetadataFactory = await ethers.getContractFactory("ERC721Metadata");
        erc721Metadata = (await ERC721MetadataFactory.deploy()) as ERC721Metadata;
        await erc721Metadata.deployed();

        const GEMOwnershipFactory = await ethers.getContractFactory("GEMOwnership");
        gemOwnership = (await GEMOwnershipFactory.deploy()) as GEMOwnership;
        await gemOwnership.deployed();

        const GEMCoreFactory = await ethers.getContractFactory("GEMCore");
        gemCore = (await GEMCoreFactory.deploy(gemOwnership.address, 0, ethers.constants.AddressZero)) as GEMCore;
        await gemCore.deployed();

        await gemOwnership.setMetadataAddress(erc721Metadata.address);
    });

    it("should set the correct metadata address", async function () {
        expect(await gemOwnership.erc721Metadata()).to.equal(erc721Metadata.address);
    });

    it("should create a promo GEM and transfer ownership", async function () {
        await gemCore.createPromoGEM(1, owner.address);
        expect(await gemOwnership.balanceOf(owner.address)).to.equal(1);
    });

    it("should transfer GEM ownership", async function () {
        await gemCore.createPromoGEM(1, owner.address);
        await gemOwnership.transfer(addr1.address, 1);
        expect(await gemOwnership.balanceOf(owner.address)).to.equal(0);
        expect(await gemOwnership.balanceOf(addr1.address)).to.equal(1);
    });

    it("should approve and transfer GEM from another address", async function () {
        await gemCore.createPromoGEM(1, owner.address);
        await gemOwnership.approveGEM(addr1.address, 1);
        await gemOwnership.connect(addr1).transferGEMFrom(owner.address, addr2.address, 1);
        expect(await gemOwnership.balanceOf(owner.address)).to.equal(0);
        expect(await gemOwnership.balanceOf(addr2.address)).to.equal(1);
    });

    it("should return the correct total supply", async function () {
        await gemCore.createPromoGEM(1, owner.address);
        await gemCore.createPromoGEM(2, owner.address);
        expect(await gemOwnership.totalSupply()).to.equal(2);
    });

    it("should return the correct owner of a GEM", async function () {
        await gemCore.createPromoGEM(1, owner.address);
        expect(await gemOwnership.ownerOfGEM(1)).to.equal(owner.address);
    });

    it("should return the correct tokens of an owner", async function () {
        await gemCore.createPromoGEM(1, owner.address);
        await gemCore.createPromoGEM(2, owner.address);
        const tokens = await gemOwnership.tokensOfOwner(owner.address);
        expect(tokens.map((t: any) => t.toNumber())).to.deep.equal([1, 2]);
    });

    it("should return the correct metadata for a token", async function () {
        await gemCore.createPromoGEM(1, owner.address);
        const metadata = await gemOwnership.tokenMetadata(1, "");
        expect(metadata).to.equal("BASIC GEM 1");
    });
});

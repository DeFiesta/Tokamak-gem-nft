const { expect } = require("chai");

describe("NFTBase", function () {
    let base;
    let owner;
    let addr1;
    let addr2;
    let addrs;

    beforeEach(async function () {
        // Get signers
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

        // Deploy the NFTMarketplace contract
        const NFTBase = await ethers.getContractFactory("NFTBase");
        base = await NFTBase.deploy();
        await base.deployed();

    });

    it("Should mint a new NFT, add it to the tkNFTs array, and emit a Minted event", async function () {
        // Prepare the recipient address and NFT attributes
        const recipient = owner.address; // Using the owner's address for simplicity
        const genes = 123456789;
        const birthTime = Math.floor(Date.now() / 1000);
        const matronId = 1;
        const sireId = 2;
        const generation = 1;

        // Call the mint function and wait for the transaction to be mined
        const tx = await base.mintTkNFT(recipient, genes, birthTime, matronId, sireId, generation);
        await tx.wait();

        // Check if the Minted event was emitted
        await expect(tx).to.emit(base, "Minted").withArgs(recipient, 1); // Assuming the first token ID is 1

        // Retrieve the newly minted NFT details
        const tkNFT = await base.tkNFTs(0);

        // Check if the NFT was correctly minted and added to the array
        expect(tkNFT.owner).to.equal(recipient);
        expect(tkNFT.tokenId).to.equal(1);
        expect(tkNFT.genes).to.equal(genes);
        expect(tkNFT.birthTime).to.equal(birthTime);
        expect(tkNFT.matronId).to.equal(matronId);
        expect(tkNFT.sireId).to.equal(sireId);
        expect(tkNFT.generation).to.equal(generation);
    });


    it("Should prevent non-owner accounts from minting", async function () {
        // Attempt to mint a token as a non-owner
        await expect(
            base.connect(addr1).mint(
                addr1.address,
                123456789,
                Math.floor(Date.now() / 1000),
                1,
                2,
                1
            )
        ).to.be.reverted;
    });

});

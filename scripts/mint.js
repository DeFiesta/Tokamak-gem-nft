const hre = require("hardhat");

async function main() {
    const contractAddress = "0xc1126D8525C14e7D2efe62f61DAF1eb5d38fF2a0";
    const recipientAddress = "0x1A681d0E32f8a1d0a5ba94113ecBc1A5dF92e50F";
    const genes = "14A28402D3"; // Example gene string
    const birthTime = Math.floor(Date.now() / 1000);
    const matronId = 1;
    const sireId = 2;
    const siringWithId = 0;
    const cooldownIndex = 0;
    const generation = 1;

    const NFTBase = await hre.ethers.getContractAt("NFTBase", contractAddress);

    const mintTx = await NFTBase.mintTkNFT(
        recipientAddress,
        genes,
        birthTime,
        matronId,
        sireId,
        siringWithId,
        cooldownIndex,
        generation
    );
    const receipt = await mintTx.wait();

    // Log the Minted event
    const event = receipt.events.find(event => event.event === 'Minted');
    if (event) {
        console.log(`Minted NFT to ${event.args._to} with tokenId ${event.args._newTokenId} and genes ${event.args.genes}`);
    } else {
        console.log('Mint event not found');
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

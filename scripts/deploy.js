async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const NFTbase = await ethers.getContractFactory("NFTBase");
  const nftBase = await NFTbase.deploy();
  await nftBase.deployed();

  console.log("NFTbase deployed to:", nftBase.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

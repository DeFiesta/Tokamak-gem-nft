const { ethers, network } = require("hardhat");

const CONTRACT_ADDRESSES = {
    DepositManager: "0x76c01207959df1242c2824b4445cde48eb55d2f1",
    WTON: "0xYourWTONContractAddress" // Replace with the actual WTON contract address
};

async function main() {
    const [deployer] = await ethers.getSigners();

    // Get the DepositManager contract instance
    const depositManager = await ethers.getContractAt("DepositManager", CONTRACT_ADDRESSES.DepositManager, deployer);

    // Get the WTON contract instance
    const wton = await ethers.getContractAt("IERC20", CONTRACT_ADDRESSES.WTON, deployer);

    // Define the layer2 address and the amount to deposit
    const layer2Address = "0xYourLayer2Address"; // Replace with the actual layer2 address
    const depositAmount = ethers.utils.parseUnits("10", 18); // Replace with the amount you want to deposit

    // Approve the DepositManager contract to spend WTON tokens
    const approveTx = await wton.approve(CONTRACT_ADDRESSES.DepositManager, depositAmount);
    await approveTx.wait();
    console.log(`Approved ${ethers.utils.formatUnits(depositAmount, 18)} WTON for DepositManager`);

    // Call the deposit function
    const depositTx = await depositManager.deposit(layer2Address, depositAmount);
    await depositTx.wait();
    console.log(`Deposited ${ethers.utils.formatUnits(depositAmount, 18)} WTON to layer2 ${layer2Address}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("Deploying DAOCommitteeExtend...");

    await deploy('DAOCommitteeExtend', {
        from: deployer,
        args: [], // Add constructor arguments here if any
        log: true,
    });

    console.log("DAOCommitteeExtend deployed!");
};

export default func;
func.tags = ['DAOCommitteeExtend'];

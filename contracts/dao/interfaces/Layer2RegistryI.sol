// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface Layer2RegistryI {
    function deployCoinage(address layer2, address seigManager) external returns (bool);
    function registerAndDeployCoinage(address layer2, address seigManager, string memory name)
        external
        returns (bool);
    function registerAndDeployCoinageAndSetCommissionRate(
        address layer2,
        address seigManager,
        uint256 commissionRate,
        bool isCommissionRateNegative,
        string memory name
    ) external returns (bool);
    function register(address layer2, string memory name) external returns (bool);
    function unregister(address layer2) external returns (bool);
    function layer2s(address layer2) external view returns (bool);
    function numLayer2s() external view returns (uint256);
    function layer2ByIndex(uint256 index) external view returns (address);
    function getLayer2ByName(string memory name) external view returns (address);
}

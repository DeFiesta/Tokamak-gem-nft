// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CoinageFactoryI} from "../interfaces/CoinageFactoryI.sol";
import {RefactorCoinageSnapshotProxy} from "../tokens/RefactorCoinageSnapshotProxy.sol";

interface IIAutoRefactorCoinage {
    function initialize(string memory name_, string memory symbol_, uint256 factor_, address seigManager_) external;
}

contract CoinageFactory is CoinageFactoryI, Ownable {
    uint256 internal constant _DEFAULT_FACTOR = 10 ** 27;

    address public autoCoinageLogic;

    constructor(address initialOwner) Ownable(initialOwner) {
        // Additional initialization if needed
    }

    function setAutoCoinageLogic(address newLogic) external onlyOwner {
        autoCoinageLogic = newLogic;
    }

    function deploy() external override returns (address) {
        RefactorCoinageSnapshotProxy c = new RefactorCoinageSnapshotProxy();
        c.upgradeTo(autoCoinageLogic);
        c.addMinter(msg.sender);

        IIAutoRefactorCoinage(address(c)).initialize("StakedWTON", "sWTON", _DEFAULT_FACTOR, msg.sender);

        // c.renounceMinter();
        c.transferOwnership(msg.sender);

        return address(c);
    }
}

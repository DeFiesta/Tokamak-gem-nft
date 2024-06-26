// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Layer2RegistryI} from "../dao/interfaces/Layer2RegistryI.sol";
import "../proxy/ProxyStorage.sol";
import {AuthControlCoinage} from "../common/AuthControlCoinage.sol";
import {Layer2RegistryStorage} from "./Layer2RegistryStorage.sol";

interface IISeigManager {
    function deployCoinage(address layer2) external returns (bool);
    function setCommissionRate(address layer2, uint256 commission, bool isCommissionRateNegative)
        external
        returns (bool);
}

interface IILayer2 {
    function operator() external view returns (address);
    function isLayer2() external view returns (bool);
}

// TODO: transfer coinages ownership to seig manager
contract Layer2Registry is ProxyStorage, AuthControlCoinage, Layer2RegistryStorage, Layer2RegistryI {
    modifier onlyMinterOrOperator(address layer2) {
        require(
            hasRole(MINTER_ROLE, msg.sender) || IILayer2(layer2).operator() == msg.sender,
            "sender is neither admin nor operator"
        );
        _;
    }

    // ------ onlyOwner

    function deployCoinage(address layer2, address seigManager) external onlyMinterOrOperator(layer2) returns (bool) {
        return _deployCoinage(layer2, seigManager);
    }

    function registerAndDeployCoinage(address layer2, address seigManager, string memory name)
        external
        onlyMinterOrOperator(layer2)
        returns (bool)
    {
        require(_register(layer2, name));
        require(_deployCoinage(layer2, seigManager));
        return true;
    }

    function registerAndDeployCoinageAndSetCommissionRate(
        address layer2,
        address seigManager,
        uint256 commissionRate,
        bool isCommissionRateNegative,
        string memory name
    ) external onlyMinterOrOperator(layer2) returns (bool) {
        require(_register(layer2, name));
        require(_deployCoinage(layer2, seigManager));
        require(_setCommissionRate(layer2, seigManager, commissionRate, isCommissionRateNegative));
        return true;
    }

    function register(address layer2, string memory name) external onlyMinterOrOperator(layer2) returns (bool) {
        return _register(layer2, name);
    }

    function unregister(address layer2) external onlyOwner returns (bool) {
        require(_layer2s[layer2]);

        _layer2s[layer2] = false;
        return true;
    }

    // ------ external

    function layer2s(address layer2) external view returns (bool) {
        return _layer2s[layer2];
    }

    function numLayer2s() external view returns (uint256) {
        return _numLayer2s;
    }

    function layer2ByIndex(uint256 index) external view returns (address) {
        return _layer2ByIndex[index];
    }

    // Ajout de cette fonction pour récupérer l'adresse layer2 par nom
    function getLayer2ByName(string memory name) public view returns (address) {
        return _layer2ByName[name];
    }

    // ------ internal

    function _register(address layer2, string memory name) internal returns (bool) {
        require(!_layer2s[layer2]);
        require(IILayer2(layer2).isLayer2());

        _layer2s[layer2] = true;
        _layer2ByIndex[_numLayer2s] = layer2;
        _layer2ByName[name] = layer2; // Utilisation du paramètre name
        _numLayer2s += 1;

        return true;
    }

    function _deployCoinage(address layer2, address seigManager) internal returns (bool) {
        return IISeigManager(seigManager).deployCoinage(layer2);
    }

    function _setCommissionRate(
        address layer2,
        address seigManager,
        uint256 commissionRate,
        bool isCommissionRateNegative
    ) internal returns (bool) {
        return IISeigManager(seigManager).setCommissionRate(layer2, commissionRate, isCommissionRateNegative);
    }
}

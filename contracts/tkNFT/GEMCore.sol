// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GEMAuction} from "./auction/GEMAuction.sol";

contract GEMCore is GEMAuction {
    uint256 public forgedTkGEMs;

    constructor(address _GEMAddr, uint256 _cut, address _wtonTokenAddress)
        GEMAuction(_GEMAddr, _cut, _wtonTokenAddress)
    {}

    function tkGEMCore() public onlyCEO {
        paused = true;

        // the creator of the contract is the initial CEO and COO
        ceoAddress = msg.sender;
        cooAddress = msg.sender;

        // start with the mythical GEM 0 - so we don't have generation-0 parent issues
        _createGEM(0, 0, 0, 0, address(0));
    }

    function tkGEMwithdrawBalance() external onlyCFO {
        uint256 balance = address(this).balance;
        // Subtract all the currently Forging tkGEMs we have, plus 1 of margin.
        uint256 subtractFees = (forgedTkGEMs + 1) * autoForgeFee;

        if (balance > subtractFees) {
            payable(cfoAddress).transfer(balance - subtractFees);
        }
    }

    /// @dev Reject all Ether from being sent here, unless it's from one of the
    ///  two auction contracts. (Hopefully, we can prevent user accidents.)
    receive() external payable {
        require(msg.sender == address(saleAuction));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTMinting} from "./NFTMinting.sol";

contract NFTCore is NFTMinting {
    uint256 public pregnantTkNFT;
    uint256 public autoBirthFee;

    function tkNFTCore() public {
        paused = true;

        // the creator of the contract is the initial CEO and COO
        ceoAddress = msg.sender;
        cooAddress = msg.sender;

        // start with the mythical NFT 0 - so we don't have generation-0 parent issues
        _createNFT(0, 0, 0, 0, address(0));
    }

    function withdrawBalance() external onlyCFO {
        uint256 balance = address(this).balance;
        // Subtract all the currently pregnant kittens we have, plus 1 of margin.
        uint256 subtractFees = (pregnantTkNFT + 1) * autoBirthFee;

        if (balance > subtractFees) {
            payable(cfoAddress).transfer(balance - subtractFees);
        }
    }

    /// @dev Reject all Ether from being sent here, unless it's from one of the
    ///  two auction contracts. (Hopefully, we can prevent user accidents.)
    receive() external payable {
        require(msg.sender == address(saleAuction) || msg.sender == address(siringAuction));
    }
}

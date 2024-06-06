// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GEMAuction} from "./auction/GEMAuction.sol";

contract GEMCore is GEMAuction {
    uint256 public constant PROMO_CREATION_LIMIT = 5000;
    uint256 public constant GEN0_CREATION_LIMIT = 45000;

    uint256 public constant GEN0_STARTING_PRICE = 10 * 1e15; // 10 finney in wei
    uint256 public constant GEN0_AUCTION_DURATION = 1 days;

    uint256 public forgedTkGEMs;
    uint256 public promoCreatedCount;
    uint256 public gen0CreatedCount;

    constructor(address _GEMAddr, uint256 _cut, address _wtonTokenAddress)
        GEMAuction(_GEMAddr, _cut, _wtonTokenAddress)
    {}

    function createPromoGEM(uint256 _shape, address _owner) external onlyCOO {
        address GEMOwner = _owner;
        if (GEMOwner == address(0)) {
            GEMOwner = cooAddress; // default to COO address
        }
        require(promoCreatedCount < PROMO_CREATION_LIMIT);
        promoCreatedCount++;
        _createGEM(0, _shape, GEMOwner);
    }

    function tkGEMCore() public onlyCEO {
        paused = true;

        // the creator of the contract is the initial CEO and COO
        ceoAddress = msg.sender;
        cooAddress = msg.sender;

        // start with the mythical GEM 0 - so we don't have generation-0 parent issues
        _createGEM(0, 0, address(0));
    }

    function tkGEMwithdrawBalance() external onlyCFO {
        uint256 balance = address(this).balance;
        // Subtract all the currently Forging tkGEMs we have, plus 1 of margin.
        //uint256 subtractFees = (forgedTkGEMs + 1) * autoForgeFee;

        //if (balance > subtractFees) {
        payable(cfoAddress).transfer(balance);
        //
    }

    // Creates a new gen0 tkGEM and an auction for it.
    /*
    function createGen0Auction(uint256 _shape) external onlyCOO {
        require(gen0CreatedCount < GEN0_CREATION_LIMIT);
        uint256 tkGEMId = _createGEM(0, 0, 0, _shape, address(this));
        _approve(tkGEMId, saleAuction);
        saleAuction.createAuction(tkGEMId, _computeNextGen0Price(), 0, GEN0_AUCTION_DURATION, address(this));
        gen0CreatedCount++;
    }
    */
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ClockAuction} from "./auction/ClockAuction.sol";
import {GEMForging} from "./GEMForging.sol";
import {GEMAccessControl} from "./GEMAccessControl.sol";

contract GEMMinting is GEMForging {
    uint256 public constant PROMO_CREATION_LIMIT = 5000;
    uint256 public constant GEN0_CREATION_LIMIT = 45000;

    uint256 public constant GEN0_STARTING_PRICE = 10 * 1e15; // 10 finney in wei
    uint256 public constant GEN0_AUCTION_DURATION = 1 days;

    // Counts the number of GEMs the contract owner has created.
    uint256 public promoCreatedCount;
    uint256 public gen0CreatedCount;

    function createPromoGEM(uint256 _genes, address _owner) external onlyCOO {
        address GEMOwner = _owner;
        if (GEMOwner == address(0)) {
            GEMOwner = cooAddress; // default to COO address
        }
        require(promoCreatedCount < PROMO_CREATION_LIMIT);
        promoCreatedCount++;
        _createGEM(0, 0, 0, _genes, GEMOwner);
    }

    // Creates a new gen0 tkGEM and an auction for it.
    /*
    function createGen0Auction(uint256 _genes) external onlyCOO {
        require(gen0CreatedCount < GEN0_CREATION_LIMIT);
        uint256 tkGEMId = _createGEM(0, 0, 0, _genes, address(this));
        _approve(tkGEMId, saleAuction);
        saleAuction.createAuction(tkGEMId, _computeNextGen0Price(), 0, GEN0_AUCTION_DURATION, address(this));
        gen0CreatedCount++;
    }
    */
}

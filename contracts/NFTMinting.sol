// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ClockAuction} from "./auction/ClockAuction.sol";
import {NFTBase} from "./NFTBase.sol";
import {NFTAccessControl} from "./NFTAccessControl.sol";

contract NFTMinting is NFTAccessControl, NFTBase {
    uint256 public constant PROMO_CREATION_LIMIT = 5000;
    uint256 public constant GEN0_CREATION_LIMIT = 45000;

    uint256 public constant GEN0_STARTING_PRICE = 10 * 1e15; // 10 finney in wei
    uint256 public constant GEN0_AUCTION_DURATION = 1 days;

    // Counts the number of cats the contract owner has created.
    uint256 public promoCreatedCount;
    uint256 public gen0CreatedCount;

    function createPromoNFT(uint256 _genes, address _owner) external onlyCOO {
        address NFTOwner = _owner;
        if (NFTOwner == address(0)) {
            NFTOwner = cooAddress; // default to COO address
        }
        require(promoCreatedCount < PROMO_CREATION_LIMIT);
        promoCreatedCount++;
        _createNFT(0, 0, 0, _genes, NFTOwner);
    }

    // Creates a new gen0 kitty and an auction for it.
    /*
    function createGen0Auction(uint256 _genes) external onlyCOO {
        require(gen0CreatedCount < GEN0_CREATION_LIMIT);
        uint256 tkNFTId = _createNFT(0, 0, 0, _genes, address(this));
        _approve(tkNFTId, saleAuction);
        saleAuction.createAuction(tkNFTId, _computeNextGen0Price(), 0, GEN0_AUCTION_DURATION, address(this));
        gen0CreatedCount++;
    }
    */
}

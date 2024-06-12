// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SaleClockAuction} from "./SaleClockAuction.sol";
import {ClockAuctionBase} from "./ClockAuctionBase.sol";
import {GEMForging} from "../GEMForging.sol";

/// @title Handles creating auctions for sale and forging of tkGEMs.
///  This wrapper of ReverseAuction exists only so that users can create
///  auctions with only one transaction.
contract GEMAuction is GEMForging, SaleClockAuction {
    // @notice The auction contract variables are defined in GEMStorage to allow
    //  us to refer to them in GEMOwnership to prevent accidental transfers.
    // `saleAuction` refers to the auction for gen0 and p2p sale of tkGEMs.
    // `forgingAuction` refers to the auction for forging rights of tkGEMs.t.

    constructor(address _GEMAddr, uint256 _cut, address _wtonTokenAddress)
        SaleClockAuction(_GEMAddr, _cut, _wtonTokenAddress)
    {}

    function setSaleAuctionAddress(address _address) external onlyCEO {
        SaleClockAuction candidateContract = SaleClockAuction(_address);

        require(candidateContract.isSaleClockAuction());

        // Set the new contract address
        saleAuction = candidateContract;
    }

    /// @dev Put a tkGEM up for auction.
    ///  Does some ownership trickery to create auctions in one tx.
    function createSaleAuction(uint256 _GEMId, uint256 _startingPrice, uint256 _endingPrice, uint256 _duration)
        external
        whenNotPaused
    {
        require(_owns(msg.sender, _GEMId));
        _approve(_GEMId, address(saleAuction));
        saleAuction.createAuction(_GEMId, _startingPrice, _endingPrice, _duration, msg.sender);
    }

    /// @dev Transfers the balance of the sale auction contract
    /// to the tkGEMCore contract. We use two-step withdrawal to
    /// prevent two transfer calls in the auction bid function.
    function withdrawAuctionBalances() external onlyCLevel {
        saleAuction.withdrawBalance();
    }
}

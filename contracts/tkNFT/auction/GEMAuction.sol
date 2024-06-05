// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GEMMinting} from "../GEMMinting.sol";
import {SaleClockAuction} from "./SaleClockAuction.sol";
import {SiringClockAuction} from "./SiringClockAuction.sol";
import {ClockAuctionBase} from "./ClockAuctionBase.sol";

/// @title Handles creating auctions for sale and siring of tkGEMs.
///  This wrapper of ReverseAuction exists only so that users can create
///  auctions with only one transaction.
contract GEMAuction is GEMMinting, SaleClockAuction {
    // @notice The auction contract variables are defined in GEMBase to allow
    //  us to refer to them in GEMOwnership to prevent accidental transfers.
    // `saleAuction` refers to the auction for gen0 and p2p sale of tkGEMs.
    // `siringAuction` refers to the auction for siring rights of tkGEMs.t.

    constructor(address _GEMAddr, uint256 _cut, address _wtonTokenAddress)
        SaleClockAuction(_GEMAddr, _cut, _wtonTokenAddress)
    {}

    function setSaleAuctionAddress(address _address) external onlyCEO {
        SaleClockAuction candidateContract = SaleClockAuction(_address);

        require(candidateContract.isSaleClockAuction());

        // Set the new contract address
        saleAuction = candidateContract;
    }

    /// @dev Sets the reference to the siring auction.
    /// @param _address - Address of siring contract.
    function setSiringAuctionAddress(address _address) external onlyCEO {
        SiringClockAuction candidateContract = SiringClockAuction(_address);
        require(candidateContract.isSiringClockAuction());

        // Set the new contract address
        siringAuction = candidateContract;
    }

    /// @dev Put a tkGEM up for auction.
    ///  Does some ownership trickery to create auctions in one tx.
    function createSaleAuction(uint256 _GEMId, uint256 _startingPrice, uint256 _endingPrice, uint256 _duration)
        external
        whenNotPaused
    {
        // Auction contract checks input sizes
        // If tkGEM is already on any auction, this will throw
        // because it will be owned by the auction contract.
        require(_owns(msg.sender, _GEMId));
        // Ensure the tkGEM is not pregnant to prevent the auction
        // contract accidentally receiving ownership of the child.
        // NOTE: the tkGEM IS allowed to be in a cooldown.
        require(!isPregnant(_GEMId));
        _approve(_GEMId, address(saleAuction));
        // Sale auction throws if inputs are invalid and clears
        // transfer and sire approval after escrowing the tkGEM.
        saleAuction.createAuction(_GEMId, _startingPrice, _endingPrice, _duration, msg.sender);
    }

    /// @dev Put a tkGEM up for auction to be sire.
    ///  Performs checks to ensure the tkGEM can be sired, then
    ///  delegates to reverse auction.
    function createSiringAuction(uint256 _GEMId, uint256 _startingPrice, uint256 _endingPrice, uint256 _duration)
        external
        whenNotPaused
    {
        // Auction contract checks input sizes
        // If tkGEM is already on any auction, this will throw
        // because it will be owned by the auction contract.
        require(_ownsGEM(msg.sender, _GEMId));
        require(_isReadyToforge(tkGEMs[_GEMId]));
        _approve(_GEMId, address(siringAuction));
        // Siring auction throws if inputs are invalid and clears
        // transfer and sire approval after escrowing the tkGEM.
        siringAuction.createAuction(_GEMId, _startingPrice, _endingPrice, _duration, msg.sender);
    }

    /// @dev Completes a siring auction by bidding.
    ///  Immediately forges the winning matron with the sire on auction.
    /// @param _sireId - ID of the sire on auction.
    /// @param _matronId - ID of the matron owned by the bidder.
    function bidOnSiringAuction(uint256 _sireId, uint256 _matronId) external payable whenNotPaused {
        // Auction contract checks input sizes
        require(_ownsGEM(msg.sender, _matronId));
        require(_isReadyToforge(tkGEMs[_matronId]));
        require(_canforgeWithViaAuction(_matronId, _sireId));

        // Define the current price of the auction.
        uint256 currentPrice = siringAuction.getCurrentPrice(_sireId);
        require(msg.value >= currentPrice + autoBirthFee);

        // Siring auction will throw if the bid fails.
        siringAuction.bid{value: msg.value - autoBirthFee}(_sireId);
        _forgeWith(uint32(_matronId), uint32(_sireId));
    }

    /// @dev Transfers the balance of the sale auction contract
    /// to the tkGEMCore contract. We use two-step withdrawal to
    /// prevent two transfer calls in the auction bid function.
    function withdrawAuctionBalances() external onlyCLevel {
        saleAuction.withdrawBalance();
        siringAuction.withdrawBalance();
    }
}

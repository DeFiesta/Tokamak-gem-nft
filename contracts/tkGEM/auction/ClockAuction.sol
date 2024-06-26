// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ClockAuctionBase} from "./ClockAuctionBase.sol";
import {GEMAccessControl} from "../GEMAccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ClockAuction is ClockAuctionBase {
    /// @dev The ERC-165 interface signature for ERC-721.
    ///  Ref: https://github.com/ethereum/EIPs/issues/165
    ///  Ref: https://github.com/ethereum/EIPs/issues/721
    bytes4 constant InterfaceSignature_ERC721 = bytes4(0x9a20483d);

    /// @dev Constructor creates a reference to the GEM ownership contract
    ///  and verifies the owner cut is in the valid range.
    /// @param _GEMAddr - address of a deployed contract implementing
    ///  the Nonfungible Interface.
    /// @param _cut - percent cut the owner takes on each auction, must be
    ///  between 0-10,000.

    /// @dev Constructor creates a reference to the GEM ownership contract
    ///  and verifies the owner cut is in the valid range.
    /// @param _GEMAddr - address of a deployed contract implementing
    ///  the Nonfungible Interface.
    /// @param _cut - percent cut the owner takes on each auction, must be
    ///  between 0-10,000.
    /// @param _wtonTokenAddress - address of the deployed WTON token contract.
    constructor(address _GEMAddr, uint256 _cut, address _wtonTokenAddress) ClockAuctionBase(_wtonTokenAddress) {
        require(_cut <= 10000, "Cut must be between 0 and 10000");
        ownerCut = _cut;

        ERC721 candidateContract = ERC721(_GEMAddr);
        require(
            candidateContract.supportsInterface(InterfaceSignature_ERC721),
            "GEM contract does not support ERC721 interface"
        );
        nonFungibleContract = candidateContract;
    }

    /// @dev Remove all Ether from the contract, which is the owner's cuts
    ///  as well as any Ether sent directly to the contract address.
    ///  Always transfers to the GEM contract, but can be called either by
    ///  the owner or the GEM contract.
    function withdrawBalance() external onlyCFO returns (bool res) {
        address GEMAddress = address(nonFungibleContract);

        require(msg.sender == GEMAddress);
        // We are using this boolean method to make sure that even if one fails it will still work
        res = payable(GEMAddress).send(address(this).balance);
    }

    /// @dev Creates and begins a new auction.
    /// @param _tokenId - ID of token to auction, sender must be owner.
    /// @param _startingPrice - Price of item (in wei) at beginning of auction.
    /// @param _endingPrice - Price of item (in wei) at end of auction.
    /// @param _duration - Length of time to move between starting
    ///  price and ending price (in seconds).
    /// @param _seller - Seller, if not the message sender
    function createAuction(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration,
        address _seller
    ) external virtual whenNotPaused {
        // Sanity check that no inputs overflow how many bits we've allocated
        // to store them in the auction struct.
        require(_startingPrice == uint256(uint128(_startingPrice)));
        require(_endingPrice == uint256(uint128(_endingPrice)));
        require(_duration == uint256(uint64(_duration)));

        require(_owns(msg.sender, _tokenId));
        _escrow(msg.sender, _tokenId);
        Auction memory auction =
            Auction(_seller, uint128(_startingPrice), uint128(_endingPrice), uint64(_duration), uint64(block.timestamp));
        _addAuction(_tokenId, auction);
    }

    /// @dev Bids on an open auction, completing the auction and transferring
    ///  ownership of the GEM if enough Ether is supplied.
    /// @param _tokenId - ID of token to bid on.
    function bid(uint256 _tokenId) external payable virtual whenNotPaused {
        // _bid will throw if the bid or funds transfer fails
        _bid(_tokenId, msg.value);
        _transfer(msg.sender, _tokenId);
    }

    /// @dev Cancels an auction that hasn't been won yet.
    ///  Returns the GEM to original owner.
    /// @notice This is a state-modifying function that can
    ///  be called while the contract is paused.
    /// @param _tokenId - ID of token on auction
    function cancelAuction(uint256 _tokenId) external {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(_isOnAuction(auction));
        address seller = auction.seller;
        require(msg.sender == seller);
        _cancelAuction(_tokenId, seller);
    }

    /// @dev Cancels an auction when the contract is paused.
    ///  Only the owner may do this, and GEMs are returned to
    ///  the seller. This should only be used in emergencies.
    /// @param _tokenId - ID of the GEM on auction to cancel.
    function cancelAuctionWhenPaused(uint256 _tokenId) external whenPaused onlyCFO {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(_isOnAuction(auction));
        _cancelAuction(_tokenId, auction.seller);
    }

    /// @dev Returns auction info for an GEM on auction.
    /// @param _tokenId - ID of GEM on auction.
    function getAuction(uint256 _tokenId)
        external
        view
        returns (address seller, uint256 startingPrice, uint256 endingPrice, uint256 duration, uint256 startedAt)
    {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(_isOnAuction(auction));
        return (auction.seller, auction.startingPrice, auction.endingPrice, auction.duration, auction.startedAt);
    }

    /// @dev Returns the current price of an auction.
    /// @param _tokenId - ID of the token price we are checking.
    function getCurrentPrice(uint256 _tokenId) external view returns (uint256) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(_isOnAuction(auction));
        return _currentPrice(auction);
    }
}

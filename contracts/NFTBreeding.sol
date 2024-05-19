// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTOwnership} from "./NFTOwnership.sol";

interface GeneScience {
    function isGeneScience() external pure returns (bool);

    /// @dev given genes of kitten 1 & 2, return a genetic combination - may have a random factor
    /// @param genes1 genes of mom
    /// @param genes2 genes of sire
    /// @return the genes that are supposed to be passed down the child
    function mixGenes(uint256 genes1, uint256 genes2, uint256 targetBlock) external returns (uint256);
}

contract NFTBreeding is NFTOwnership {
    uint256 public autoBirthFee = 2 * 1e15; // 2 finney
    uint256 public pregnantNFT; // number of pregnant NFT

    GeneScience geneScience;

    constructor(address _geneScience, address _nftaddr, uint256 _cut) NFTOwnership(_nftaddr, _cut) {
        geneScience = GeneScience(_geneScience);
    }

    function _isReadyToBreed(tkNFT memory _nft) internal view returns (bool) {
        return (_nft.siringWithId == 0) && (_nft.cooldownEndBlock <= uint64(block.number));
    }

    function _isReadyToGiveBirth(tkNFT memory _matron) private view returns (bool) {
        return (_matron.siringWithId != 0) && (_matron.cooldownEndBlock <= uint64(block.number));
    }

    function _triggerCooldown(tkNFT storage _nft) internal {
        // Compute an estimation of the cooldown time in blocks (based on current cooldownIndex).
        _nft.cooldownEndBlock = uint64((cooldowns[_nft.cooldownIndex] / secondsPerBlock) + block.number);
        if (_nft.cooldownIndex < 13) {
            _nft.cooldownIndex += 1;
        }
    }

    function approveSiring(address _addr, uint256 _sireId) external whenNotPaused {
        require(_owns(msg.sender, _sireId));
        sireAllowedToAddress[_sireId] = _addr;
    }

    function _isSiringPermitted(uint256 _sireId, uint256 _matronId) internal view returns (bool) {
        address matronOwner = NFTIndexToOwner[_matronId];
        address sireOwner = NFTIndexToOwner[_sireId];
        return (matronOwner == sireOwner || sireAllowedToAddress[_sireId] == matronOwner);
    }

    function _isValidMatingPair(tkNFT storage _matron, uint256 _matronId, tkNFT storage _sire, uint256 _sireId)
        private
        view
        returns (bool)
    {
        // A NFT can't breed with itself!
        if (_matronId == _sireId) {
            return false;
        }
        // NFTs can't breed with their parents.
        if (_matron.matronId == _sireId || _matron.sireId == _sireId) {
            return false;
        }
        if (_sire.matronId == _matronId || _sire.sireId == _matronId) {
            return false;
        }
        // We can short circuit the sibling check (below) if either nft is
        // gen zero (has a matron ID of zero).
        if (_sire.matronId == 0 || _matron.matronId == 0) {
            return true;
        }
        // tkNFTs can't breed with full or half siblings.
        if (_sire.matronId == _matron.matronId || _sire.matronId == _matron.sireId) {
            return false;
        }
        if (_sire.sireId == _matron.matronId || _sire.sireId == _matron.sireId) {
            return false;
        }
        return true;
    }

    function _breedWith(uint256 _matronId, uint256 _sireId) internal {
        tkNFT storage sire = tkNFTs[_sireId];
        tkNFT storage matron = tkNFTs[_matronId];

        matron.siringWithId = uint32(_sireId);

        _triggerCooldown(sire);
        _triggerCooldown(matron);

        pregnantNFT++;
    }

    // Anyone can call this function (if they are willing to pay the gas!),
    // but the new nft always goes to the mother's owner.
    function giveBirth(uint256 _matronId) external whenNotPaused returns (uint256) {
        tkNFT storage matron = tkNFTs[_matronId];
        require(_isReadyToGiveBirth(matron));
        uint256 sireId = matron.siringWithId;
        tkNFT storage sire = tkNFTs[sireId];

        // Determine the higher generation number of the two parents
        uint16 parentGen = matron.generation;
        if (sire.generation > matron.generation) {
            parentGen = sire.generation;
        }

        // Call the sooper-sekret gene mixing operation.
        uint256 childGenes = geneScience.mixGenes(matron.genes, sire.genes, matron.cooldownEndBlock - 1);

        // Make the new kitten!
        address owner = NFTIndexToOwner[_matronId];
        uint256 kittenId = _createNFT(_matronId, matron.siringWithId, parentGen + 1, childGenes, owner);

        // Clear the reference to sire from the matron (REQUIRED! Having siringWithId
        // set is what marks a matron as being pregnant.)
        delete matron.siringWithId;

        pregnantNFT--;

        // Send the balance fee to the person who made birth happen.
        payable(msg.sender).transfer(autoBirthFee);

        return kittenId;
    }
}

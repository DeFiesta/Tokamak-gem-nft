// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTOwnership} from "./GEMOwnership.sol";
import {NFTBase} from "./GEMBase.sol";

interface GeneScienceInterface {
    function isGeneScience() external pure returns (bool);

    /// @dev given genes of tknft 1 & 2, return a genetic combination - may have a random factor
    /// @param genes1 genes of mom
    /// @param genes2 genes of sire
    /// @return the genes that are supposed to be passed down the child
    function mixGenes(uint256 genes1, uint256 genes2, uint256 targetBlock) external returns (uint256);
}

contract NFTForging is NFTOwnership {
    /// @notice The minimum payment required to use forgeWithAuto(). This fee goes towards
    ///  the gas cost paid by whatever calls giveBirth(), and can be dynamically updated by
    ///  the COO role as the gas price changes.
    uint256 public autoBirthFee = 2 * 1e15; //finney;

    // Keeps track of number of pregnant tkNFTs.
    uint256 public pregnantTkNFTs;

    /// @dev The address of the sibling contract that is used to implement the sooper-sekret
    ///  genetic combination algorithm.
    GeneScienceInterface public geneScience;

    /// @dev The Pregnant event is fired when two nfts successfully forge and the pregnancy
    ///  timer begins for the matron.
    event Pregnant(address owner, uint256 matronId, uint256 sireId, uint256 cooldownEndBlock);

    /// @dev Update the address of the genetic contract, can only be called by the CEO.
    /// @param _address An address of a GeneScience contract instance to be used from this point forward.

    function setGeneScienceAddress(address _address) external onlyCEO {
        GeneScienceInterface candidateContract = GeneScienceInterface(_address);

        require(candidateContract.isGeneScience());

        // Set the new contract address
        geneScience = candidateContract;
    }

    /// @dev Checks that a given tknft is able to forge. Requires that the
    ///  current cooldown is finished (for sires) and also checks that there is
    ///  no pending pregnancy.
    function _isReadyToforge(tkNFT memory _nft) internal view returns (bool) {
        // In addition to checking the cooldownEndBlock, we also need to check to see if
        // the nft has a pending birth; there can be some period of time between the end
        // of the pregnacy timer and the birth event.
        return (_nft.siringWithId == 0) && (_nft.cooldownEndBlock <= uint64(block.number));
    }

    /// @dev Check if a sire has authorized  Forging with this matron. True if both sire
    ///  and matron have the same owner, or if the sire has given siring permission to
    ///  the matron's owner (via approveSiring()).
    function _isSiringPermitted(uint256 _sireId, uint256 _matronId) internal view returns (bool) {
        address matronOwner = NFTIndexToOwner[_matronId];
        address sireOwner = NFTIndexToOwner[_sireId];

        // Siring is okay if they have same owner, or if the matron's owner was given
        // permission to forge with this sire.
        return (matronOwner == sireOwner || sireAllowedToAddress[_sireId] == matronOwner);
    }

    /// @dev set the cooldownEndTime for the given TkNFT, based on its current cooldownIndex.
    ///  Also increments the cooldownIndex (unless it has hit the cap).
    /// @param _nfts A reference to the TkNFT in storage which needs its timer started.
    function _triggerCooldown(tkNFT storage _nfts) internal {
        // Compute an estimation of the cooldown time in blocks (based on current cooldownIndex).
        _nfts.cooldownEndBlock = uint64((cooldowns[_nfts.cooldownIndex] / secondsPerBlock) + block.number);

        // Increment the  Forging count, clamping it at 13, which is the length of the
        // cooldowns array. We could check the array size dynamically, but hard-coding
        // this as a constant saves gas.
        if (_nfts.cooldownIndex < 13) {
            _nfts.cooldownIndex += 1;
        }
    }

    /// @notice Grants approval to another user to sire with one of your tkNFTs.
    /// @param _addr The address that will be able to sire with your TkNFT. Set to
    ///  address(0) to clear all siring approvals for this TkNFT.
    /// @param _sireId A TkNFT that you own that _addr will now be able to sire with.
    function approveSiring(address _addr, uint256 _sireId) external whenNotPaused {
        require(_ownsNFT(msg.sender, _sireId));
        sireAllowedToAddress[_sireId] = _addr;
    }

    /// @dev Updates the minimum payment required for calling giveBirthAuto(). Can only
    ///  be called by the COO address. (This fee is used to offset the gas cost incurred
    ///  by the autobirth daemon).
    function setAutoBirthFee(uint256 val) external onlyCOO {
        autoBirthFee = val;
    }

    /// @dev Checks to see if a given TkNFT is pregnant and (if so) if the gestation
    ///  period has passed.
    function _isReadyToGiveBirth(tkNFT memory _matron) private view returns (bool) {
        return (_matron.siringWithId != 0) && (_matron.cooldownEndBlock <= uint64(block.number));
    }

    /// @notice Checks that a given tknft is able to forge (i.e. it is not pregnant or
    ///  in the middle of a siring cooldown).
    /// @param _nftId reference the id of the tknft, any user can inquire about it
    function isReadyToforge(uint256 _nftId) public view returns (bool) {
        require(_nftId > 0);
        tkNFT storage nft = tkNFTs[_nftId];
        return _isReadyToforge(nft);
    }

    /// @dev Checks whether a TkNFT is currently pregnant.
    /// @param _nftId reference the id of the tknft, any user can inquire about it
    function isPregnant(uint256 _nftId) public view returns (bool) {
        require(_nftId > 0);
        // A TkNFT is pregnant if and only if this field is set
        return tkNFTs[_nftId].siringWithId != 0;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair. DOES NOT
    ///  check ownership permissions (that is up to the caller).
    /// @param _matron A reference to the TkNFT struct of the potential matron.
    /// @param _matronId The matron's ID.
    /// @param _sire A reference to the TkNFT struct of the potential sire.
    /// @param _sireId The sire's ID
    function _isValidMatingPair(tkNFT storage _matron, uint256 _matronId, tkNFT storage _sire, uint256 _sireId)
        private
        view
        returns (bool)
    {
        // A TkNFT can't forge with itself!
        if (_matronId == _sireId) {
            return false;
        }

        // tkNFTs can't forge with their parents.
        if (_matron.matronId == _sireId || _matron.sireId == _sireId) {
            return false;
        }
        if (_sire.matronId == _matronId || _sire.sireId == _matronId) {
            return false;
        }

        // We can short circuit the sibling check (below) if either cat is
        // gen zero (has a matron ID of zero).
        if (_sire.matronId == 0 || _matron.matronId == 0) {
            return true;
        }

        // tkNFTs can't forge with full or half siblings.
        if (_sire.matronId == _matron.matronId || _sire.matronId == _matron.sireId) {
            return false;
        }
        if (_sire.sireId == _matron.matronId || _sire.sireId == _matron.sireId) {
            return false;
        }

        // Everything seems cool! Let's get DTF.
        return true;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair for
    ///   Forging via auction (i.e. skips ownership and siring approval checks).
    function _canforgeWithViaAuction(uint256 _matronId, uint256 _sireId) internal view returns (bool) {
        tkNFT storage matron = tkNFTs[_matronId];
        tkNFT storage sire = tkNFTs[_sireId];
        return _isValidMatingPair(matron, _matronId, sire, _sireId);
    }

    /// @notice Checks to see if two cats can forge together, including checks for
    ///  ownership and siring approvals. Does NOT check that both cats are ready for
    ///   Forging (i.e. forgeWith could still fail until the cooldowns are finished).
    ///  TODO: Shouldn't this check pregnancy and cooldowns?!?
    /// @param _matronId The ID of the proposed matron.
    /// @param _sireId The ID of the proposed sire.
    function canforgeWith(uint256 _matronId, uint256 _sireId) external view returns (bool) {
        require(_matronId > 0);
        require(_sireId > 0);
        tkNFT storage matron = tkNFTs[_matronId];
        tkNFT storage sire = tkNFTs[_sireId];
        return _isValidMatingPair(matron, _matronId, sire, _sireId) && _isSiringPermitted(_sireId, _matronId);
    }

    /// @dev Internal utility function to initiate  Forging, assumes that all  Forging
    ///  requirements have been checked.
    function _forgeWith(uint256 _matronId, uint256 _sireId) internal {
        // Grab a reference to the tkNFTs from storage.
        tkNFT storage sire = tkNFTs[_sireId];
        tkNFT storage matron = tkNFTs[_matronId];

        // Mark the matron as pregnant, keeping track of who the sire is.
        matron.siringWithId = uint32(_sireId);

        // Trigger the cooldown for both parents.
        _triggerCooldown(sire);
        _triggerCooldown(matron);

        // Clear siring permission for both parents. This may not be strictly necessary
        // but it's likely to avoid confusion!
        delete sireAllowedToAddress[_matronId];
        delete sireAllowedToAddress[_sireId];

        // Every time a TkNFT gets pregnant, counter is incremented.
        pregnantTkNFTs++;

        // Emit the pregnancy event.
        emit Pregnant(NFTIndexToOwner[_matronId], _matronId, _sireId, matron.cooldownEndBlock);
    }

    /// @notice forge a TkNFT you own (as matron) with a sire that you own, or for which you
    ///  have previously been given Siring approval. Will either make your cat pregnant, or will
    ///  fail entirely. Requires a pre-payment of the fee given out to the first caller of giveBirth()
    /// @param _matronId The ID of the TkNFT acting as matron (will end up pregnant if successful)
    /// @param _sireId The ID of the TkNFT acting as sire (will begin its siring cooldown if successful)
    function forgeWithAuto(uint256 _matronId, uint256 _sireId) external payable whenNotPaused {
        // Checks for payment.
        require(msg.value >= autoBirthFee);

        // Caller must own the matron.
        require(_ownsNFT(msg.sender, _matronId));

        // Neither sire nor matron are allowed to be on auction during a normal
        //  Forging operation, but we don't need to check that explicitly.
        // For matron: The caller of this function can't be the owner of the matron
        //   because the owner of a TkNFT on auction is the auction house, and the
        //   auction house will never call forgeWith().
        // For sire: Similarly, a sire on auction will be owned by the auction house
        //   and the act of transferring ownership will have cleared any oustanding
        //   siring approval.
        // Thus we don't need to spend gas explicitly checking to see if either cat
        // is on auction.

        // Check that matron and sire are both owned by caller, or that the sire
        // has given siring permission to caller (i.e. matron's owner).
        // Will fail for _sireId = 0
        require(_isSiringPermitted(_sireId, _matronId));

        // Grab a reference to the potential matron
        tkNFT storage matron = tkNFTs[_matronId];

        // Make sure matron isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToforge(matron));

        // Grab a reference to the potential sire
        tkNFT storage sire = tkNFTs[_sireId];

        // Make sure sire isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToforge(sire));

        // Test that these cats are a valid mating pair.
        require(_isValidMatingPair(matron, _matronId, sire, _sireId));

        // All checks passed, TkNFT gets pregnant!
        _forgeWith(_matronId, _sireId);
    }

    /// @notice Have a pregnant TkNFT give birth!
    /// @param _matronId A TkNFT ready to give birth.
    /// @return The TkNFT ID of the new tknft.
    /// @dev Looks at a given TkNFT and, if pregnant and if the gestation period has passed,
    ///  combines the genes of the two parents to create a new tknft. The new TkNFT is assigned
    ///  to the current owner of the matron. Upon successful completion, both the matron and the
    ///  new tknft will be ready to forge again. Note that anyone can call this function (if they
    ///  are willing to pay the gas!), but the new tknft always goes to the mother's owner.
    function giveBirth(uint256 _matronId) external whenNotPaused returns (uint256) {
        // Grab a reference to the matron in storage.
        tkNFT storage matron = tkNFTs[_matronId];

        // Check that the matron is a valid cat.
        require(matron.birthTime != 0);

        // Check that the matron is pregnant, and that its time has come!
        require(_isReadyToGiveBirth(matron));

        // Grab a reference to the sire in storage.
        uint256 sireId = matron.siringWithId;
        tkNFT storage sire = tkNFTs[sireId];

        // Determine the higher generation number of the two parents
        uint16 parentGen = matron.generation;
        if (sire.generation > matron.generation) {
            parentGen = sire.generation;
        }

        // Call the sooper-sekret gene mixing operation.
        uint256 childGenes = geneScience.mixGenes(matron.genes, sire.genes, matron.cooldownEndBlock - 1);

        // Make the new tknft!
        address owner = NFTIndexToOwner[_matronId];
        uint256 nftId = _createNFT(_matronId, matron.siringWithId, parentGen + 1, childGenes, owner);

        // Clear the reference to sire from the matron (REQUIRED! Having siringWithId
        // set is what marks a matron as being pregnant.)
        delete matron.siringWithId;

        // Every time a TkNFT gives birth counter is decremented.
        pregnantTkNFTs--;

        // Send the balance fee to the person who made birth happen.
        payable(msg.sender).transfer(autoBirthFee);

        // return the new tknft's ID
        return nftId;
    }
}
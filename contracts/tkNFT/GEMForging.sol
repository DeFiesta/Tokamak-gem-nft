// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GEMOwnership} from "./GEMOwnership.sol";
import {GEMBase} from "./GEMBase.sol";

interface GeneScienceInterface {
    function isGeneScience() external pure returns (bool);

    /// @dev given genes of tkGEM 1 & 2, return a genetic combination - may have a random factor
    /// @param genes1 genes of GEM1
    /// @param genes2 genes of GEM2
    /// @return the genes that are supposed to be passed down the forged GEM
    function mixGenes(uint256 genes1, uint256 genes2, uint256 targetBlock) external returns (uint256);
}

contract GEMForging is GEMOwnership {
    /// @notice The minimum payment required to use forgeWithAuto(). This fee goes towards
    ///  the gas cost paid by whatever calls forge(), and can be dynamically updated by
    ///  the COO role as the gas price changes.
    uint256 public autoForgeFee = 2 * 1e15; //finney;

    // Keeps track of number of Forging tkGEMs.
    uint256 public forgingTkGEMs;

    /// @dev The address of the sibling contract that is used to implement the
    ///  genetic combination algorithm.
    GeneScienceInterface public geneScience;

    /// @dev The Forging event is fired when two GEMs successfully forge and the forging
    ///  timer begins for the matron.
    event Forging(address owner, uint256 matronId, uint256 sireId, uint256 cooldownEndBlock);

    /// @dev Update the address of the genetic contract, can only be called by the CEO.
    /// @param _address An address of a GeneScience contract instance to be used from this point forward.

    function setGeneScienceAddress(address _address) external onlyCEO {
        GeneScienceInterface candidateContract = GeneScienceInterface(_address);

        require(candidateContract.isGeneScience());

        // Set the new contract address
        geneScience = candidateContract;
    }

    /// @dev Checks that a given tkGEM is able to forge. Requires that the
    ///  current cooldown is finished (for sires) and also checks that there is
    ///  no pending forging.
    function _isReadyToforge(tkGEM memory _GEM) internal view returns (bool) {
        // In addition to checking the cooldownEndBlock, we also need to check to see if
        // the GEM has a pending birth; there can be some period of time between the end
        // of the pregnacy timer and the birth event.
        return (_GEM.forgingWithId == 0) && (_GEM.cooldownEndBlock <= uint64(block.number));
    }

    /// @dev Check if a sire has authorized  Forging with this matron. True if both sire
    ///  and matron have the same owner, or if the sire has given forging permission to
    ///  the matron's owner (via approveforging()).
    function _isforgingPermitted(uint256 _sireId, uint256 _matronId) internal view returns (bool) {
        address matronOwner = GEMIndexToOwner[_matronId];
        address sireOwner = GEMIndexToOwner[_sireId];

        // forging is okay if they have same owner, or if the matron's owner was given
        // permission to forge with this sire.
        return (matronOwner == sireOwner || sireAllowedToAddress[_sireId] == matronOwner);
    }

    /// @dev set the cooldownEndTime for the given TkGEM, based on its current cooldownIndex.
    ///  Also increments the cooldownIndex (unless it has hit the cap).
    /// @param _GEMs A reference to the TkGEM in storage which needs its timer started.
    function _triggerCooldown(tkGEM storage _GEMs) internal {
        // Compute an estimation of the cooldown time in blocks (based on current cooldownIndex).
        _GEMs.cooldownEndBlock = uint64((cooldowns[_GEMs.cooldownIndex] / secondsPerBlock) + block.number);

        // Increment the  Forging count, clamping it at 13, which is the length of the
        // cooldowns array. We could check the array size dynamically, but hard-coding
        // this as a constant saves gas.
        if (_GEMs.cooldownIndex < 13) {
            _GEMs.cooldownIndex += 1;
        }
    }

    /// @notice Grants approval to another user to sire with one of your tkGEMs.
    /// @param _addr The address that will be able to sire with your TkGEM. Set to
    ///  address(0) to clear all forging approvals for this TkGEM.
    /// @param _sireId A TkGEM that you own that _addr will now be able to sire with.
    function approveforging(address _addr, uint256 _sireId) external whenNotPaused {
        require(_ownsGEM(msg.sender, _sireId));
        sireAllowedToAddress[_sireId] = _addr;
    }

    /// @dev Updates the minimum payment required for calling ForgeAuto(). Can only
    ///  be called by the COO address. (This fee is used to offset the gas cost incurred
    ///  by the autobirth daemon).
    function setAutoBirthFee(uint256 val) external onlyCOO {
        autoForgeFee = val;
    }

    /// @dev Checks to see if a given TkGEM is Forging and (if so) if the gestation
    ///  period has passed.
    function _isReadyToForge(tkGEM memory _matron) private view returns (bool) {
        return (_matron.forgingWithId != 0) && (_matron.cooldownEndBlock <= uint64(block.number));
    }

    /// @notice Checks that a given tkGEM is able to forge (i.e. it is not Forging or
    ///  in the middle of a forging cooldown).
    /// @param _GEMId reference the id of the tkGEM, any user can inquire about it
    function isReadyToforge(uint256 _GEMId) public view returns (bool) {
        require(_GEMId > 0);
        tkGEM storage GEM = tkGEMs[_GEMId];
        return _isReadyToforge(GEM);
    }

    /// @dev Checks whether a TkGEM is currently Forging.
    /// @param _GEMId reference the id of the tkGEM, any user can inquire about it
    function isForging(uint256 _GEMId) public view returns (bool) {
        require(_GEMId > 0);
        // A TkGEM is Forging if and only if this field is set
        return tkGEMs[_GEMId].forgingWithId != 0;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair. DOES NOT
    ///  check ownership permissions (that is up to the caller).
    /// @param _matron A reference to the TkGEM struct of the potential matron.
    /// @param _matronId The matron's ID.
    /// @param _sire A reference to the TkGEM struct of the potential sire.
    /// @param _sireId The sire's ID
    function _isValidForgingPair(tkGEM storage _matron, uint256 _matronId, tkGEM storage _sire, uint256 _sireId)
        private
        view
        returns (bool)
    {
        // A TkGEM can't forge with itself!
        if (_matronId == _sireId) {
            return false;
        }

        // tkGEMs can't forge with their parents.
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

        // tkGEMs can't forge with full or half siblings.
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
    ///   Forging via auction (i.e. skips ownership and forging approval checks).
    function _canforgeWithViaAuction(uint256 _matronId, uint256 _sireId) internal view returns (bool) {
        tkGEM storage matron = tkGEMs[_matronId];
        tkGEM storage sire = tkGEMs[_sireId];
        return _isValidForgingPair(matron, _matronId, sire, _sireId);
    }

    /// @notice Checks to see if two cats can forge together, including checks for
    ///  ownership and forging approvals. Does NOT check that both cats are ready for
    ///   Forging (i.e. forgeWith could still fail until the cooldowns are finished).
    ///  TODO: Shouldn't this check forging and cooldowns?!?
    /// @param _matronId The ID of the proposed matron.
    /// @param _sireId The ID of the proposed sire.
    function canforgeWith(uint256 _matronId, uint256 _sireId) external view returns (bool) {
        require(_matronId > 0);
        require(_sireId > 0);
        tkGEM storage matron = tkGEMs[_matronId];
        tkGEM storage sire = tkGEMs[_sireId];
        return _isValidForgingPair(matron, _matronId, sire, _sireId) && _isforgingPermitted(_sireId, _matronId);
    }

    /// @dev Internal utility function to initiate  Forging, assumes that all  Forging
    ///  requirements have been checked.
    function _forgeWith(uint256 _matronId, uint256 _sireId) internal {
        // Grab a reference to the tkGEMs from storage.
        tkGEM storage sire = tkGEMs[_sireId];
        tkGEM storage matron = tkGEMs[_matronId];

        // Mark the matron as Forging, keeping track of who the sire is.
        matron.forgingWithId = uint32(_sireId);

        // Trigger the cooldown for both parents.
        _triggerCooldown(sire);
        _triggerCooldown(matron);

        // Clear forging permission for both parents. This may not be strictly necessary
        // but it's likely to avoid confusion!
        delete sireAllowedToAddress[_matronId];
        delete sireAllowedToAddress[_sireId];

        // Every time a TkGEM gets Forging, counter is incremented.
        forgingTkGEMs++;

        // Emit the forging event.
        emit Forging(GEMIndexToOwner[_matronId], _matronId, _sireId, matron.cooldownEndBlock);
    }

    /// @notice forge a TkGEM you own (as matron) with a sire that you own, or for which you
    ///  have previously been given forging approval. Will either make your cat Forging, or will
    ///  fail entirely. Requires a pre-payment of the fee given out to the first caller of forge()
    /// @param _matronId The ID of the TkGEM acting as matron (will end up Forging if successful)
    /// @param _sireId The ID of the TkGEM acting as sire (will begin its forging cooldown if successful)
    function forgeWithAuto(uint256 _matronId, uint256 _sireId) external payable whenNotPaused {
        // Checks for payment.
        require(msg.value >= autoForgeFee);

        // Caller must own the matron.
        require(_ownsGEM(msg.sender, _matronId));

        // Neither sire nor matron are allowed to be on auction during a normal
        //  Forging operation, but we don't need to check that explicitly.
        // For matron: The caller of this function can't be the owner of the matron
        //   because the owner of a TkGEM on auction is the auction house, and the
        //   auction house will never call forgeWith().
        // For sire: Similarly, a sire on auction will be owned by the auction house
        //   and the act of transferring ownership will have cleared any oustanding
        //   forging approval.
        // Thus we don't need to spend gas explicitly checking to see if either cat
        // is on auction.

        // Check that matron and sire are both owned by caller, or that the sire
        // has given forging permission to caller (i.e. matron's owner).
        // Will fail for _sireId = 0
        require(_isforgingPermitted(_sireId, _matronId));

        // Grab a reference to the potential matron
        tkGEM storage matron = tkGEMs[_matronId];

        // Make sure matron isn't Forging, or in the middle of a forging cooldown
        require(_isReadyToforge(matron));

        // Grab a reference to the potential sire
        tkGEM storage sire = tkGEMs[_sireId];

        // Make sure sire isn't Forging, or in the middle of a forging cooldown
        require(_isReadyToforge(sire));

        // Test that these cats are a valid mating pair.
        require(_isValidForgingPair(matron, _matronId, sire, _sireId));

        // All checks passed, TkGEM gets Forging!
        _forgeWith(_matronId, _sireId);
    }

    /// @notice Have a Forging TkGEM give birth!
    /// @param _matronId A TkGEM ready to give birth.
    /// @return The ID of the new tkGEM.
    /// @dev Looks at a given TkGEM and, if Forging and if the gestation period has passed,
    ///  combines the genes of the two parents to create a new tkGEM. The new TkGEM is assigned
    ///  to the current owner of the matron. Upon successful completion, both the matron and the
    ///  new tkGEM will be ready to forge again. Note that anyone can call this function (if they
    ///  are willing to pay the gas!), but the new tkGEM always goes to the mother's owner.
    function forge(uint256 _matronId) external whenNotPaused returns (uint256) {
        // Grab a reference to the matron in storage.
        tkGEM storage matron = tkGEMs[_matronId];

        // Check that the matron is a valid cat.
        require(matron.birthTime != 0);

        // Check that the matron is Forging, and that its time has come!
        require(_isReadyToForge(matron));

        // Grab a reference to the sire in storage.
        uint256 sireId = matron.forgingWithId;
        tkGEM storage sire = tkGEMs[sireId];

        // Determine the higher generation number of the two parents
        uint16 parentGen = matron.generation;
        if (sire.generation > matron.generation) {
            parentGen = sire.generation;
        }

        // Call the sooper-sekret gene mixing operation.
        uint256 childGenes = geneScience.mixGenes(matron.genes, sire.genes, matron.cooldownEndBlock - 1);

        // Make the new tkGEM!
        address owner = GEMIndexToOwner[_matronId];
        uint256 GEMId = _createGEM(_matronId, matron.forgingWithId, parentGen + 1, childGenes, owner);

        // Clear the reference to sire from the matron (REQUIRED! Having forgingWithId
        // set is what marks a matron as being Forging.)
        delete matron.forgingWithId;

        // Every time a TkGEM gives birth counter is decremented.
        forgingTkGEMs--;

        // Send the balance fee to the person who made birth happen.
        payable(msg.sender).transfer(autoForgeFee);

        // return the new tkGEM's ID
        return GEMId;
    }
}

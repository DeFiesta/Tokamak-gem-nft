// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GEMOwnership} from "./GEMOwnership.sol";
import {GEMBase} from "./GEMBase.sol";

interface shapecienceInterface {
    function isshapecience() external pure returns (bool);

    /// @dev given shape of tkGEM 1 & 2, return a genetic combination - may have a random factor
    /// @param shape1 shape of GEM1
    /// @param shape2 shape of GEM2
    /// @return the shape that are supposed to be passed down the forged GEM
    function mixshape(uint256 shape1, uint256 shape2, uint256 targetBlock) external returns (uint256);
}

contract GEMForging is GEMOwnership {
    // Keeps track of number of Forging tkGEMs.
    uint256 public forgingTkGEMs;

    /// @dev The address of the sibling contract that is used to implement the
    ///  genetic combination algorithm.
    shapecienceInterface public shapecience;

    /// @dev The Forging event is fired when two GEMs successfully forge and the forging
    ///  timer begins for the gem.
    event Forging(address owner, uint256 firstGemId, uint256 secondGemId, uint256 cooldownEndBlock);

    /// @dev Update the address of the genetic contract, can only be called by the CEO.
    /// @param _address An address of a shapecience contract instance to be used from this point forward.

    function setshapecienceAddress(address _address) external onlyCEO {
        shapecienceInterface candidateContract = shapecienceInterface(_address);

        require(candidateContract.isshapecience());

        // Set the new contract address
        shapecience = candidateContract;
    }

    /// @notice Checks that a given tkGEM is able to forge (i.e. it is not Forging or
    /// in the middle of a forging cooldown).
    /// @param _GEMId reference the id of the tkGEM, any user can inquire about it
    function isReadyToforge(uint256 _GEMId) public view returns (bool) {
        require(_GEMId > 0);
        tkGEM storage gem = tkGEMs[_GEMId];
        return _isReadyToforge(gem);
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
    /// @param _GemId A TkGEM that you own that _addr will now be able to sire with.
    function approveforging(address _addr, uint256 _GemId) external whenNotPaused {
        require(_ownsGEM(msg.sender, _GemId));
        gemAllowedToAddress[_GemId] = _addr;
    }

    /// @dev Checks whether a TkGEM is currently Forging.
    /// @param _GEMId reference the id of the tkGEM, any user can inquire about it
    function isForging(uint256 _GEMId) public view returns (bool) {
        require(_GEMId > 0);
        // A TkGEM is Forging if and only if this field is set
        return tkGEMs[_GEMId].forgingWithId != 0;
    }

    /// @dev Internal utility function to initiate  Forging, assumes that all Forging
    ///  requirements have been checked.
    function _forgeWith(uint256 _firstGemId, uint256 _secondGemId) internal {
        // Grab a reference to the tkGEMs from storage.
        tkGEM storage firstGem = tkGEMs[_firstGemId];
        tkGEM storage secondGem = tkGEMs[_secondGemId];

        // Mark the first gem as Forging, keeping track of who the second gem is.
        firstGem.forgingWithId = uint32(_secondGemId);
        secondGem.forgingWithId = uint32(_firstGemId);

        // Trigger the cooldown for both parents.
        _triggerCooldown(secondGem);
        _triggerCooldown(firstGem);

        // Clear forging permission for both parents. This may not be strictly necessary
        // but it's likely to avoid confusion!
        delete gemAllowedToAddress[_firstGemId];
        delete gemAllowedToAddress[_secondGemId];

        // Every time a TkGEM gets Forging, counter is incremented.
        forgingTkGEMs++;

        // Emit the forging event.
        emit Forging(GEMIndexToOwner[_firstGemId], _firstGemId, _secondGemId, firstGem.cooldownEndBlock);
    }

    /// @notice forge a Gem you own with a second Gem that you own. Will either make your gem Forging, or will
    ///  fail entirely.
    /// @param _firstGemId The ID of the TkGEM acting as first gem (will end up Forging if successful)
    /// @param _secondGemId The ID of the TkGEM acting as second gem (will begin its forging cooldown if successful)
    function forgeWithAuto(uint256 _firstGemId, uint256 _secondGemId) external whenNotPaused {
        require(_ownsGEM(msg.sender, _firstGemId));
        require(_ownsGEM(msg.sender, _secondGemId));

        // Grab a reference to the potential matron
        tkGEM storage firstGem = tkGEMs[_firstGemId];

        // Make sure first gem isn't Forging, or in the middle of a forging cooldown
        require(_isReadyToforge(firstGem));

        // Grab a reference to the potential second gem
        tkGEM storage secondGem = tkGEMs[_secondGemId];

        // Make sure second gem isn't Forging, or in the middle of a forging cooldown
        require(_isReadyToforge(secondGem));

        // All checks passed, gems gets Forging
        _forgeWith(_firstGemId, _secondGemId);
    }

    /// @notice Have a Forging TkGEM
    /// @param _FirstGemId first gem to firge
    /// @param _SecondGemId second Gem to forge
    /// @return The ID of the new tkGEM.
    /// @dev Looks at a given TkGEM and, if Forging and if the gestation period has passed,
    ///  combines the shape of the two parents to create a new tkGEM. The new TkGEM is assigned
    ///  to the current owner of the matron. Upon successful completion, both the matron and the
    ///  new tkGEM will be ready to forge again. Note that anyone can call this function (if they
    ///  are willing to pay the gas!), but the new tkGEM always goes to the mother's owner.
    function forge(uint256 _FirstGemId, uint256 _SecondGemId) external whenNotPaused returns (uint256) {
        // Grab a reference to the Gem in storage.
        tkGEM storage firstGem = tkGEMs[_FirstGemId];
        tkGEM storage secondGem = tkGEMs[_SecondGemId];

        // Check that the first Gem is a valid gem.
        require(firstGem.forgeTime != 0);

        // Determine the higher generation number of the two parents
        uint16 parentGen = firstGem.generation;
        if (secondGem.generation > firstGem.generation) {
            parentGen = secondGem.generation;
        }

        // Call the gene mixing operation.
        uint256 childshape = shapecience.mixshape(firstGem.shape, secondGem.shape, firstGem.cooldownEndBlock - 1);

        // Make the new tkGEM!
        address owner = GEMIndexToOwner[_FirstGemId];
        uint256 GEMId = _createGEM(parentGen + 1, childshape, owner);

        // Every time a TkGEM is forged, counter is decremented.
        forgingTkGEMs--;

        // Delete the parent gems from storage
        _deleteGEM(_FirstGemId);
        _deleteGEM(_SecondGemId);

        // return the new tkGEM's ID
        return GEMId;
    }

    /// @dev Internal function to delete a GEM from storage and update mappings
    function _deleteGEM(uint256 _GemId) internal {
        // Remove the GEM from the tkGEMs array by setting it to a default value
        delete tkGEMs[_GemId];

        // Update ownership mappings
        address owner = GEMIndexToOwner[_GemId];
        if (owner != address(0)) {
            ownershipTokenCount[owner]--;
            delete GEMIndexToOwner[_GemId];
            delete GEMIndexToApproved[_GemId];
            delete gemAllowedToAddress[_GemId];
        }
    }
}

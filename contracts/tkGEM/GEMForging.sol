// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GEMOwnership} from "./GEMOwnership.sol";
import {GEMStorage} from "./GEMStorage.sol";

contract GEMForging is GEMOwnership {
    event Forged(address owner, uint256 firstGemId, uint256 secondGemId);
    event Splitted(address owner, uint256 GemId);

    /// @notice Have a Forged GEM
    /// @param _FirstGemId first gem to forge
    /// @param _SecondGemId second Gem to forge
    /// @return The ID of the new tkGEM.
    function forge(uint256 _FirstGemId, uint256 _SecondGemId) external whenNotPaused returns (uint256) {
        require(_ownsGEM(msg.sender, _FirstGemId));
        require(_ownsGEM(msg.sender, _SecondGemId));

        // add checks to ensure First or Second GEMs is not an Herloom (can't be forged)

        // estimate the shape of the forged GEM

        tkGEM storage firstGem = tkGEMs[_FirstGemId];
        tkGEM storage secondGem = tkGEMs[_SecondGemId];
        uint256 childshape = shapecience.estimateShapeForgedGem(firstGem.shape, secondGem.shape);

        // transfer the new tkGEM from the pre minted pool of nft to the user
        uint256 GEMId = getSpecificShapeTokenId(childshape);

        // reassign the parent gems to GEMOwnership contract
        _reinitializeGem(_FirstGemId);
        _reinitializeGem(_SecondGemId);

        // send the forged GEM to msg.sender
        super.approveGEM(msg.sender, GEMId);
        super.transferGEMFrom(address(this), msg.sender, GEMId);

        emit Forged(msg.sender, _FirstGemId, _SecondGemId);

        // return the new tkGEM's ID
        return GEMId;
    }

    /// @notice Have Splitted GEMs
    /// @param _GemId gem to split
    /// @return GEMIds IDs of the new tkGEMs.
    function split(uint256 _GemId) external whenNotPaused returns (uint256[] memory GEMIds) {
        require(_ownsGEM(msg.sender, _GemId));

        // add checks to ensure the GEM is not a basic Gem (can't be splitted)

        // estimate the shape of the forged GEMs

        tkGEM storage Gem = tkGEMs[_GemId];
        uint256 childshape = shapecience.estimateShapeSplittedGems(Gem.shape);

        // reassign the parent gem to GEMOwnership contract
        _reinitializeGem(_GemId);

        // Initialize the GEMIds array with the length of 2
        GEMIds = new uint256[](2);

        for (uint256 i = 0; i < 2; i++) {
            // transfer the new tkGEM from the pre minted pool of nft to the user
            uint256 GEMId = getSpecificShapeTokenId(childshape);
            GEMIds[i] = GEMId;

            // send the splitted GEMs to msg.sender
            super.approveGEM(msg.sender, GEMId);
            super.transferGEMFrom(address(this), msg.sender, GEMId);
        }

        emit Splitted(msg.sender, _GemId);

        // return the new tkGEM's ID
        return GEMIds;
    }
}

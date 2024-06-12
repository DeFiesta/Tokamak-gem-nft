// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GEMAccessControl} from "./GEMAccessControl.sol";

contract GEMStorage is GEMAccessControl {
    struct tkGEM {
        uint256 shape;
        uint64 cooldownEndBlock;
        uint32 tokenId;
    }

    /**
     * CONSTANTS **
     */

    uint32[14] public cooldowns = [
        uint32(1 minutes),
        uint32(2 minutes),
        uint32(5 minutes),
        uint32(10 minutes),
        uint32(30 minutes),
        uint32(1 hours),
        uint32(2 hours),
        uint32(4 hours),
        uint32(8 hours),
        uint32(16 hours),
        uint32(1 days),
        uint32(2 days),
        uint32(4 days),
        uint32(7 days)
    ];

    uint256 public secondsPerBlock = 15;

    tkGEM[] tkGEMs;
    mapping(uint256 => bool) public PreMintedGEMAvailable;
    mapping(uint256 => address) public GEMIndexToOwner;
    mapping(address => uint256) ownershipTokenCount;
    mapping(uint256 => address) public GEMIndexToApproved;
    mapping(uint256 => address) public gemAllowedToAddress;

    /**
     * EVENTS **
     */

    event Created(address owner, uint256 tkGEMId, uint256 shape);
    event TransferTKGEM(address from, address to, uint256 tokenId);

    // ----------------------------------------------------------------------------------------
    // ----------------------------- INTERNAL FUNCTIONS----------------------------------------
    // ----------------------------------------------------------------------------------------

    function _transferGEM(address _from, address _to, uint256 _tokenId) internal {
        ownershipTokenCount[_to]++;
        GEMIndexToOwner[_tokenId] = _to;
        ownershipTokenCount[_from]--;
        delete gemAllowedToAddress[_tokenId];
        delete GEMIndexToApproved[_tokenId];
    }

    function _createGEM(uint256 _shape, address _owner) internal returns (uint256) {
        tkGEM memory _tkGEM = tkGEM({shape: _shape, cooldownEndBlock: 0, tokenId: 0});
        tkGEMs.push(_tkGEM);
        uint256 newTKGEMId = tkGEMs.length - 1;

        // safe check on the token Id created
        require(newTKGEMId == uint256(uint32(newTKGEMId)));
        _tkGEM.tokenId = uint32(newTKGEMId);
        GEMIndexToOwner[newTKGEMId] = _owner;

        emit Created(_owner, newTKGEMId, _tkGEM.shape);
        _transferGEM(address(0), _owner, newTKGEMId);
        return newTKGEMId;
    }

    function setSecondsPerBlock(uint256 secs) external onlyCLevel {
        require(secs < cooldowns[0]);
        secondsPerBlock = secs;
    }
}

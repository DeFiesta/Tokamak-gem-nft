// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GEMAccessControl} from "./GEMAccessControl.sol";
import {SaleClockAuction} from "./auction/SaleClockAuction.sol";

contract GEMBase is GEMAccessControl {
    struct tkGEM {
        uint256 shape;
        uint64 forgeTime; // timestamp of GEM creation
        uint64 cooldownEndBlock;
        uint32 GemId;
        uint32 forgingWithId;
        uint16 cooldownIndex;
        uint16 generation;
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

    /**
     * STORAGE **
     */

    tkGEM[] tkGEMs;
    mapping(uint256 => address) public GEMIndexToOwner;
    mapping(address => uint256) ownershipTokenCount;
    mapping(uint256 => address) public GEMIndexToApproved;
    mapping(uint256 => address) public gemAllowedToAddress;
    SaleClockAuction public saleAuction;

    /**
     * EVENTS **
     */

    event Forged(address owner, uint256 tkGEMId, uint256 shape);
    event TransferTKGEM(address from, address to, uint256 tokenId);

    // ----------------------------------------------------------------------------------------
    // ----------------------------- INTERNAL FUNCTIONS----------------------------------------
    // ----------------------------------------------------------------------------------------

    function _transferGEM(address _from, address _to, uint256 _tokenId) internal virtual {
        ownershipTokenCount[_to]++;
        GEMIndexToOwner[_tokenId] = _to;
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            delete gemAllowedToAddress[_tokenId];
            delete GEMIndexToApproved[_tokenId];
        }
        emit TransferTKGEM(_from, _to, _tokenId);
    }

    function _createGEM(uint256 _firstGem, uint256 _secondGem, uint256 _generation, uint256 _shape, address _owner)
        internal
        returns (uint256)
    {
        require(_firstGem == uint256(uint32(_firstGem)));
        require(_secondGem == uint256(uint32(_secondGem)));
        require(_generation == uint256(uint16(_generation)));
        uint16 cooldownIndex = uint16(_generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }
        tkGEM memory _tkGEM = tkGEM({
            shape: _shape,
            forgeTime: uint64(block.timestamp),
            cooldownEndBlock: 0,
            GemId: 0,
            forgingWithId: 0,
            cooldownIndex: cooldownIndex,
            generation: uint16(_generation)
        });
        tkGEMs.push(_tkGEM);
        uint256 newTKGEMId = tkGEMs.length - 1;
        require(newTKGEMId == uint256(uint32(newTKGEMId)));
        _tkGEM.GemId = uint32(newTKGEMId);
        emit Forged(_owner, newTKGEMId, _tkGEM.shape);
        _transferGEM(address(0), _owner, newTKGEMId);
        return newTKGEMId;
    }

    function setSecondsPerBlock(uint256 secs) external onlyCLevel {
        require(secs < cooldowns[0]);
        secondsPerBlock = secs;
    }
}

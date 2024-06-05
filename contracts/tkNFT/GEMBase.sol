// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTAccessControl} from "./GEMAccessControl.sol";
import {SaleClockAuction} from "./auction/SaleClockAuction.sol";
import {SiringClockAuction} from "./auction/SiringClockAuction.sol";

contract NFTBase is NFTAccessControl {
    struct tkNFT {
        uint256 genes;
        uint64 birthTime;
        uint64 cooldownEndBlock;
        uint32 matronId;
        uint32 sireId;
        uint32 siringWithId;
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

    tkNFT[] tkNFTs;
    mapping(uint256 => address) public NFTIndexToOwner;
    mapping(address => uint256) ownershipTokenCount;
    mapping(uint256 => address) public NFTIndexToApproved;
    mapping(uint256 => address) public sireAllowedToAddress;
    SaleClockAuction public saleAuction;
    SiringClockAuction public siringAuction;

    /**
     * EVENTS **
     */

    event Birth(address owner, uint256 tkNFTId, uint256 matronId, uint256 sireId, uint256 genes);
    event TransferTKNFT(address from, address to, uint256 tokenId);

    // ----------------------------------------------------------------------------------------
    // ----------------------------- INTERNAL FUNCTIONS----------------------------------------
    // ----------------------------------------------------------------------------------------

    function _transferNFT(address _from, address _to, uint256 _tokenId) internal virtual {
        ownershipTokenCount[_to]++;
        NFTIndexToOwner[_tokenId] = _to;
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            delete sireAllowedToAddress[_tokenId];
            delete NFTIndexToApproved[_tokenId];
        }
        emit TransferTKNFT(_from, _to, _tokenId);
    }

    function _createNFT(uint256 _matronId, uint256 _sireId, uint256 _generation, uint256 _genes, address _owner)
        internal
        returns (uint256)
    {
        require(_matronId == uint256(uint32(_matronId)));
        require(_sireId == uint256(uint32(_sireId)));
        require(_generation == uint256(uint16(_generation)));

        uint16 cooldownIndex = uint16(_generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }

        tkNFT memory _tkNFT = tkNFT({
            genes: _genes,
            birthTime: uint64(block.timestamp),
            cooldownEndBlock: 0,
            matronId: uint32(_matronId),
            sireId: uint32(_sireId),
            siringWithId: 0,
            cooldownIndex: cooldownIndex,
            generation: uint16(_generation)
        });
        tkNFTs.push(_tkNFT);
        uint256 newTKNFTId = tkNFTs.length - 1;

        require(newTKNFTId == uint256(uint32(newTKNFTId)));

        emit Birth(_owner, newTKNFTId, uint256(_tkNFT.matronId), uint256(_tkNFT.sireId), _tkNFT.genes);

        _transferNFT(address(0), _owner, newTKNFTId);

        return newTKNFTId;
    }

    function setSecondsPerBlock(uint256 secs) external onlyCLevel {
        require(secs < cooldowns[0]);
        secondsPerBlock = secs;
    }
}

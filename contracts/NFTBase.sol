// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTBase is ERC721, Ownable {
    struct tkNFT {
        address owner;
        uint256 tokenId;
        string genes; // Store genes as a string
        uint64 birthTime;
        uint32 matronId; //mom's id
        uint32 sireId; // dad's id
        uint32 siringWithId; //if set then pregnant
        uint16 cooldownIndex; // like age. bigger it is, longer is the cooldown
        uint16 generation;
    }

    tkNFT[] public tkNFTs;

    uint256 private _currentTokenId = 0;

    event Minted(address indexed _to, uint256 _newTokenId, string genes);

    constructor() ERC721("Tokamak GEM NFT", "TKNFT") Ownable(msg.sender) {}

    function mintTkNFT(
        address to,
        string memory genes,
        uint64 birthTime,
        uint32 matronId,
        uint32 sireId,
        uint32 siringWithId,
        uint16 cooldownIndex,
        uint16 generation
    ) external onlyOwner {
        require(_isValidGene(genes), "Invalid gene format");
        _incrementTokenId();
        uint256 newTokenId = _getTokenId();
        _mintTkNFT(to, newTokenId, genes, birthTime, matronId, sireId, siringWithId, cooldownIndex, generation);
        emit Minted(to, newTokenId, genes);
    }

    function _mintTkNFT(
        address _to,
        uint256 _newTokenId,
        string memory _genes,
        uint64 _birthTime,
        uint32 _matronId,
        uint32 _sireId,
        uint32 _siringWithId,
        uint16 _cooldownIndex,
        uint16 _generation
    ) internal {
        tkNFT memory newTkNFT = tkNFT({
            owner: _to,
            tokenId: _newTokenId,
            genes: _genes,
            birthTime: _birthTime,
            matronId: _matronId,
            sireId: _sireId,
            siringWithId: _siringWithId,
            cooldownIndex: _cooldownIndex,
            generation: _generation
        });

        tkNFTs.push(newTkNFT);

        _safeMint(_to, _newTokenId);
    }

    function _getTokenId() private view returns (uint256) {
        return _currentTokenId;
    }

    function _incrementTokenId() private {
        _currentTokenId++;
    }

    function _isValidGene(string memory gene) private pure returns (bool) {
        bytes memory b = bytes(gene);
        if (b.length != 10) return false; // Ensure the gene string is 10 characters long (5 pairs of hex digits)
        for (uint256 i = 0; i < b.length; i++) {
            if (
                !(b[i] >= 0x30 && b[i] <= 0x39) // 0-9
                    && !(b[i] >= 0x41 && b[i] <= 0x46) // A-F
                    && !(b[i] >= 0x61 && b[i] <= 0x66) // a-f
            ) {
                return false;
            }
        }
        return true;
    }

    // Function to get the gene characteristics
    function getGeneCharacteristics(uint256 tokenId) public view returns (string memory) {
        require(tokenId < tkNFTs.length, "Token ID does not exist");
        return tkNFTs[tokenId].genes;
    }

    // Function to parse gene characteristics
    function parseGene(string memory gene) public pure returns (string memory) {
        require(_isValidGene(gene), "Invalid gene format");
        bytes memory b = bytes(gene);
        string memory eyeColor = _getEyeColor(b[0], b[1]);
        // Add more parsing logic for other characteristics here
        return eyeColor;
    }

    function _getEyeColor(bytes1 x1, bytes1 x2) private pure returns (string memory) {
        // Example logic to determine eye color from gene
        if (x1 == 0x31 && x2 == 0x34) {
            // 14 in hex
            return "yellow";
        }
        // Add more conditions for other eye colors
        return "unknown";
    }
}

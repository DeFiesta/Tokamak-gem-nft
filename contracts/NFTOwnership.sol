// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {NFTBase} from "./NFTBase.sol";

/// @title The external contract that is responsible for generating metadata for the TKNFTs,
///  it has one function that will return the data as bytes.
contract ERC721Metadata {
    /// @dev Given a token Id, returns a byte array that is supposed to be converted into string.
    function getMetadata(uint256 _tokenId, string memory)
        public
        pure
        returns (bytes32[4] memory buffer, uint256 count)
    {
        if (_tokenId == 1) {
            buffer[0] = "Hello World! :D";
            count = 15;
        } else if (_tokenId == 2) {
            buffer[0] = "I would definitely choose a medi";
            buffer[1] = "um length string.";
            count = 49;
        } else if (_tokenId == 3) {
            buffer[0] = "Lorem ipsum dolor sit amet, mi e";
            buffer[1] = "st accumsan dapibus augue lorem,";
            buffer[2] = " tristique vestibulum id, libero";
            buffer[3] = " suscipit varius sapien aliquam.";
            count = 128;
        }
    }
}

contract NFTOwnership is NFTBase, ERC721 {
    // The contract that will return TKNFT metadata
    ERC721Metadata public erc721Metadata;

    bytes4 constant InterfaceSignature_ERC165 = bytes4(keccak256("supportsInterface(bytes4)"));

    constructor() ERC721("TokamakNFT", "TKNFT") {}

    /// @notice Introspection interface as per ERC-165 (https://github.com/ethereum/EIPs/issues/165).
    ///  Returns true for any standardized interfaces implemented by this contract. We implement
    ///  ERC-165 (obviously!) and ERC-721.
    function supportsInterfaceNFT(bytes4 _interfaceID) external pure returns (bool) {
        // DEBUG ONLY
        //require((InterfaceSignature_ERC165 == 0x01ffc9a7) && (InterfaceSignature_ERC721 == 0x9a20483d));

        return ((_interfaceID == InterfaceSignature_ERC165) || (_interfaceID == type(IERC721).interfaceId));
    }

    /// @dev Set the address of the sibling contract that tracks metadata.
    ///  CEO only.
    function setMetadataAddress(address _contractAddress) public onlyCEO {
        erc721Metadata = ERC721Metadata(_contractAddress);
    }

    // Internal utility functions: These functions all assume that their input arguments
    // are valid. We leave it to public methods to sanitize their inputs and follow
    // the required logic.

    /// @dev Checks if a given address is the current owner of a particular TKNFT.
    /// @param _claimant the address we are validating against.
    /// @param _tokenId TKNFT id, only valid when > 0
    function _ownsNFT(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return NFTIndexToOwner[_tokenId] == _claimant;
    }

    /// @dev Checks if a given address currently has transferApproval for a particular TKNFT.
    /// @param _claimant the address we are confirming kitten is approved for.
    /// @param _tokenId TKNFT id, only valid when > 0
    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return NFTIndexToApproved[_tokenId] == _claimant;
    }

    /// @dev Marks an address as being approved for transferFrom(), overwriting any previous
    ///  approval. Setting _approved to address(0) clears all transfer approval.
    ///  NOTE: _approve() does NOT send the Approval event. This is intentional because
    ///  _approve() and transferFrom() are used together for putting TKNFTs on auction, and
    ///  there is no value in spamming the log with Approval events in that case.
    function _approve(uint256 _tokenId, address _approved) internal {
        NFTIndexToApproved[_tokenId] = _approved;
    }

    /// @notice Returns the number of TKNFTs owned by a specific address.
    /// @param _owner The owner address to check.
    /// @dev Required for ERC-721 compliance
    function balanceOf(address _owner) public view override returns (uint256 count) {
        return ownershipTokenCount[_owner];
    }

    /// @notice Transfers a TKNFTs to another address. If transferring to a smart
    ///  contract be VERY CAREFUL to ensure that it is aware of ERC-721 or your TKNFT may be lost forever.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _tokenId The ID of the TKNFT to transfer.
    /// @dev Required for ERC-721 compliance.
    function transfer(address _to, uint256 _tokenId) external whenNotPaused {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        // Disallow transfers to this contract to prevent accidental misuse.
        // The contract should never own any kitties (except very briefly
        // after a gen0 cat is created and before it goes on auction).
        require(_to != address(this));
        // Disallow transfers to the auction contracts to prevent accidental
        // misuse. Auction contracts should only take ownership of kitties
        // through the allow + transferFrom flow.
        require(_to != address(saleAuction));
        require(_to != address(siringAuction));

        // You can only send your own cat.
        require(_ownsNFT(msg.sender, _tokenId));

        // Reassign ownership, clear pending approvals, emit Transfer event.
        _transferNFT(msg.sender, _to, _tokenId);
    }

    /// @notice Grant another address the right to transfer a specific tkNFT via
    ///  transferFrom(). This is the preferred flow for transfering NFTs to contracts.
    /// @param _to The address to be granted transfer approval. Pass address(0) to
    ///  clear all approvals.
    /// @param _tokenId The ID of the tkNFT that can be transferred if this call succeeds.
    /// @dev Required for ERC-721 compliance.
    function approveNFT(address _to, uint256 _tokenId) external whenNotPaused {
        // Only an owner can grant transfer approval.
        require(_ownsNFT(msg.sender, _tokenId));

        // Register the approval (replacing any previous approval).
        _approve(_tokenId, _to);

        // Emit approval event.
        emit Approval(msg.sender, _to, _tokenId);
    }

    /// @notice Transfer a tkNFT owned by another address, for which the calling address
    ///  has previously been granted transfer approval by the owner.
    /// @param _from The address that owns the tkNFT to be transfered.
    /// @param _to The address that should take ownership of the tkNFT. Can be any address,
    ///  including the caller.
    /// @param _tokenId The ID of the tkNFT to be transferred.
    /// @dev Required for ERC-721 compliance.
    function transferNFTFrom(address _from, address _to, uint256 _tokenId) external whenNotPaused {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        // Disallow transfers to this contract to prevent accidental misuse.
        // The contract should never own any kitties (except very briefly
        // after a gen0 cat is created and before it goes on auction).
        require(_to != address(this));
        // Check for approval and valid ownership
        require(_approvedFor(msg.sender, _tokenId));
        require(_ownsNFT(_from, _tokenId));

        // Reassign ownership (also clears pending approvals and emits Transfer event).
        _transferNFT(_from, _to, _tokenId);
    }

    /// @notice Returns the total number of Kitties currently in existence.
    /// @dev Required for ERC-721 compliance.
    function totalSupply() public view returns (uint256) {
        return tkNFTs.length - 1;
    }

    /// @notice Returns the address currently assigned ownership of a given tkNFT.
    /// @dev Required for ERC-721 compliance.
    function ownerOfNFT(uint256 _tokenId) external view returns (address owner) {
        owner = NFTIndexToOwner[_tokenId];

        require(owner != address(0));
    }

    /// @notice Returns a list of all tkNFT IDs assigned to an address.
    /// @param _owner The owner whose Kitties we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. First, it's fairly
    ///  expensive (it walks the entire tkNFT

    function tokensOfOwner(address _owner) external view returns (uint256[] memory ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalCats = totalSupply();
            uint256 resultIndex = 0;

            // We count on the fact that all cats have IDs starting at 1 and increasing
            // sequentially up to the totalCat count.
            uint256 catId;

            for (catId = 1; catId <= totalCats; catId++) {
                if (NFTIndexToOwner[catId] == _owner) {
                    result[resultIndex] = catId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

    /// @dev Adapted from memcpy() by @arachnid (Nick Johnson <arachnid@notdot.net>)
    ///  This method is licenced under the Apache License.
    ///  Ref: https://github.com/Arachnid/solidity-stringutils/blob/2f6ca9accb48ae14c66f1437ec50ed19a0616f78/strings.sol
    function _memcpy(uint256 _dest, uint256 _src, uint256 _len) private pure {
        // Copy word-length chunks while possible
        for (; _len >= 32; _len -= 32) {
            assembly {
                mstore(_dest, mload(_src))
            }
            _dest += 32;
            _src += 32;
        }

        // Copy remaining bytes
        uint256 mask = 256 ** (32 - _len) - 1;
        assembly {
            let srcpart := and(mload(_src), not(mask))
            let destpart := and(mload(_dest), mask)
            mstore(_dest, or(destpart, srcpart))
        }
    }

    /// @dev Adapted from toString(slice) by @arachnid (Nick Johnson <arachnid@notdot.net>)
    ///  This method is licenced under the Apache License.
    ///  Ref: https://github.com/Arachnid/solidity-stringutils/blob/2f6ca9accb48ae14c66f1437ec50ed19a0616f78/strings.sol
    function _toString(bytes32[4] memory _rawBytes, uint256 _stringLength) private pure returns (string memory) {
        string memory outputString = new string(_stringLength);
        uint256 outputPtr;
        uint256 bytesPtr;

        assembly {
            outputPtr := add(outputString, 32)
            bytesPtr := _rawBytes
        }

        _memcpy(outputPtr, bytesPtr, _stringLength);

        return outputString;
    }

    /// @notice Returns a URI pointing to a metadata package for this token conforming to
    ///  ERC-721 (https://github.com/ethereum/EIPs/issues/721)
    /// @param _tokenId The ID number of the tkNFT whose metadata should be returned.
    function tokenMetadata(uint256 _tokenId, string memory _preferredTransport)
        external
        view
        returns (string memory infoUrl)
    {
        require(address(erc721Metadata) != address(0));
        bytes32[4] memory buffer;
        uint256 count;
        (buffer, count) = erc721Metadata.getMetadata(_tokenId, _preferredTransport);

        return _toString(buffer, count);
    }
}

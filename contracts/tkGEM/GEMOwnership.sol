// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {GEMStorage} from "./GEMStorage.sol";

interface IVDFShapeScience {
    function isshapecience() external pure returns (bool);
    function generateRandomUint256() external returns (uint256);
    function estimateShapeForgedGem(uint256 _shape1, uint256 _shape2) external returns (uint256);
    function estimateShapeSplittedGems(uint256 _shape) external returns (uint256);
}

/// @title The external contract that is responsible for generating metadata for the TKGEMs,
///  it has one function that will return the data as bytes.
contract ERC721Metadata {
    /// @dev Given a token Id, returns a byte array that is supposed to be converted into string.
    function getMetadata(uint256 _tokenId, string memory)
        public
        pure
        returns (bytes32[4] memory buffer, uint256 count)
    {
        if (_tokenId == 1) {
            buffer[0] = "BASIC GEM 1";
            count = 15;
        } else if (_tokenId == 2) {
            buffer[0] = "BASIC GEM 1";
            buffer[1] = "DESCRIPTION";
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

contract GEMOwnership is GEMStorage, ERC721 {
    ERC721Metadata public erc721Metadata;

    bytes4 constant InterfaceSignature_ERC165 = bytes4(keccak256("supportsInterface(bytes4)"));

    IVDFShapeScience public shapecience;

    constructor() ERC721("TokamakGEM", "TKGEM") {}

    //---------------------------------------------------------------------------------------
    //--------------------------EXTERNAL FUNCTIONS-------------------------------------------
    //---------------------------------------------------------------------------------------

    /// @notice Transfers a TKGEMs to another address.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _tokenId The ID of the TKGEM to transfer.
    function transfer(address _to, uint256 _tokenId) external whenNotPaused {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0) && msg.sender != address(0));

        // You can only send your own gem.
        require(_ownsGEM(msg.sender, _tokenId));

        // storage variables update
        _transferGEM(msg.sender, _to, _tokenId);

        // Reassign ownership,
        safeTransferFrom(msg.sender, _to, _tokenId);

        emit TransferTKGEM(msg.sender, _to, _tokenId);
    }

    function _reinitializeGem(uint256 _tokenId) public whenNotPaused {
        require(_tokenId > 0, "token ID must be > 0");
        GEMIndexToOwner[_tokenId] = address(this);
        PreMintedGEMAvailable[_tokenId] = true;
        _transferGEM(msg.sender, address(this), _tokenId);
        safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    /// @notice Grant another address the right to transfer a specific tkGEM via
    ///  transferFrom(). This is the preferred flow for transfering GEMs to contracts.
    /// @param _to The address to be granted transfer approval. Pass address(0) to
    ///  clear all approvals.
    /// @param _tokenId The ID of the tkGEM that can be transferred if this call succeeds.
    function approveGEM(address _to, uint256 _tokenId) public whenNotPaused {
        // Only an owner can grant transfer approval.
        require(_ownsGEM(msg.sender, _tokenId));

        // Register the approval (replacing any previous approval).
        _approve(_tokenId, _to);

        // Emit approval event.
        emit Approval(msg.sender, _to, _tokenId);
    }

    /// @notice Transfer a tkGEM owned by another address, for which the calling address
    ///  has previously been granted transfer approval by the owner.
    /// @param _from The address that owns the tkGEM to be transfered.
    /// @param _to The address that should take ownership of the tkGEM. Can be any address,
    ///  including the caller.
    /// @param _tokenId The ID of the tkGEM to be transferred.
    function transferGEMFrom(address _from, address _to, uint256 _tokenId) public whenNotPaused {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        require(_approvedFor(msg.sender, _tokenId));
        require(_ownsGEM(_from, _tokenId));

        //update state variables
        _transferGEM(_from, _to, _tokenId);
        // Reassign ownership (also clears pending approvals and emits Transfer event).
        safeTransferFrom(_from, _to, _tokenId);
        //emit transfer event
        emit TransferTKGEM(_from, _to, _tokenId);
    }

    function supportsInterfaceGEM(bytes4 _interfaceID) external pure returns (bool) {
        return ((_interfaceID == InterfaceSignature_ERC165) || (_interfaceID == type(IERC721).interfaceId));
    }

    /// @dev Set the address of the ERC721Metadata contract that tracks metadata.
    ///  CEO only.
    function setMetadataAddress(address _contractAddress) external onlyCEO {
        erc721Metadata = ERC721Metadata(_contractAddress);
    }

    /// @dev Update the address of the genetic contract, can only be called by the CEO.
    /// @param _address An address of a shapecience contract instance to be used from this point forward.

    function setshapecienceAddress(address _address) external onlyCEO {
        IVDFShapeScience candidateContract = IVDFShapeScience(_address);

        require(candidateContract.isshapecience());

        // Set the new contract address
        shapecience = candidateContract;
    }

    //---------------------------------------------------------------------------------------
    //--------------------------INERNAL FUNCTIONS--------------------------------------------
    //---------------------------------------------------------------------------------------

    /// @dev Checks if a given address is the current owner of a particular TKGEM.
    /// @param _claimant the address we are validating against.
    /// @param _tokenId TKGEM id, only valid when > 0
    function _ownsGEM(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return GEMIndexToOwner[_tokenId] == _claimant;
    }

    /// @dev Checks if a given address currently has transferApproval for a particular TKGEM.
    /// @param _claimant the address we are confirming tkGEM is approved for.
    /// @param _tokenId TKGEM id, only valid when > 0
    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return GEMIndexToApproved[_tokenId] == _claimant;
    }

    /// @dev Marks an address as being approved for transferFrom(), overwriting any previous
    ///  approval. Setting _approved to address(0) clears all transfer approval.
    function _approve(uint256 _tokenId, address _approved) internal {
        GEMIndexToApproved[_tokenId] = _approved;
    }

    /// @notice Returns the number of TKGEMs owned by a specific address.
    /// @param _owner The owner address to check.
    function balanceOf(address _owner) public view override returns (uint256 count) {
        return ownershipTokenCount[_owner];
    }

    function getSpecificShapeTokenId(uint256 _shape) public view returns (uint256 tokenId) {
        for (uint256 i = 0; i < tkGEMs.length; i++) {
            if (tkGEMs[i].shape == _shape && GEMIndexToOwner[i] == address(this)) {
                return i;
            }
        }
        revert("No available token with the specified shape was found");
    }

    /// @notice Returns the total number of tkGEMs currently in existence.
    function totalSupply() public view returns (uint256) {
        return tkGEMs.length - 1;
    }

    /// @notice Returns the address currently assigned ownership of a given tkGEM.
    function ownerOfGEM(uint256 _tokenId) external view returns (address owner) {
        owner = GEMIndexToOwner[_tokenId];

        require(owner != address(0));
    }

    /// @notice Returns a list of all tkGEM IDs assigned to an address.
    /// @param _owner The owner whose tkGEMs we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. First, it's fairly
    ///  expensive (it walks the entire tkGEM)

    function tokensOfOwner(address _owner) external view returns (uint256[] memory ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalGems = totalSupply();
            uint256 resultIndex = 0;

            // We count on the fact that all gems have IDs starting at 1 and increasing
            // sequentially up to the totalCat count.
            uint256 gemId;

            for (gemId = 1; gemId <= totalGems; gemId++) {
                if (GEMIndexToOwner[gemId] == _owner) {
                    result[resultIndex] = gemId;
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
    /// @param _tokenId The ID number of the tkGEM whose metadata should be returned.
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

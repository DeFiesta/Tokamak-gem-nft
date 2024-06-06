// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IGEMOwnership {
    function supportsInterfaceGEM(bytes4 _interfaceID) external pure returns (bool);
    function setMetadataAddress(address _contractAddress) external;
    function transfer(address _to, uint256 _tokenId) external;
    function approveGEM(address _to, uint256 _tokenId) external;
    function transferGEMFrom(address _from, address _to, uint256 _tokenId) external;
    function ownerOfGEM(uint256 _tokenId) external view returns (address owner);
    function tokensOfOwner(address _owner) external view returns (uint256[] memory ownerTokens);
    function tokenMetadata(uint256 _tokenId, string memory _preferredTransport)
        external
        view
        returns (string memory infoUrl);
}

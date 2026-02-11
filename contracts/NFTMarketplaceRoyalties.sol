// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplaceRoyalties is ERC721URIStorage, ERC2981, Ownable {
    uint256 public nextTokenId = 1;

    event DefaultRoyaltySet(address receiver, uint96 feeNumerator);

    constructor(address defaultReceiver, uint96 defaultFee) ERC721("BaseNFT", "BNFT") Ownable(msg.sender) {
        require(defaultReceiver != address(0), "receiver=0");
        _setDefaultRoyalty(defaultReceiver, defaultFee);
        emit DefaultRoyaltySet(defaultReceiver, defaultFee);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        require(receiver != address(0), "receiver=0");
        require(feeNumerator <= 2000, "too high");
        _setDefaultRoyalty(receiver, feeNumerator);
        emit DefaultRoyaltySet(receiver, feeNumerator);
    } 

    function mint(address to, string calldata uri) external returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
 

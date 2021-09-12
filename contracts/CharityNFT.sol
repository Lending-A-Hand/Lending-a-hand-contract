// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CharityNFT is ERC721, Ownable{
    
    enum nftStatus { pending, accept} 

    mapping(uint256 => string)  private _tokenURIs;
    mapping(uint256 => nftStatus) private _tokenStatus;
    
    event TokenBurn(uint256 tokenId);
    
    constructor (string memory name_, string memory symbol_) ERC721(name_, symbol_) {}
    /***********************************|
    |           Mint function           |
    |__________________________________*/
    
    function mint(uint256 tokenId, string memory uri) external returns (bool) {
        _mint(msg.sender, tokenId);
        require(tokenId > 0, "CharityNFT: tokenId invalid");
        _tokenURIs[tokenId] = uri;
        _tokenStatus[tokenId] = nftStatus.pending;
        return true;
    }

    function burn(uint256 tokenId) external returns (bool) {
        _burn(tokenId);
        require(tokenId > 0, "CharityNFT: tokenId invalid");
        _tokenStatus[tokenId] = nftStatus.pending;
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
        emit TokenBurn(tokenId);
        return true;
    }
    
    function accept(uint256 tokenId) external {
        _tokenStatus[tokenId] = nftStatus.accept;
    }

    function transfer(uint256 tokenId, address receipient) external {
        _transfer(msg.sender, receipient, tokenId);
    }

    /***********************************|
    |            token URI              |
    |__________________________________*/
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "CharityNFT: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];

        return _tokenURI;
    }
    
    
    /***********************************|
    |          Getter Function          |
    |__________________________________*/
    
    function _baseURI() internal pure override returns (string memory) {
        return "https://api.jsonbin.io/b/";
    }
    
    function tokenStatus(uint256 tokenId) external view returns (bool) {
        if (_tokenStatus[tokenId] == nftStatus.accept)
            return true;
        return false;
    }
    /// https://api.jsonbin.io/b/6110fc75e1b0604017a9f471
    /// https://api.jsonbin.io/b/6110e47953ca131484a3471d
}

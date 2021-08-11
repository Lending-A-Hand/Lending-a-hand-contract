// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CharityNFT is ERC721, Ownable{

    uint256 private adjustZero;
    
    constructor (string memory name_, string memory symbol_, uint256 adjustZero_) ERC721(name_, symbol_) {
        adjustZero = adjustZero_;
    }
    
    mapping(uint256 => string)  private _tokenURIs;
    mapping(uint256 => uint256) private _poolTokenCount;
    
    event TokenBurn(uint256 tokenId, uint256 poolBalance);
    
    /***********************************|
    |           Mint function           |
    |__________________________________*/
    
    function mint(uint256 tokenId, string memory uri) external returns (bool) {
        _mint(msg.sender, tokenId);
        uint256 temp = tokenId / adjustZero;
        require(temp > 0, "CharityNFT: tokenId invalid");
        _poolTokenCount[temp] += 1;
        _tokenURIs[tokenId] = uri;
        
        return true;
    }
    
    function burn(uint256 tokenId) external returns (bool) {
        _burn(tokenId);
        uint256 temp = tokenId / adjustZero;
        require(temp > 0, "CharityNFT: tokenId invalid");
        _poolTokenCount[temp] -= 1;
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    
        emit TokenBurn(tokenId, _poolTokenCount[temp]);

        return true;
    }

    /***********************************|
    |            token URI              |
    |__________________________________*/
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "CharityNFT: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }
    
    
    /***********************************|
    |          Getter Function          |
    |__________________________________*/
    
    function _baseURI() internal pure override returns (string memory) {
        return "https://api.jsonbin.io/b/";
    }
    /// https://api.jsonbin.io/b/6110fc75e1b0604017a9f471
    /// https://api.jsonbin.io/b/6110e47953ca131484a3471d
}

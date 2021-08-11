// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./CharityNFT.sol";

contract NftPool is Ownable {

    struct poolStatRecord {
        uint256   curTokenId;
        uint256   pendingTokenCount;
        uint256   acceptTokenCount;
        uint256[] threshold; 
    }

    uint256 private indexGap = 1e6;
    uint256 private  poolCount;
    CharityNFT public charityNftContract;

    mapping(address => uint256) private poolIndex;
    mapping(uint256 => poolStatRecord) private poolStat;
    // msg.sender => poolIndex => rank
    mapping(address => mapping(uint256 => uint256)) public rankByPool;
    // tokenId => bool
    mapping(uint256 => bool) public acceptFlag;

    /***********************************|
    |              Event                |
    |__________________________________*/
    event AdjustThreshold(uint256 poolId, uint256[] newThreshold);

    /***********************************|
    |            Constructor            |
    |__________________________________*/

    constructor (string memory name_, string memory symbol_) onlyOwner {
        require(address(charityNftContract) == address(0), "NftPool: CharityNFT initialized");
        charityNftContract = new CharityNFT(name_, symbol_, indexGap);
    }

    /***********************************|
    |       Manipulate  Functions       |
    |__________________________________*/

    function initializePool(address receipient, uint256[] memory _threshold) public onlyOwner {
        require(poolIndex[receipient] == 0, "NftPool: pool initialized");
        poolCount++;
        poolIndex[receipient] = poolCount;
        poolStat[poolIndex[receipient]] = poolStatRecord( 0, 0, 0, _threshold);
    }

    function poolMintToken(address receipient, string memory uri) external {
        poolStat[poolIndex[receipient]].pendingTokenCount++;
        uint nextTokenId = poolStat[poolIndex[receipient]].curTokenId;
        require(charityNftContract.mint(dealTokenId(receipient, nextTokenId), uri), "NftPool: mint failed");
    }

    function acceptNFT(uint256 tokenId) external onlyOwner {
        require(acceptFlag[tokenId] == true, "NftPool: token already accept");
        acceptFlag[tokenId] = true;
        poolStat[tokenId/indexGap].pendingTokenCount--;
        poolStat[tokenId/indexGap].acceptTokenCount++;
    }

    function rejectNFT(uint256 tokenId) external onlyOwner {
        charityNftContract.burn(tokenId);
        poolStat[tokenId/indexGap].pendingTokenCount--;
    }

    function adjustThresholds(uint256 poolId, uint256[] memory newThreshold) external onlyOwner {
        poolStat[poolId].threshold = newThreshold;
        emit AdjustThreshold(poolId, newThreshold);
    }

    /*function claim(address receipient) {
        uint256 currentRank = rankByPool[msg.sender][receipient];
    }*/

    // function registerERC721() {

    // }


    /***********************************|
    |         Getter Functions          |
    |__________________________________*/

    function dealTokenId(address _receipient, uint256 _tokenId)
        internal
        view 
        returns (uint256 tokenId) 
    {
        tokenId = poolIndex[_receipient] * indexGap + _tokenId;
    }

    function getPoolStat(address receipient) 
        external 
        view 
        returns (uint256 curTokenId, uint256 pendingTokenCount, uint256 acceptTokenCount, uint256[] threshold) 
    {
        return (
            poolStat[poolIndex[receipient]].curTokenId,
            poolStat[poolIndex[receipient]].pendingTokenCount,
            poolStat[poolIndex[receipient]].acceptTokenCount,
            poolStat[poolIndex[receipient]].threshold
        );
    }

}

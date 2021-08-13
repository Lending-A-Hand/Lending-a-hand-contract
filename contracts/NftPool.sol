// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./CharityNFT.sol";

contract NftPool is Ownable {

    using Counters for Counters.Counter;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableSet for EnumerableSet.UintSet;

    struct poolStatRecord {
        uint256   poolId;
        uint256   pendingTokenCount;
        uint256   acceptTokenCount;
        address   underlyingAssets;
        uint256[] threshold; 
    }

    uint256 private poolCount;
    CharityNFT public charityNftContract;
    
    Counters.Counter private tokenCount;
    Counters.Counter private tokenBurn;
    // receipient => poolId
    mapping(address => uint256) private poolIndex;
    // pool => poolStatRecord
    mapping(uint256 => poolStatRecord) private poolStat;
    // pool => tokenId
    mapping(uint256 => EnumerableSet.UintSet) private poolToken;
    // poolId => addressid => address
    mapping(uint256 => EnumerableMap.UintToAddressMap) private poolReceiveNft;
    // address => poolId
    mapping(address => uint256[]) private poolReceiveNftMap;
    // msg.sender => poolIndex => rank
    mapping(address => mapping(uint256 => uint256)) public rankByPool;
    // tokenId => bool
    mapping(uint256 => bool) public acceptFlag;
    // pool => tokenId
    mapping(address => bool) public registered;
    
    uint256[] public showPoolNfts;

    /***********************************|
    |              Event                |
    |__________________________________*/
    event AdjustThreshold(uint256 poolId, uint256[] newThreshold);

    /***********************************|
    |            Constructor            |
    |__________________________________*/
    constructor (string memory name_, string memory symbol_) onlyOwner {
        require(address(charityNftContract) == address(0), "NftPool: CharityNFT initialized");
        charityNftContract = new CharityNFT(name_, symbol_);
    }
    
    /***********************************|
    |            Ｍodifier              |
    |__________________________________*/
    modifier thresholdCheck(uint256[] memory threshold) {
        for (uint256 i = 1; i < threshold.length; i++) {
            require(threshold[i] > threshold[i - 1], "NftPool: threshold error");
        }
        _;
    }
    
    /***********************************|
    |       Manipulate  Functions       |
    |__________________________________*/
    function initializePool(
        address receipient,
        address underlyingAsset,
        uint256[] memory threshold
    )   public 
        onlyOwner
        thresholdCheck(threshold)
    {
        require(poolIndex[receipient] == 0, "NftPool: pool initialized");
        poolCount++;
        poolIndex[receipient] = poolCount;
        poolStat[poolIndex[receipient]] = poolStatRecord(
            poolCount,
            0,
            0,
            underlyingAsset,
            threshold
        );
    }

    function poolMintToken(address receipient, string memory uri) external onlyOwner {
        poolStat[poolIndex[receipient]].pendingTokenCount++;
        tokenCount.increment();
        require(charityNftContract.mint(tokenCount.current(), uri), "NftPool: mint failed");
        poolToken[poolIndex[receipient]].add(tokenCount.current());
    }

    function acceptNft(address receipient, uint256 tokenId) external onlyOwner {
        require(poolToken[poolIndex[receipient]].contains(tokenId), "NftPool: token not exist");
        require(acceptFlag[tokenId] == false, "NftPool: token already accept");
        acceptFlag[tokenId] = true;
        poolStat[poolIndex[receipient]].pendingTokenCount--;
        poolStat[poolIndex[receipient]].acceptTokenCount++;
        charityNftContract.accept(tokenId);
    }

    function rejectNft(address receipient, uint256 tokenId) external onlyOwner {
        charityNftContract.burn(tokenId);
        poolToken[poolIndex[receipient]].remove(tokenId);
        tokenBurn.increment();
        poolStat[tokenId].pendingTokenCount--;
    }

    function adjustThresholds(address receipient, uint256[] memory newThreshold)
        external
        onlyOwner
        thresholdCheck(newThreshold)
    {
        poolStat[poolIndex[receipient]].threshold = newThreshold;
        emit AdjustThreshold(poolIndex[receipient], newThreshold);
    }

    /*function claim(address receipient) {
        uint256 currentRank = rankByPool[msg.sender][receipient];
    }*/

    function registerERC721(address receipient, address nftTokenAddress) external onlyOwner {
        poolReceiveNft[poolIndex[receipient]].set(poolReceiveNft[poolIndex[receipient]].length(), nftTokenAddress);
        poolReceiveNftMap[nftTokenAddress].push(poolIndex[receipient]);
    }

    /***********************************|
    |         Getter Functions          |
    |__________________________________*/

    function getPoolStat(address receipient) 
        external 
        view 
        returns (uint256, uint256, uint256,
                 address, uint256[] memory) 
    {
        return (
            poolStat[poolIndex[receipient]].poolId,
            poolStat[poolIndex[receipient]].pendingTokenCount,
            poolStat[poolIndex[receipient]].acceptTokenCount,
            poolStat[poolIndex[receipient]].underlyingAssets,
            poolStat[poolIndex[receipient]].threshold
        );
    }
    
    function getPoolCount() external view returns(uint256) {
        return poolCount;
    }
    
    function getTokenReject() external view returns(uint256) {
        return tokenBurn.current();
    }
    
    function getPoolToken(address receipient) external {
        delete showPoolNfts;
        for (uint256 i = 0; i < poolToken[poolIndex[receipient]].length(); i++) {
            showPoolNfts.push(poolToken[poolIndex[receipient]].at(i));
        }
    }
}

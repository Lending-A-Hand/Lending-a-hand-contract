// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./utils/EnumerableMap.sol";
import "./RToken/IRToken.sol";
import "./RToken/RTokenStructs.sol";
import "./CharityNFT.sol";

contract NftPool is Ownable, RTokenStructs {

    using Counters for Counters.Counter;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableSet for EnumerableSet.UintSet;

    struct poolStatRecord {
        uint256   poolId;
        uint256   pendingTokenCount;
        uint256   acceptTokenCount;
        uint256   unitPrice;
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
    // poolId => uint256[]
    mapping(uint256 => EnumerableSet.UintSet) private acceptTokenId;
    // msg.sender => poolIndex => rank
    mapping(address => mapping(uint256 => uint256)) public rankByPool;
    // tokenId => bool
    mapping(uint256 => bool) public acceptFlag;
    // pool => tokenId
    mapping(address => bool) public registered;

    mapping(address => uint256) public mockCumulativeInterest;

    uint256 private _nonce;
    uint256 private magicNumber;

    uint256[] public showPoolNfts;

    /***********************************|
    |              Event                |
    |__________________________________*/
    event AcceptNft(address receipient, uint256 tokenId, uint256 pendingCount, uint256 acceptCount);

    event AdjustThreshold(uint256 poolId, uint256[] newThreshold);

    event TokenDistributed(address receipient, uint256 tokenId);

    /***********************************|
    |            Constructor            |
    |__________________________________*/
    constructor (string memory name_, string memory symbol_, uint256 magicNumber_) onlyOwner {
        require(address(charityNftContract) == address(0), "NftPool: CharityNFT initialized");
        charityNftContract = new CharityNFT(name_, symbol_);
        magicNumber = magicNumber_;
    }
    
    /***********************************|
    |             Modifier              |
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
        uint256 unitPrice,
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
            unitPrice,
            underlyingAsset,
            threshold
        );
    }

    function updateCumulative(address addr, uint256 amount) external {
        mockCumulativeInterest[addr] = amount;
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
        acceptTokenId[poolIndex[receipient]].add(tokenId);
        poolStat[poolIndex[receipient]].pendingTokenCount--;
        poolStat[poolIndex[receipient]].acceptTokenCount++;
        charityNftContract.accept(tokenId);
        emit AcceptNft(
            receipient,
            tokenId, 
            poolStat[poolIndex[receipient]].pendingTokenCount,
            poolStat[poolIndex[receipient]].acceptTokenCount
        );
            
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

    function _updatePoolRank(
        address receipient,
        address account,
        uint256 amount
    ) internal {
        rankByPool[account][poolIndex[receipient]] += amount;
    }

    function claimNFT(address receipient) external {
        IRToken rToken = IRToken(receipient);
        AccountStatsView memory stats = rToken.getAccountStats(msg.sender);
        uint256 amount = rToken.interestPayableOf(msg.sender);
        uint256 accumulated = stats.cumulativeInterest;
        uint256 rank = rankByPool[msg.sender][poolIndex[receipient]];
        uint256[] memory poolThreshold = poolStat[poolIndex[receipient]].threshold;
        require(rank < poolThreshold.length, "NftPool: nothing to claim");
        for (uint256 i = rank; i < poolThreshold.length; i++) {
            // if (accumulated + amount < poolThreshold[i])
            if (mockCumulativeInterest[msg.sender] < poolThreshold[i])
              break;
            else {
                mockCumulativeInterest[msg.sender] = 0;
                uint256 id = _drawNftFromPool(poolIndex[receipient]);
                charityNftContract.transfer(id, msg.sender);
                poolToken[poolIndex[receipient]].remove(id);
                _nonce += magicNumber;
                emit TokenDistributed(msg.sender, id);
                rankByPool[msg.sender][poolIndex[receipient]] = 0;
                break;
            }
        }
    }

    function canClaim(address from, address receipient) public view returns (bool) {
        uint256 rank = rankByPool[msg.sender][poolIndex[receipient]];
        uint256[] memory poolThreshold = poolStat[poolIndex[receipient]].threshold;
        if (rank >= poolThreshold.length)
            return false;

        for (uint256 i = rank; i < poolThreshold.length; i++) {
            // if (accumulated + amount < poolThreshold[i])
            if (mockCumulativeInterest[msg.sender] < poolThreshold[i])
              break;
            else {
                return true;
            }
        }
    }

    function _drawNftFromPool(uint256 poolId) internal view returns(uint256 id) {
        EnumerableSet.UintSet storage ids = poolToken[poolId];
        uint256 index = _random(ids.length());
        return ids.at(index);
    }

    function _random(uint256 _length) private view returns(uint256 index) {
        index = uint256(keccak256(abi.encodePacked(tx.origin, block.difficulty, _nonce, block.number))) / _length;
    }

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
                 uint256, address, uint256[] memory) 
    {
        return (
            poolStat[poolIndex[receipient]].poolId,
            poolStat[poolIndex[receipient]].pendingTokenCount,
            poolStat[poolIndex[receipient]].acceptTokenCount,
            poolStat[poolIndex[receipient]].unitPrice,
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

    function getThreshold(address receipient, address account) 
        external 
        view
        returns(uint256[] memory, uint256) 
    {
        // return threshold level, accumulatd amount
        IRToken rToken = IRToken(receipient);
        uint256 userBal = rToken.balanceOf(account);
        uint256 accuAmount = userBal / poolStat[poolIndex[receipient]].unitPrice;
        return (poolStat[poolIndex[receipient]].threshold, accuAmount);
    }
    
    function getPoolToken(address receipient) public view returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](poolToken[poolIndex[receipient]].length());
        for (uint256 i = 0; i < poolToken[poolIndex[receipient]].length(); i++) {
            arr[i] = poolToken[poolIndex[receipient]].at(i);
        }

        return arr;
    }
}

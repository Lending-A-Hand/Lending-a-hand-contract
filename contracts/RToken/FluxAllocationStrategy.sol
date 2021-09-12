// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import {IAllocationStrategy} from "./IAllocationStrategy.sol";
import {Ownable} from "./Ownable.sol";
import {IERC20} from "./IERC20.sol";
import {IMarket} from "./IMarket.sol";
//import {CErc20Interface} from "./compound/contracts/CErc20Interface.sol";

contract FluxAllocationStrategy is IAllocationStrategy, Ownable {

    IMarket private fToken;
    IERC20 private token;

    //constructor(CErc20Interface cToken_) public {
    constructor(IMarket fToken_) public {
        fToken = fToken_;
        token = IERC20(fToken.underlying());
    }

    /// @dev ISavingStrategy.underlying implementation
    function underlying() external override view returns (address) {
        return fToken.underlying();
    }

    /// @dev ISavingStrategy.exchangeRateStored implementation
    function exchangeRateStored() external override view returns (uint256) {
        return fToken.exchangeRate();
    }

    /// @dev ISavingStrategy.accrueInterest implementation
    function accrueInterest() external override returns (bool) {
        return fToken.interestIndex() == 0;
    }

    /// @dev ISavingStrategy.investUnderlying implementation
    function investUnderlying(uint256 investAmount) external override onlyOwner returns (uint256) {
        token.transferFrom(msg.sender, address(this), investAmount);
        token.approve(address(fToken), investAmount);
        uint256 fTotalBefore = fToken.totalSupply();
        // TODO should we handle mint failure?
        //require(fToken.mint(investAmount) == 0, "mint failed");
        uint256 fTotalAfter = fToken.totalSupply();
        uint256 fCreatedAmount;
        require (fTotalAfter >= fTotalBefore, "Compound minted negative amount!?");
        fCreatedAmount = fTotalAfter - fTotalBefore;
        return fCreatedAmount;
    }

    /// @dev ISavingStrategy.redeemUnderlying implementation
    function redeemUnderlying(uint256 redeemAmount) external override onlyOwner returns (uint256) {
        uint256 fTotalBefore = fToken.totalSupply();
        // TODO should we handle redeem failure?
        //require(fToken.redeemUnderlying(redeemAmount) == 0, "fToken.redeemUnderlying failed");
        uint256 fTotalAfter = fToken.totalSupply();
        uint256 fBurnedAmount;
        require(fTotalAfter <= fTotalBefore, "Compound redeemed negative amount!?");
        fBurnedAmount = fTotalBefore - fTotalAfter;
        token.transfer(msg.sender, redeemAmount);
        return fBurnedAmount;
    }

    /// @dev ISavingStrategy.redeemAll implementation
    function redeemAll() external override onlyOwner
        returns (uint256 savingsAmount, uint256 underlyingAmount) {
        savingsAmount = fToken.balanceOf(address(this));
        //require(fToken.redeem(savingsAmount) == 0, "cToken.redeem failed");
        underlyingAmount = token.balanceOf(address(this));
        token.transfer(msg.sender, underlyingAmount);
    }

}
pragma solidity 0.8.6;

import {IAllocationStrategy} from "./IAllocationStrategy.sol";
import {Ownable} from "./Ownable.sol";
import {IERC20} from "./IERC20.sol";

contract NothingAllocationStrategy is IAllocationStrategy, Ownable {
    IERC20 private token = IERC20(0x87d915beb1e242683750240C93C6ea699D797D10);
    uint256 private totalInvested;

    event TotalInvested(uint indexed totalInvested);

    /// @dev Returns the address of the underlying token
    function underlying() external view override returns (address) {
        return address(token);
    }

    /// @dev Returnss the exchange rate from aToken to the underlying asset
    function exchangeRateStored() public view override returns (uint256) {
        // Aave has a fixed exchange rate of 1:1 for aToken <-> underlying
        // Interest is modeled by increasing balance of aTokens
        // We calculate a virtual exchange rate based on the aToken balance and invested amount

        return 10**18;
    }

    /// @dev Accrues interest. Not required for Aave protocol. Always returns true
    function accrueInterest() external override returns (bool) {
        // Aaves interest accrual does not need to be called explicitly
        // aToken.balanceOf() already contains the accrued interest
        return true;
    }

    /// @dev Invest investAmount of underlying asset into Aave
    function investUnderlying(uint256 investAmount) external onlyOwner override returns (uint256) {
        // Transfer underlying from caller to this contract
        token.transferFrom(msg.sender, address(this), investAmount);

        // Update totalInvested. We want to keep the exchange rate while updating the totalInvested.
        // We calculate the newTotalInvested value we need to have the same exchange rate as before
        // oldExchangeRate = newExchangeRate
        // oldATokenBalance / oldTotalInvested = newATokenBalance / newTotalInvested      // solve for newTotalInvested
        // newATokenBalance  / (oldATokenBalance / oldTotalInvested) = newTotalInvested
        // newTotalInvested = (newATokenBalance * oldTotalInvested) / oldATokenBalance
        totalInvested += investAmount;
        emit TotalInvested(totalInvested);

        // Return the difference in aToken balance
        return (investAmount * 10**18) / exchangeRateStored();
    }

    /// @dev Redeem redeemAmount from Aave
    function redeemUnderlying(uint256 redeemAmount) external onlyOwner override returns (uint256) {
        totalInvested -= redeemAmount;
        emit TotalInvested(totalInvested);

        // Transfer redeemed underlying assets to caller
        token.transfer(msg.sender, redeemAmount);
        // Return the difference in aToken balance
        return (redeemAmount * 10**18) / exchangeRateStored();
    }

    /// @dev Redeem the entire balance of aToken from Aave
    function redeemAll() external onlyOwner override
        returns (uint256, uint256) {
        uint256 invested = totalInvested;

        totalInvested = 0;
        emit TotalInvested(totalInvested);
        // Transfer redeemed underlying assets to caller
        token.transfer(msg.sender, invested);
    }
}

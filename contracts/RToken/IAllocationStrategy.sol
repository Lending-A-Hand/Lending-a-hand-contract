pragma solidity ^0.8.0;

/**
 * @notice Allocation strategy for assets.
 *         - It invests the underlying assets into some yield generating contracts,
 *           usually lending contracts, in return it gets new assets aka. saving assets.
 *         - Savings assets can be redeemed back to the underlying assets plus interest any time.
 */
interface IAllocationStrategy {

    /**
     * @notice Underlying asset for the strategy
     * @return address Underlying asset address
     */
    function underlying() external view virtual returns (address);

    /**
     * @notice Calculates the exchange rate from underlying to saving assets
     * @return Calculated exchange rate scaled by 1e18
     *
     * NOTE:
     *
     *   underlying = savingAssets × exchangeRate
     */
    function exchangeRateStored() external view virtual returns (uint256);

    /**
      * @notice Applies accrued interest to all savings
      * @dev This should calculates interest accrued from the last checkpointed
      *      block up to the current block and writes new checkpoint to storage.
      * @return bool success(true) or failure(false)
      */
    function accrueInterest() external virtual returns (bool);

    /**
     * @notice Sender supplies underlying assets into the market and receives saving assets in exchange
     * @dev Interst shall be accrued
     * @param investAmount The amount of the underlying asset to supply
     * @return Amount of saving assets created
     */
    function investUnderlying(uint256 investAmount) external virtual returns (uint256);

    /**
     * @notice Sender redeems saving assets in exchange for a specified amount of underlying asset
     * @dev Interst shall be accrued
     * @param redeemAmount The amount of underlying to redeem
     * @return Amount of saving assets burned
     */
    function redeemUnderlying(uint256 redeemAmount) external virtual returns (uint256);

    /**
     * @notice Owner redeems all saving assets
     * @dev Interst shall be accrued
     * @return savingsAmount Amount of savings redeemed
     * @return underlyingAmount Amount of underlying redeemed
     */
    function redeemAll() external virtual returns (uint256 savingsAmount, uint256 underlyingAmount);

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "./IERC20.sol";

interface IMarket is IERC20 {
    function decimals() external view returns (uint8);         
    
    // 剩余可用现金
    function cashPrior() external view returns (uint256);
    // 利息指数
    function interestIndex() external view returns (uint256); 
    // ftoken market 对应的底层资产 token 地址
    function underlying() external view returns (address);
    // 市场待还借款
    function totalBorrows() external view returns (uint256);
    // token 价格
    function underlyingPrice() external view returns (uint256);


    function isFluxMarket() external pure returns (bool);

    /**
      @notice 获取市场兑换汇率
      @return 返回汇率的尾数
     */
    function exchangeRate() external view returns (uint256);


    /**
     @notice 获取账户借贷信息快照
     @param acct 待查询的账户地址
     @return ftokens 存款份额，含利息。 存款余额= 存款份额*汇率
     @return borrows 借款余额，含利息。
     @return xrate 汇率
    */
    function getAcctSnapshot(address acct)
        external
        view
        returns (
            uint256 ftokens,
            uint256 borrows,
            uint256 xrate
    );


    /**
        @notice 计算账户借贷资产信息
        @dev 通过提供多个参数来灵活的计算账户的借贷时的资产变动信息，比如可以查询出账户如果继续借入 200 个 FC 后的借贷情况。
        @param acct 待查询账户
        @param collRatioMan 计算时使用的借款抵押率
        @param addBorrows 计算时需要增加的借款数量
        @param subSupplies 计算时需要减少的存款数量
      @return supplyValueMan 存款额（尾数）
      @return borrowValueMan 借款额（尾数）
      @return borrowLimitMan 借款所需抵押额（尾数）
     */
    function accountValues(
        address acct,
        uint256 collRatioMan,
        uint256 addBorrows,
        uint256 subSupplies
    )
        external
        view
        returns (
            uint256 supplyValueMan,
            uint256 borrowValueMan,
            uint256 borrowLimitMan
        );


    /**
        @notice 执行复利计息
     */
    function calcCompoundInterest() external;

}
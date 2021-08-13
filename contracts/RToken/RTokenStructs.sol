pragma solidity 0.8.1;

/**
 * @notice RToken storage structures
 */
contract RTokenStructs {

    /**
     * @notice Global stats
     */
        /// @notice Total redeemable tokens supply
        /// @notice Total saving assets in redeemable amount

    struct GlobalStats {
        uint256 totalSupply;
        uint256 totalSavingsAmount;
    }

    /**
     * @notice Account stats stored
     */
        /// @notice Current hat ID
        /// @notice Current redeemable amount
        /// @notice Interest portion of the rAmount
        /// @notice Current loaned debt amount
        /// @notice Current internal savings amount
        /// @notice Interest payable
        /// @notice Cumulative interest generated for the account
        /// @notice Loans lent to the recipients

    struct AccountStatsView {
        uint256 hatID;
        uint256 rAmount;
        uint256 rInterest;
        uint256 lDebt;
        uint256 sInternalAmount;
        uint256 rInterestPayable;
        uint256 cumulativeInterest;
        uint256 lRecipientsSum;
    }

    /**
     * @notice Account stats stored
     */
        /// @notice Cumulative interest generated for the account
    struct AccountStatsStored {
        uint256 cumulativeInterest;
    }

    /**
     * @notice Hat stats view
     */
        /// @notice Number of addresses has the hat
        /// @notice Total net loans distributed through the hat
        /// @notice Total net savings distributed through the hat
    struct HatStatsView {
        uint256 useCount;
        uint256 totalLoans;
        uint256 totalSavings;
    }

    /**
     * @notice Hat stats stored
     */
        /// @notice Number of addresses has the hat
        /// @notice Total net loans distributed through the hat
        /// @notice Total net savings distributed through the hat
    struct HatStatsStored {
        uint256 useCount;
        uint256 totalLoans;
        uint256 totalInternalSavings;
    }

    /**
     * @notice Hat structure describes who are the recipients of the interest
     *
     * To be a valid hat structure:
     *   - at least one recipient
     *   - recipients.length == proportions.length
     *   - each value in proportions should be greater than 0
     */
    struct Hat {
        address[] recipients;
        uint32[] proportions;
    }

    /// @dev Account structure
        /// @notice Current selected hat ID of the account
        /// @notice Interest rate portion of the rAmount
        /// @notice Debt in redeemable amount lent to recipients
        //          In case of self-hat, external debt is optimized to not to
        //          be stored in lRecipients
        /// @notice Received loan.
        ///         Debt in redeemable amount owed to the lenders distributed
        ///         through one or more hats.
        /// @notice Savings internal accounting amount.
        ///         Debt is sold to buy savings

    struct Account {
        uint256 hatID;
        uint256 rAmount;
        uint256 rInterest;
        mapping(address => uint256) lRecipients;
        uint256 lDebt;
        uint256 sInternalAmount;
    }

    /**
     * Additional Definitions:
     *
     *   - rGross = sInternalToR(sInternalAmount)
     *   - lRecipientsSum = sum(lRecipients)
     *   - interestPayable = rGross - lDebt - rInterest
     *   - realtimeBalance = rAmount + interestPayable
     *
     *   - rAmount aka. tokenBalance
     *   - rGross aka. receivedSavings
     *   - lDebt aka. receivedLoan
     *
     * Account Invariants:
     *
     *   - rAmount = lRecipientsSum + rInterest [with rounding errors]
     *
     * Global Invariants:
     *
     * - globalStats.totalSupply = sum(account.tokenBalance)
     * - globalStats.totalSavingsAmount = sum(account.receivedSavings) [with rounding errors]
     * - sum(hatStats.totalLoans) = sum(account.receivedLoan)
     * - sum(hatStats.totalSavings) = sum(account.receivedSavings + cumulativeInterest - rInterest) [with rounding errors]
     *
     */
}


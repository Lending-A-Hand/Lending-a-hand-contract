pragma solidity 0.8.6;

import {Ownable} from "./Ownable.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";
import {RTokenStructs} from "./RTokenStructs.sol";
import {RTokenStorage} from "./RTokenStorage.sol";
import {IERC20, IRToken} from "./IRToken.sol";
import {NothingAllocationStrategy} from "./NothingAllocationStrategy.sol";
import {IAllocationStrategy} from "./IAllocationStrategy.sol";

/**
 * @notice RToken an ERC20 token that is 1:1 redeemable to its underlying ERC20 token.
 */
contract RToken is
    IRToken,
    RTokenStorage,
    Ownable,
    ReentrancyGuard
{
    uint256 public constant ALLOCATION_STRATEGY_EXCHANGE_RATE_SCALE = 1e18;
    uint256 public constant INITIAL_SAVING_ASSET_CONVERSION_RATE = 1e18;
    uint256 public constant MAX_UINT256 = uint256(int256(-1));
    uint256 public constant SELF_HAT_ID = MAX_UINT256;
    uint32 public constant PROPORTION_BASE = 0xFFFFFFFF;
    uint256 public constant MAX_NUM_HAT_RECIPIENTS = 50;

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _decimals
    ) public {
        require(!_initialized, "The library has already been initialized.");
        _initialized = true;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        savingAssetConversionRate = INITIAL_SAVING_ASSET_CONVERSION_RATE;
        address nas = address(new NothingAllocationStrategy());
        allocationStrategy = IAllocationStrategy(nas);
        token = IERC20(allocationStrategy.underlying());

        // special hat aka. zero hat : hatID = 0
        hats.push(Hat(new address[](0), new uint32[](0)));

        // everyone is using it by default
        hatStats[0].useCount = MAX_UINT256;

        emit AllocationStrategyChanged(nas, savingAssetConversionRate);
    }

    //
    // ERC20 Interface
    //

    function balanceOf(address owner) external view override returns (uint256) {
        return accounts[owner].rAmount;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return transferAllowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
        return true;
    }

    function transfer(address dst, uint256 amount)
        external
        nonReentrant
        override
        returns (bool)
    {
        _payInterest(msg.sender);
        _transfer(msg.sender, msg.sender, dst, amount);
        _payInterest(dst);
        return true;
    }

    function transferFrom(address src, address dst, uint256 amount)
        external
        nonReentrant
        override
        returns (bool)
    {
        _payInterest(src);
        _transfer(msg.sender, src, dst, amount);
        _payInterest(dst);
        return true;
    }

    //
    // rToken interface
    //

    function mint(uint256 mintAmount) external nonReentrant override returns (bool) {
        _mint(mintAmount);
        _payInterest(msg.sender);
        return true;
    }

    function mintWithSelectedHat(uint256 mintAmount, uint256 hatID)
        external
        nonReentrant
        override
        returns (bool)
    {
        _changeHat(msg.sender, hatID);
        _mint(mintAmount);
        _payInterest(msg.sender);
        return true;
    }

    function mintWithNewHat(
        uint256 mintAmount,
        address[] calldata recipients,
        uint32[] calldata proportions
    ) external nonReentrant override returns (bool) {
        uint256 hatID = _createHat(recipients, proportions);
        _changeHat(msg.sender, hatID);
        _mint(mintAmount);
        _payInterest(msg.sender);
        return true;
    }

    function redeem(uint256 redeemTokens) external nonReentrant override returns (bool) {
        _payInterest(msg.sender);
        _redeem(msg.sender, redeemTokens);
        return true;
    }

    function redeemAndTransfer(address redeemTo, uint256 redeemTokens)
        external
        nonReentrant
        returns (bool)
    {
        _payInterest(msg.sender);
        _redeem(redeemTo, redeemTokens);
        return true;
    }

    function redeemAndTransferAll(address redeemTo)
        external
        nonReentrant
        returns (bool)
    {
        _payInterest(msg.sender);
        _redeem(redeemTo, accounts[msg.sender].rAmount);
        return true;
    }

    function createHat(
        address[] calldata recipients,
        uint32[] calldata proportions,
        bool doChangeHat
    ) external nonReentrant override returns (uint256 hatID) {
        hatID = _createHat(recipients, proportions);
        if (doChangeHat) {
            _changeHat(msg.sender, hatID);
        }
    }

    function changeHat(uint256 hatID) external nonReentrant override returns (bool) {
        _changeHat(msg.sender, hatID);
        _payInterest(msg.sender);
        return true;
    }

    function getMaximumHatID() external view override returns (uint256 hatID) {
        return hats.length - 1;
    }

    function getHatByAddress(address owner)
        external
        view
        override
        returns (
            uint256 hatID,
            address[] memory recipients,
            uint32[] memory proportions
        )
    {
        hatID = accounts[owner].hatID;
        (recipients, proportions) = _getHatByID(hatID);
    }

    function getHatByID(uint256 hatID)
        external
        view
        override
        returns (address[] memory recipients, uint32[] memory proportions) {
        (recipients, proportions) = _getHatByID(hatID);
    }

    function _getHatByID(uint256 hatID)
        private
        view
        returns (address[] memory recipients, uint32[] memory proportions) {
        if (hatID != 0 && hatID != SELF_HAT_ID) {
            Hat memory hat = hats[hatID];
            recipients = hat.recipients;
            proportions = hat.proportions;
        } else {
            recipients = new address[](0);
            proportions = new uint32[](0);
        }
    }

    function receivedSavingsOf(address owner)
        external
        view
        override
        returns (uint256 amount)
    {
        Account storage account = accounts[owner];
        uint256 rGross = sInternalToR(account.sInternalAmount);
        return rGross;
    }

    function receivedLoanOf(address owner)
        external
        view
        override
        returns (uint256 amount)
    {
        Account storage account = accounts[owner];
        return account.lDebt;
    }

    function interestPayableOf(address owner)
        external
        view
        override
        returns (uint256 amount)
    {
        Account storage account = accounts[owner];
        return getInterestPayableOf(account);
    }

    function payInterest(address owner) external nonReentrant override returns (bool) {
        _payInterest(owner);
        return true;
    }

    function getGlobalStats() external view override returns (GlobalStats memory) {
        uint256 totalSavingsAmount = sOriginalToR(savingAssetOrignalAmount);
        return
            GlobalStats({
                totalSupply: totalSupply,
                totalSavingsAmount: totalSavingsAmount
            });
    }

    function getAccountStats(address owner)
        external
        view
        override
        returns (AccountStatsView memory stats)
    {
        Account storage account = accounts[owner];
        stats.hatID = account.hatID;
        stats.rAmount = account.rAmount;
        stats.rInterest = account.rInterest;
        stats.lDebt = account.lDebt;
        stats.sInternalAmount = account.sInternalAmount;

        stats.rInterestPayable = getInterestPayableOf(account);

        AccountStatsStored storage statsStored = accountStats[owner];
        stats.cumulativeInterest = statsStored.cumulativeInterest;

        Hat storage hat = hats[account.hatID == SELF_HAT_ID
            ? 0
            : account.hatID];
        if (account.hatID == 0 || account.hatID == SELF_HAT_ID) {
            // Self-hat has storage optimization for lRecipients.
            // We use the account invariant to calculate lRecipientsSum instead,
            // so it does look like a tautology indeed.
            // Check RTokenStructs documentation for more info.
            stats.lRecipientsSum = gentleSub(stats.rAmount, stats.rInterest);
        } else {
            for (uint256 i = 0; i < hat.proportions.length; ++i) {
                stats.lRecipientsSum += account.lRecipients[hat.recipients[i]];
            }
        }

        return stats;
    }

    function getHatStats(uint256 hatID)
        external
        view
        override
        returns (HatStatsView memory stats) {
        HatStatsStored storage statsStored = hatStats[hatID];
        stats.useCount = statsStored.useCount;
        stats.totalLoans = statsStored.totalLoans;

        stats.totalSavings = sInternalToR(statsStored.totalInternalSavings);
        return stats;
    }

    function getCurrentSavingStrategy() external view override returns (address) {
        return address(allocationStrategy);
    }

    function getSavingAssetBalance()
        external
        view
        override
        returns (uint256 rAmount, uint256 sOriginalAmount)
    {
        sOriginalAmount = savingAssetOrignalAmount;
        rAmount = sOriginalToR(sOriginalAmount);
    }

    function changeAllocationStrategy(address _allocationStrategy)
        external
        nonReentrant
        onlyOwner
    {
        IAllocationStrategy newStrategy = IAllocationStrategy(_allocationStrategy);
        require(
            newStrategy.underlying() == address(token),
            "New strategy should have the same underlying asset"
        );
        IAllocationStrategy oldStrategy = allocationStrategy;
        allocationStrategy = newStrategy;
        // redeem everything from the old strategy
        (uint256 sOriginalBurned, ) = oldStrategy.redeemAll();
        uint256 totalAmount = token.balanceOf(address(this));
        // invest everything into the new strategy
        require(token.approve(address(allocationStrategy), totalAmount), "token approve failed");
        uint256 sOriginalCreated = allocationStrategy.investUnderlying(totalAmount);

        // give back the ownership of the old allocation strategy to the admin
        // unless we are simply switching to the same allocaiton Strategy
        //
        //  - But why would we switch to the same allocation strategy?
        //  - This is a special case where one could pick up the unsoliciated
        //    savings from the allocation srategy contract as extra "interest"
        //    for all rToken holders.
        // TODO: figure out what does ownership here do
        if (address(allocationStrategy) != address(oldStrategy)) {
            Ownable(address(oldStrategy)).transferOwnership(address(owner()));
        }

        // calculate new saving asset conversion rate
        //
        // NOTE:
        //   - savingAssetConversionRate should be scaled by 1e18
        //   - to keep internalSavings constant:
        //     internalSavings == sOriginalBurned * savingAssetConversionRateOld
        //     internalSavings == sOriginalCreated * savingAssetConversionRateNew
        //     =>
        //     savingAssetConversionRateNew = sOriginalBurned
        //          * savingAssetConversionRateOld
        //          / sOriginalCreated
        //

        uint256 sInternalAmount = sOriginalToSInternal(savingAssetOrignalAmount);
        uint256 savingAssetConversionRateOld = savingAssetConversionRate;
        savingAssetConversionRate = sOriginalBurned * savingAssetConversionRateOld / sOriginalCreated;
        savingAssetOrignalAmount = sInternalToSOriginal(sInternalAmount);

        emit AllocationStrategyChanged(_allocationStrategy, savingAssetConversionRate);
    }

    function getCurrentAllocationStrategy() external view returns (address allocationStrategy) {
        return address(allocationStrategy);
    }

    function changeHatFor(address contractAddress, uint256 hatID) external onlyOwner {
        require(_isContract(contractAddress), "Admin can only change hat for contract address");
        _changeHat(contractAddress, hatID);
    }

    function _transfer(
        address spender,
        address src,
        address dst,
        uint256 tokens
    ) internal {
        require(
            accounts[src].rAmount >= tokens,
            "Not enough balance to transfer"
        );

        /* Get the allowance, infinite for the account owner */
        uint256 startingAllowance = 0;
        if (spender == src) {
            startingAllowance = MAX_UINT256;
        } else {
            startingAllowance = transferAllowances[src][spender];
        }
        require(
            startingAllowance >= tokens,
            "Not enough allowance for transfer"
        );

        /* Do the calculations, checking for {under,over}flow */
        uint256 allowanceNew = startingAllowance - tokens;
        uint256 srcTokensNew = accounts[src].rAmount - tokens;
        uint256 dstTokensNew = accounts[dst].rAmount + tokens;

        /* Eat some of the allowance (if necessary) */
        if (startingAllowance != MAX_UINT256) {
            transferAllowances[src][spender] = allowanceNew;
        }

        // lRecipients adjustments
        uint256 sInternalEstimated = estimateAndRecollectLoans(src, tokens);
        _distributeLoans(dst, tokens, sInternalEstimated);

        // update token balances
        accounts[src].rAmount = srcTokensNew;
        accounts[dst].rAmount = dstTokensNew;

        // apply hat inheritance rule
        if ((accounts[src].hatID != 0 &&
            accounts[dst].hatID == 0 &&
            accounts[src].hatID != SELF_HAT_ID)) {
            _changeHat(dst, accounts[src].hatID);
        }

        /* We emit a Transfer event */
        emit Transfer(src, dst, tokens);
    }

    function _mint(uint256 mintAmount) internal {
        require(
            token.allowance(msg.sender, address(this)) >= mintAmount,
            "Not enough allowance"
        );

        Account storage account = accounts[msg.sender];

        // create saving assets
        require(token.transferFrom(msg.sender, address(this), mintAmount), "token transfer failed");
        require(token.approve(address(allocationStrategy), mintAmount), "token approve failed");
        uint256 sOriginalCreated = allocationStrategy.investUnderlying(mintAmount);

        // update global and account r balances
        totalSupply += mintAmount;
        account.rAmount += mintAmount;

        // update global stats
        savingAssetOrignalAmount += sOriginalCreated;

        // distribute saving assets as loans to recipients
        uint256 sInternalCreated = sOriginalToSInternal(sOriginalCreated);
        _distributeLoans(msg.sender, mintAmount, sInternalCreated);

        emit Transfer(address(0), msg.sender, mintAmount);
    }

    function _redeem(address redeemTo, uint256 redeemAmount) internal {
        Account storage account = accounts[msg.sender];
        require(redeemAmount > 0, "Redeem amount cannot be zero");
        require(
            redeemAmount <= account.rAmount,
            "Not enough balance to redeem"
        );

        _redeemAndRecollectLoans(msg.sender, redeemAmount);

        // update Account r balances and global statistics
        account.rAmount -= redeemAmount;
        totalSupply -= redeemAmount;

        // transfer the token back
        require(token.transfer(redeemTo, redeemAmount), "token transfer failed");

        emit Transfer(msg.sender, address(0), redeemAmount);
    }

    function _createHat(
        address[] memory recipients,
        uint32[] memory proportions
    ) internal returns (uint256 hatID) {
        uint256 i;

        require(recipients.length > 0, "Invalid hat: at least one recipient");
        require(recipients.length <= MAX_NUM_HAT_RECIPIENTS, "Invalild hat: maximum number of recipients reached");
        require(
            recipients.length == proportions.length,
            "Invalid hat: length not matching"
        );

        // normalize the proportions
        // safemath is not used here, because:
        // proportions are uint32, there is no overflow concern
        uint256 totalProportions = 0;
        for (i = 0; i < recipients.length; ++i) {
            require(
                proportions[i] > 0,
                "Invalid hat: proportion should be larger than 0"
            );
            require(recipients[i] != address(0), "Invalid hat: recipient should not be 0x0");
            // don't panic, no safemath, look above comment
            totalProportions += uint256(proportions[i]);
        }
        for (i = 0; i < proportions.length; ++i) {
            proportions[i] = uint32(
                // don't panic, no safemath, look above comment
                (uint256(proportions[i]) * uint256(PROPORTION_BASE)) /
                    totalProportions
            );
        }

        hats.push(Hat(recipients, proportions));
        hatID = hats.length - 1;
        emit HatCreated(hatID);
    }

    function _changeHat(address owner, uint256 hatID) internal {
        require(hatID == SELF_HAT_ID || hatID < hats.length, "Invalid hat ID");
        Account storage account = accounts[owner];
        uint256 oldHatID = account.hatID;
        HatStatsStored storage oldHatStats = hatStats[oldHatID];
        HatStatsStored storage newHatStats = hatStats[hatID];
        if (account.rAmount > 0) {
            uint256 sInternalEstimated = estimateAndRecollectLoans(owner, account.rAmount);
            account.hatID = hatID;
            _distributeLoans(owner, account.rAmount, sInternalEstimated);
        } else {
            account.hatID = hatID;
        }
        oldHatStats.useCount -= 1;
        newHatStats.useCount += 1;
        emit HatChanged(owner, oldHatID, hatID);
    }

    function getInterestPayableOf(Account storage account)
        internal
        view
        returns (uint256)
    {
        uint256 rGross = sInternalToR(account.sInternalAmount);
        if (rGross > account.lDebt + account.rInterest) {
            // don't panic, the condition guarantees that safemath is not needed
            return rGross - account.lDebt - account.rInterest;
        } else {
            // no interest accumulated yet or even negative interest rate!?
            return 0;
        }
    }

    function _distributeLoans(
        address owner,
        uint256 rAmount,
        uint256 sInternalAmount
    ) internal {
        Account storage account = accounts[owner];
        Hat storage hat = hats[account.hatID == SELF_HAT_ID
            ? 0
            : account.hatID];
        uint256 i;
        if (hat.recipients.length > 0) {
            uint256 rLeft = rAmount;
            uint256 sInternalLeft = sInternalAmount;
            for (i = 0; i < hat.proportions.length; ++i) {
                Account storage recipientAccount = accounts[hat.recipients[i]];
                bool isLastRecipient = i == (hat.proportions.length - 1);

                // calculate the loan amount of the recipient
                uint256 lDebtRecipient = isLastRecipient
                    ? rLeft
                    : rAmount * hat.proportions[i] / PROPORTION_BASE;
                // distribute the loan to the recipient
                account.lRecipients[hat.recipients[i]] += lDebtRecipient;
                recipientAccount.lDebt += lDebtRecipient;
                // remaining value adjustments
                rLeft = gentleSub(rLeft, lDebtRecipient);

                // calculate the savings holdings of the recipient
                uint256 sInternalAmountRecipient = isLastRecipient
                    ? sInternalLeft
                    : sInternalAmount * hat.proportions[i] / PROPORTION_BASE;
                recipientAccount.sInternalAmount += sInternalAmountRecipient;
                // remaining value adjustments
                sInternalLeft = gentleSub(sInternalLeft, sInternalAmountRecipient);

                _updateLoanStats(owner, hat.recipients[i], account.hatID, true, lDebtRecipient, sInternalAmountRecipient);
            }
        } else {
            // Account uses the zero/self hat, give all interest to the owner
            account.lDebt += rAmount;
            account.sInternalAmount += sInternalAmount;

            _updateLoanStats(owner, owner, account.hatID, true, rAmount, sInternalAmount);
        }
    }

    function estimateAndRecollectLoans(address owner, uint256 rAmount)
        internal returns (uint256 sInternalEstimated)
    {
        // accrue interest so estimate is up to date
        require(allocationStrategy.accrueInterest(), "accrueInterest failed");
        sInternalEstimated = rToSInternal(rAmount);
        _recollectLoans(owner, rAmount);
    }

    function _redeemAndRecollectLoans(address owner, uint256 rAmount)
        internal
    {
        uint256 sOriginalBurned = allocationStrategy.redeemUnderlying(rAmount);
        sOriginalToSInternal(sOriginalBurned);
        _recollectLoans(owner, rAmount);

        // update global stats
        // TODO: figure out when will the second case heppen
        if (savingAssetOrignalAmount > sOriginalBurned) {
            savingAssetOrignalAmount -= sOriginalBurned;
        } else {
            savingAssetOrignalAmount = 0;
        }
    }

    function _recollectLoans(
        address owner,
        uint256 rAmount
    ) internal {
        Account storage account = accounts[owner];
        Hat storage hat = hats[account.hatID == SELF_HAT_ID
            ? 0
            : account.hatID];
        // interest part of the balance is not debt
        // hence maximum amount debt to be collected is:
        uint256 debtToCollect = gentleSub(account.rAmount, account.rInterest);
        // only a portion of debt needs to be collected
        if (debtToCollect > rAmount) {
            debtToCollect = rAmount;
        }
        uint256 sInternalToCollect = rToSInternal(debtToCollect);
        if (hat.recipients.length > 0) {
            uint256 rLeft = 0;
            uint256 sInternalLeft = 0;
            uint256 i;
            // adjust recipients' debt and savings
            rLeft = debtToCollect;
            sInternalLeft = sInternalToCollect;
            for (i = 0; i < hat.proportions.length; ++i) {
                Account storage recipientAccount = accounts[hat.recipients[i]];
                bool isLastRecipient = i == (hat.proportions.length - 1);

                // calulate loans to be collected from the recipient
                uint256 lDebtRecipient = isLastRecipient
                    ? rLeft
                    : debtToCollect * hat.proportions[i] / PROPORTION_BASE;
                recipientAccount.lDebt = gentleSub(
                    recipientAccount.lDebt,
                    lDebtRecipient);
                account.lRecipients[hat.recipients[i]] = gentleSub(
                    account.lRecipients[hat.recipients[i]],
                    lDebtRecipient);
                // loans leftover adjustments
                rLeft = gentleSub(rLeft, lDebtRecipient);

                // calculate savings to be collected from the recipient
                uint256 sInternalAmountRecipient = isLastRecipient
                    ? sInternalLeft
                    : sInternalToCollect * hat.proportions[i] / PROPORTION_BASE;
                recipientAccount.sInternalAmount = gentleSub(
                    recipientAccount.sInternalAmount,
                    sInternalAmountRecipient);
                // savings leftover adjustments
                sInternalLeft = gentleSub(sInternalLeft, sInternalAmountRecipient);

                _adjustRInterest(recipientAccount);

                _updateLoanStats(owner, hat.recipients[i], account.hatID, false, lDebtRecipient, sInternalAmountRecipient);
            }
        } else {
            // Account uses the zero hat, recollect interests from the owner

            // collect debt from self hat
            account.lDebt = gentleSub(account.lDebt, debtToCollect);

            // collect savings
            account.sInternalAmount = gentleSub(account.sInternalAmount, sInternalToCollect);

            _adjustRInterest(account);

            _updateLoanStats(owner, owner, account.hatID, false, debtToCollect, sInternalToCollect);
        }

        // debt-free portion of internal savings needs to be collected too
        if (rAmount > debtToCollect) {
            sInternalToCollect = rToSInternal(rAmount - debtToCollect);
            account.sInternalAmount = gentleSub(account.sInternalAmount, sInternalToCollect);
            _adjustRInterest(account);
        }
    }

    function _payInterest(address owner) internal {
        Account storage account = accounts[owner];
        AccountStatsStored storage stats = accountStats[owner];

        require(allocationStrategy.accrueInterest(), "accrueInterest failed");
        uint256 interestAmount = getInterestPayableOf(account);

        if (interestAmount > 0) {
            stats.cumulativeInterest += interestAmount;
            account.rInterest += interestAmount;
            account.rAmount += interestAmount;
            totalSupply += interestAmount;
            emit InterestPaid(owner, interestAmount);
            emit Transfer(address(0), owner, interestAmount);
        }
    }

    function _updateLoanStats(
        address owner,
        address recipient,
        uint256 hatID,
        bool isDistribution,
        uint256 redeemableAmount,
        uint256 sInternalAmount
    ) private {
        HatStatsStored storage hatStats = hatStats[hatID];

        emit LoansTransferred(
            owner,
            recipient,
            hatID,
            isDistribution,
            redeemableAmount,
            sInternalAmount
        );

        if (isDistribution) {
            hatStats.totalLoans += redeemableAmount;
            hatStats.totalInternalSavings += sInternalAmount;
        } else {
            hatStats.totalLoans = gentleSub(hatStats.totalLoans, redeemableAmount);
            hatStats.totalInternalSavings = gentleSub(
                hatStats.totalInternalSavings,
                sInternalAmount
            );
        }
    }

    function _isContract(address addr) private view returns (bool) {
      uint size;
      assembly { size := extcodesize(addr) }
      return size > 0;
    }

    function gentleSub(uint256 a, uint256 b) private pure returns (uint256) {
        if (a < b) return 0;
        else return a - b;
    }

    function sInternalToR(uint256 sInternalAmount)
        private view
        returns (uint256 rAmount) {
        return sInternalAmount * allocationStrategy.exchangeRateStored() / savingAssetConversionRate;
    }

    function rToSInternal(uint256 rAmount)
        private view
        returns (uint256 sInternalAmount) {
        return rAmount * savingAssetConversionRate / allocationStrategy.exchangeRateStored();
    }

    function sOriginalToR(uint sOriginalAmount)
        private view
        returns (uint256 sInternalAmount) {
        return sOriginalAmount * allocationStrategy.exchangeRateStored() / ALLOCATION_STRATEGY_EXCHANGE_RATE_SCALE;
    }

    function sOriginalToSInternal(uint sOriginalAmount)
        private view
        returns (uint256 sInternalAmount) {
        // savingAssetConversionRate is scaled by 1e18
        return sOriginalAmount * savingAssetConversionRate / ALLOCATION_STRATEGY_EXCHANGE_RATE_SCALE;
    }

    function sInternalToSOriginal(uint sInternalAmount)
        private view
        returns (uint256 sOriginalAmount) {
        // savingAssetConversionRate is scaled by 1e18
        return sInternalAmount * ALLOCATION_STRATEGY_EXCHANGE_RATE_SCALE / savingAssetConversionRate;
    }

    function _adjustRInterest(Account storage account) private {
        uint256 rGross = sInternalToR(account.sInternalAmount);
        if (account.rInterest > rGross - account.lDebt) {
            account.rInterest = rGross - account.lDebt;
        }
    }
}

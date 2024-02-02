// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../common/types/ScriptTypesEnum.sol";

library DataTypes {

    /// @notice                             Structure for registering lockers
    /// @dev
    /// @param lockerLockingScript          Locker redeem script
    /// @param lockerRescueType             Locker script type in case of getting BTCs back
    /// @param lockerRescueScript           Locker script in case of getting BTCs back
    /// @param lockedAmount                 Bond amount of locker in locked token of the target chain
    /// @param netMinted                    Total minted - total burnt
    /// @param slashingCoreBTCAmount        Total amount of coreBTC a locker must be slashed
    /// @param reservedTokenForSlash        Total locked token reserved to support slashing coreBTC
    /// @param isLocker                     Indicates that is already a locker or not
    /// @param isCandidate                  Indicates that is a candidate or not
    /// @param isScriptHash                 Shows if it's script hash
    ///                                     has enough collateral to accept more minting requests)
    /// @param lockedToken                  Address of collateral token
    /// @param inactivationTimestamp        Starting time of becoming inactive state
    struct locker {
        bytes lockerLockingScript;
        ScriptTypes lockerRescueType;
        bytes lockerRescueScript;
        uint lockedAmount;
        uint netMinted;
        uint slashingCoreBTCAmount;
        uint reservedTokenForSlash;
        bool isLocker;
        bool isCandidate;
        bool isScriptHash;
        address lockedToken;
        uint inactivationTimestamp;
    }

    struct lockersLibConstants {
        uint OneHundredPercent;
        uint HealthFactor;
        uint UpperHealthFactor;
        uint MaxLockerFee;
        uint NativeTokenDecimal;
        address NativeToken;
    }

    struct lockersLibParam {
        address coreBTC;
        address ccBurnRouter;
        address exchangeConnector;
        address priceOracle;
        address collaterals;

        uint lockerPercentageFee;
        uint collateralRatio;
        uint liquidationRatio;
        uint priceWithDiscountRatio;
        uint slashCompensationRatio;
    }
}
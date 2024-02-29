// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../common/types/ScriptTypesEnum.sol";

library DataTypes {

    /// @notice                             Structure for registering lockers
    /// @dev
    /// @param lockerLockingScript          Locker redeem script
    /// @param lockerRescueType             Locker script type in case of getting BTCs back
    /// @param lockerRescueScript           Locker script in case of getting BTCs back
    /// @param nativeTokenLockedAmount      Bond amount of locker in native token of the target chain
    /// @param netMinted                    Total minted - total burnt
    /// @param slashingCoreBTCAmount        Total amount of coreBTC a locker must be slashed
    /// @param reservedNativeTokenForSlash  Total native token reserved to support slashing coreBTC
    /// @param isLocker                     Indicates that is already a locker or not
    /// @param isCandidate                  Indicates that is a candidate or not
    /// @param isScriptHash                 Shows if it's script hash
    ///                                     has enough collateral to accept more minting requests)
    struct locker {
        bytes lockerLockingScript;
        ScriptTypes lockerRescueType;
        bytes lockerRescueScript;
        uint nativeTokenLockedAmount;
        uint netMinted;
        uint slashingCoreBTCAmount;
        uint reservedNativeTokenForSlash;
        bool isLocker;
        bool isCandidate;
        bool isScriptHash;
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

        uint minRequiredTNTLockedAmount;
        uint lockerPercentageFee;
        uint collateralRatio;
        uint liquidationRatio;
        uint priceWithDiscountRatio;
        uint slashCompensationRatio;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../oracle/interfaces/IPriceOracle.sol";
import "../erc20/interfaces/ICoreBTC.sol";
import "../types/DataTypes.sol";
import "../common/types/ScriptTypesEnum.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

library LockersLib {

    function requestToBecomeLockerValidation(
        mapping(address => DataTypes.locker) storage lockersMapping,
        DataTypes.lockersLibParam memory libParams,
        address theLockerTargetAddress,
        uint _lockedNativeTokenAmount
    ) external {

        require(
            !lockersMapping[msg.sender].isCandidate,
            "Lockers: is candidate"
        );

        require(
            !lockersMapping[msg.sender].isLocker,
            "Lockers: is locker"
        );

        require(
            _lockedNativeTokenAmount >= libParams.minRequiredTNTLockedAmount && msg.value == _lockedNativeTokenAmount,
            "Lockers: low TNT"
        );

        require(
            theLockerTargetAddress == address(0),
            "Lockers: used locking script"
        );

    }

    function requestToBecomeLocker(
        mapping(address => DataTypes.locker) storage lockersMapping,
        bytes calldata _candidateLockingScript,
        uint _lockedNativeTokenAmount,
        ScriptTypes _lockerRescueType,
        bytes calldata _lockerRescueScript
    ) external {

        DataTypes.locker memory locker_;
        locker_.lockerLockingScript = _candidateLockingScript;
        locker_.nativeTokenLockedAmount = _lockedNativeTokenAmount;
        locker_.isCandidate = true;
        locker_.lockerRescueType = _lockerRescueType;
        locker_.lockerRescueScript = _lockerRescueScript;

        lockersMapping[msg.sender] = locker_;

    }

    function buySlashedCollateralOfLocker(
        DataTypes.locker storage theLocker,
        uint _collateralAmount
    ) external returns (uint neededCoreBTC) {

        require(
            theLocker.isLocker,
            "Lockers: input address is not a valid locker"
        );

        require(
            _collateralAmount <= theLocker.reservedNativeTokenForSlash,
            "Lockers: not enough slashed collateral to buy"
        );

        neededCoreBTC = theLocker.slashingCoreBTCAmount * _collateralAmount / theLocker.reservedNativeTokenForSlash;

        if (neededCoreBTC < theLocker.slashingCoreBTCAmount) {
            // to avoid precision loss (so buyer cannot profit of it)
            neededCoreBTC = neededCoreBTC + 1;
        }

        // Updates locker's slashing info
        theLocker.slashingCoreBTCAmount =
            theLocker.slashingCoreBTCAmount - neededCoreBTC;

        theLocker.reservedNativeTokenForSlash =
            theLocker.reservedNativeTokenForSlash - _collateralAmount;

    }

    function liquidateLocker(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _collateralAmount
    ) external view returns (uint neededCoreBTC) {

        require(
            theLocker.isLocker,
            "Lockers: input address is not a valid locker"
        );

        // DataTypes.locker memory theLiquidatingLocker = lockersMapping[_lockerTargetAddress];
        uint priceOfCollateral = priceOfOneUnitOfCollateralInBTC(
            libConstants,
            libParams
        );

        // Checks that the collateral has become unhealthy
        require(
            calculateHealthFactor(
                theLocker,
                libConstants,
                libParams,
                priceOfCollateral
            ) < libConstants.HealthFactor,
            "Lockers: is healthy"
        );

        uint _maxBuyableCollateral = maximumBuyableCollateral(
            theLocker,
            libConstants,
            libParams,
            priceOfCollateral
        );

        if (_maxBuyableCollateral > theLocker.nativeTokenLockedAmount) {
            _maxBuyableCollateral = theLocker.nativeTokenLockedAmount;
        }

        require(
            _collateralAmount <= _maxBuyableCollateral,
            "Lockers: not enough collateral to buy"
        );

        // Needed amount of CoreBTC to buy collateralAmount
        neededCoreBTC = neededCoreBTCToBuyCollateral(
            libConstants,
            libParams,
            _collateralAmount,
            priceOfCollateral
        );

        neededCoreBTC = neededCoreBTC + 1; // to prevent precision loss

    }

    function slashThiefLocker(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _rewardAmount,
        uint _amount
    ) external returns (uint rewardInNativeToken, uint neededNativeTokenForSlash) {

        require(
            theLocker.isLocker,
            "Lockers: input address is not a valid locker"
        );

        uint equivalentNativeToken = IPriceOracle(libParams.priceOracle).equivalentOutputAmount(
            _amount, // Total amount of CoreBTC that is slashed
            ICoreBTC(libParams.coreBTC).decimals(), // Decimal of coreBTC
            libConstants.NativeTokenDecimal, // Decimal of TNT
            libParams.coreBTC, // Input token
            libConstants.NativeToken // Output token
        );

        rewardInNativeToken = equivalentNativeToken*_rewardAmount/_amount;
        neededNativeTokenForSlash = equivalentNativeToken*libParams.liquidationRatio/libConstants.OneHundredPercent;

        if ((rewardInNativeToken + neededNativeTokenForSlash) > theLocker.nativeTokenLockedAmount) {
            // Divides total locker's collateral proportional to reward amount and slash amount
            rewardInNativeToken = rewardInNativeToken*theLocker.nativeTokenLockedAmount/
                (rewardInNativeToken + neededNativeTokenForSlash);
            neededNativeTokenForSlash = theLocker.nativeTokenLockedAmount - rewardInNativeToken;
        }

        // Updates locker's bond (in TNT)
        theLocker.nativeTokenLockedAmount
            = theLocker.nativeTokenLockedAmount - (rewardInNativeToken + neededNativeTokenForSlash);

        if (_amount > theLocker.netMinted) {
            _amount = theLocker.netMinted;
        }

        theLocker.netMinted
            = theLocker.netMinted - _amount;

        theLocker.slashingCoreBTCAmount
            = theLocker.slashingCoreBTCAmount + _amount;

        theLocker.reservedNativeTokenForSlash
            = theLocker.reservedNativeTokenForSlash + neededNativeTokenForSlash;
    }

    function slashIdleLocker(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _rewardAmount,
        uint _amount
    ) external returns (uint equivalentNativeToken) {

        require(
            theLocker.isLocker,
            "Lockers: input address is not a valid locker"
        );

        equivalentNativeToken = IPriceOracle(libParams.priceOracle).equivalentOutputAmount(
            _rewardAmount + _amount, // Total amount of CoreBTC that is slashed
            ICoreBTC(libParams.coreBTC).decimals(), // Decimal of coreBTC
            libConstants.NativeTokenDecimal, // Decimal of TNT
            libParams.coreBTC, // Input token
            libConstants.NativeToken // Output token
        );

        if (equivalentNativeToken > theLocker.nativeTokenLockedAmount) {
            equivalentNativeToken = theLocker.nativeTokenLockedAmount;
        }

        // Updates locker's bond (in TNT)
        theLocker.nativeTokenLockedAmount
        = theLocker.nativeTokenLockedAmount - equivalentNativeToken;
    }

    function maximumBuyableCollateral(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _priceOfOneUnitOfCollateral
    ) public view returns (uint) {

        // maxBuyable <= (upperHealthFactor*netMinted*liquidationRatio/10000 - nativeTokenLockedAmount*nativeTokenPrice)/(upperHealthFactor*liquidationRatio*discountedPrice - nativeTokenPrice)
        //  => maxBuyable <= (upperHealthFactor*netMinted*liquidationRatio * 10^18  - nativeTokenLockedAmount*nativeTokenPrice * 10^8)/(upperHealthFactor*liquidationRatio*discountedPrice - nativeTokenPrice * 10^8)

        uint coreBTCDecimal = ERC20(libParams.coreBTC).decimals();

        uint antecedent = (libConstants.UpperHealthFactor * theLocker.netMinted * libParams.liquidationRatio * (10 ** libConstants.NativeTokenDecimal)) -
        (theLocker.nativeTokenLockedAmount * _priceOfOneUnitOfCollateral * (10 ** coreBTCDecimal));

        uint consequent = ((libConstants.UpperHealthFactor * libParams.liquidationRatio * _priceOfOneUnitOfCollateral * libParams.priceWithDiscountRatio)/libConstants.OneHundredPercent) -
        (_priceOfOneUnitOfCollateral * (10 ** coreBTCDecimal));

        return antecedent/consequent;
    }

    function calculateHealthFactor(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _priceOfOneUnitOfCollateral
    ) public view returns (uint) {

        require(
            theLocker.netMinted > 0 && libParams.liquidationRatio > 0,
            "Lockers: netMinted or liquidationRatio is zero"
        );

        return (_priceOfOneUnitOfCollateral * theLocker.nativeTokenLockedAmount *
            (10 ** (1 + ERC20(libParams.coreBTC).decimals())))/
                (theLocker.netMinted * libParams.liquidationRatio * (10 ** (1 + libConstants.NativeTokenDecimal)));
    }

    function neededCoreBTCToBuyCollateral(
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _collateralAmount,
        uint _priceOfCollateral
    ) public pure returns (uint) {
        return (_collateralAmount * _priceOfCollateral * libParams.priceWithDiscountRatio)/
            (libConstants.OneHundredPercent*(10 ** libConstants.NativeTokenDecimal));
    }

    function addToCollateral(
        DataTypes.locker storage theLocker,
        uint _addingNativeTokenAmount
    ) external {

        require(
            theLocker.isLocker,
            "Lockers: no locker"
        );

        theLocker.nativeTokenLockedAmount =
        theLocker.nativeTokenLockedAmount + _addingNativeTokenAmount;
    }

    function removeFromCollateral(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _priceOfOneUnitOfCollateral,
        uint _removingNativeTokenAmount
    ) external {

        require(
            theLocker.isLocker,
            "Lockers: account is not a locker"
        );

        // Capacity of locker = (locker's collateral value in CoreBTC) * (collateral ratio) - (minted CoreBTC)
        uint lockerCapacity = (theLocker.nativeTokenLockedAmount * _priceOfOneUnitOfCollateral *
            libConstants.OneHundredPercent)/
                (libParams.collateralRatio * (10 ** libConstants.NativeTokenDecimal)) - theLocker.netMinted;

        uint maxRemovableCollateral = (lockerCapacity * (10 ** libConstants.NativeTokenDecimal))/_priceOfOneUnitOfCollateral;

        require(
            _removingNativeTokenAmount <= maxRemovableCollateral,
            "Lockers: more than max removable collateral"
        );

        require(
            theLocker.nativeTokenLockedAmount - _removingNativeTokenAmount >= libParams.minRequiredTNTLockedAmount,
            "Lockers: less than min collateral"
        );

        theLocker.nativeTokenLockedAmount =
        theLocker.nativeTokenLockedAmount - _removingNativeTokenAmount;
    }

    function priceOfOneUnitOfCollateralInBTC(
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams
    ) public view returns (uint) {

        return IPriceOracle(libParams.priceOracle).equivalentOutputAmount(
            (10**libConstants.NativeTokenDecimal), // 1 Ether is 10^18 wei
            libConstants.NativeTokenDecimal,
            ICoreBTC(libParams.coreBTC).decimals(),
            libConstants.NativeToken,
            libParams.coreBTC
        );

    }


    function lockerCollateralInCoreBTC(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams
    ) public view returns (uint) {

        return IPriceOracle(libParams.priceOracle).equivalentOutputAmount(
            theLocker.nativeTokenLockedAmount,
            libConstants.NativeTokenDecimal,
            ICoreBTC(libParams.coreBTC).decimals(),
            libConstants.NativeToken,
            libParams.coreBTC
        );
    }

    function getLockerCapacity(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams
    ) external view returns (uint) {
        uint _lockerCollateralInCoreBTC = lockerCollateralInCoreBTC(
            theLocker,
            libConstants,
            libParams
        )*libConstants.OneHundredPercent/libParams.collateralRatio;

        if (_lockerCollateralInCoreBTC > theLocker.netMinted) {
            return _lockerCollateralInCoreBTC - theLocker.netMinted;
        } else {
            return 0;
        }
    }

    function getHealthFactor(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams
    ) external view returns(uint){
        require(
            theLocker.isLocker,
            "Lockers: no locker"
        );

        // calculate collateral value measured in BTC
        uint priceOfCollateral = priceOfOneUnitOfCollateralInBTC(
            libConstants,
            libParams
        );

        require(
            priceOfCollateral > 0,
            "Lockers: invalid price"
        );

        return calculateHealthFactor(
            theLocker,
            libConstants,
            libParams,
            priceOfCollateral
        );
    }

    function getMaximumBuyableCollateral(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams
    ) external view returns (uint) {
        require(
            theLocker.isLocker,
            "Lockers: no locker"
        );

        uint priceOfCollateral = priceOfOneUnitOfCollateralInBTC(
            libConstants,
            libParams
        );

        uint _maxBuyableCollateral = maximumBuyableCollateral(
            theLocker,
            libConstants,
            libParams,
            priceOfCollateral
        );

        return Math.min(_maxBuyableCollateral, theLocker.nativeTokenLockedAmount);
    }

    function getNeededCoreBTCToBuyCollateral(
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _collateralAmount
    ) external view returns(uint) {
        uint priceOfCollateral = priceOfOneUnitOfCollateralInBTC(
            libConstants,
            libParams
        );

        return neededCoreBTCToBuyCollateral(
            libConstants,
            libParams,
            _collateralAmount,
            priceOfCollateral
        );
    }

}
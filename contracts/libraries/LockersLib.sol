// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../oracle/interfaces/IPriceOracle.sol";
import "../erc20/interfaces/ICoreBTC.sol";
import "../types/DataTypes.sol";
import "../common/types/ScriptTypesEnum.sol";
import "../lockers/interfaces/ICollaterals.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LockersLib {

    using SafeERC20 for IERC20;

    function requestToBecomeLockerValidation(
        mapping(address => DataTypes.locker) storage lockersMapping,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        address theLockerTargetAddress,
        uint _lockedAmount,
        address _lockedToken
    ) external {

        require(
            !lockersMapping[msg.sender].isCandidate,
            "Lockers: is candidate"
        );

        require(
            !lockersMapping[msg.sender].isLocker,
            "Lockers: is locker"
        );

        ICollaterals(libParams.collaterals).checkLockedAmount(
            _lockedToken,
            _lockedAmount
        );

        if (_lockedToken == libConstants.NativeToken) {
            require(
                msg.value == _lockedAmount,
                "Lockers: low TNT"
            );
        }

        require(
            theLockerTargetAddress == address(0),
            "Lockers: used locking script"
        );

        // Transfer erc20 token to lockers if collateral is not TNT
        if (_lockedToken != libConstants.NativeToken) {
            IERC20(_lockedToken).safeTransferFrom(
                msg.sender,
                address(this),
                _lockedAmount
            );
        }
    }

    function requestToBecomeLocker(
        mapping(address => DataTypes.locker) storage lockersMapping,
        bytes calldata _candidateLockingScript,
        uint _lockedAmount,
        ScriptTypes _lockerRescueType,
        bytes calldata _lockerRescueScript,
        address _lockedToken
    ) external {

        DataTypes.locker memory locker_;
        locker_.lockerLockingScript = _candidateLockingScript;
        locker_.lockedAmount = _lockedAmount;
        locker_.isCandidate = true;
        locker_.lockerRescueType = _lockerRescueType;
        locker_.lockerRescueScript = _lockerRescueScript;
        locker_.lockedToken = _lockedToken;

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
            _collateralAmount <= theLocker.reservedTokenForSlash,
            "Lockers: not enough slashed collateral to buy"
        );

        neededCoreBTC = theLocker.slashingCoreBTCAmount * _collateralAmount / theLocker.reservedTokenForSlash;

        if (neededCoreBTC < theLocker.slashingCoreBTCAmount) {
            // to avoid precision loss (so buyer cannot profit of it)
            neededCoreBTC = neededCoreBTC + 1;
        }

        // Updates locker's slashing info
        theLocker.slashingCoreBTCAmount -= neededCoreBTC;

        theLocker.reservedTokenForSlash -= _collateralAmount;

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

        uint priceOfCollateral = priceOfOneUnitOfCollateralInBTC(
            libParams,
            theLocker.lockedToken
        );

        // Checks that the collateral has become unhealthy
        require(
            calculateHealthFactor(
                theLocker,
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

        if (_maxBuyableCollateral > theLocker.lockedAmount) {
            _maxBuyableCollateral = theLocker.lockedAmount;
        }

        require(
            _collateralAmount <= _maxBuyableCollateral,
            "Lockers: not enough collateral to buy"
        );

        // Needed amount of CoreBTC to buy collateralAmount
        neededCoreBTC = neededCoreBTCToBuyCollateral(
            libConstants,
            libParams,
            theLocker.lockedToken,
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
    ) external returns (uint rewardInCollateral, uint neededTokenForSlash) {

        require(
            theLocker.isLocker,
            "Lockers: input address is not a valid locker"
        );

        uint equivalentCollateral = IPriceOracle(libParams.priceOracle).equivalentOutputAmount(
            _amount, // Total amount of CoreBTC that is slashed
            ICoreBTC(libParams.coreBTC).decimals(), // Decimal of coreBTC
            ICollaterals(libParams.collaterals).getDecimals(theLocker.lockedToken), // Decimal of Collateral
            libParams.coreBTC, // Input token
            theLocker.lockedToken // Output token
        );

        rewardInCollateral = equivalentCollateral*_rewardAmount/_amount;
        neededTokenForSlash = equivalentCollateral*libParams.liquidationRatio/libConstants.OneHundredPercent;

        if ((rewardInCollateral + neededTokenForSlash) > theLocker.lockedAmount) {
            // Divides total locker's collateral proportional to reward amount and slash amount
            rewardInCollateral = rewardInCollateral*theLocker.lockedAmount/
                (rewardInCollateral + neededTokenForSlash);
            neededTokenForSlash = theLocker.lockedAmount - rewardInCollateral;
        }

        // Updates locker's bond
        theLocker.lockedAmount -= (rewardInCollateral + neededTokenForSlash);

        if (_amount > theLocker.netMinted) {
            _amount = theLocker.netMinted;
        }

        theLocker.netMinted -= _amount;

        theLocker.slashingCoreBTCAmount += _amount;

        theLocker.reservedTokenForSlash += neededTokenForSlash;
    }

    function slashIdleLocker(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibParam memory libParams,
        uint _rewardAmount,
        uint _amount
    ) external returns (uint equivalentCollateral) {

        require(
            theLocker.isLocker,
            "Lockers: input address is not a valid locker"
        );

        equivalentCollateral = IPriceOracle(libParams.priceOracle).equivalentOutputAmount(
            _rewardAmount + _amount, // Total amount of CoreBTC that is slashed
            ICoreBTC(libParams.coreBTC).decimals(), // Decimal of coreBTC
            ICollaterals(libParams.collaterals).getDecimals(theLocker.lockedToken), // Decimal of Collateral
            libParams.coreBTC, // Input token
            theLocker.lockedToken // Output token
        );

        if (equivalentCollateral > theLocker.lockedAmount) {
            equivalentCollateral = theLocker.lockedAmount;
        }

        // Updates locker's bond
        theLocker.lockedAmount -= equivalentCollateral;
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
        uint collateralDecimals = ICollaterals(libParams.collaterals).getDecimals(theLocker.lockedToken);
        require(
            libConstants.UpperHealthFactor * theLocker.netMinted * libParams.liquidationRatio * (10 ** collateralDecimals) >= theLocker.lockedAmount * _priceOfOneUnitOfCollateral * (10 ** coreBTCDecimal),
            "Lockers: invalid antecedent"
        );
        require(
            (libConstants.UpperHealthFactor * libParams.liquidationRatio * _priceOfOneUnitOfCollateral * libParams.priceWithDiscountRatio)/libConstants.OneHundredPercent > _priceOfOneUnitOfCollateral * (10 ** coreBTCDecimal),
            "Lockers: invalid consequent"
        );

        uint antecedent = (libConstants.UpperHealthFactor * theLocker.netMinted * libParams.liquidationRatio * (10 ** collateralDecimals)) -
        (theLocker.lockedAmount * _priceOfOneUnitOfCollateral * (10 ** coreBTCDecimal));

        uint consequent = ((libConstants.UpperHealthFactor * libParams.liquidationRatio * _priceOfOneUnitOfCollateral * libParams.priceWithDiscountRatio)/libConstants.OneHundredPercent) -
        (_priceOfOneUnitOfCollateral * (10 ** coreBTCDecimal));

        return antecedent/consequent;
    }

    function calculateHealthFactor(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibParam memory libParams,
        uint _priceOfOneUnitOfCollateral
    ) public view returns (uint) {

        require(
            theLocker.netMinted > 0 && libParams.liquidationRatio > 0,
            "Lockers: netMinted or liquidationRatio is zero"
        );

        return (_priceOfOneUnitOfCollateral * theLocker.lockedAmount *
            (10 ** (1 + ERC20(libParams.coreBTC).decimals())))/
                (theLocker.netMinted * libParams.liquidationRatio *
                    (10 ** (1 + ICollaterals(libParams.collaterals).getDecimals(theLocker.lockedToken))));
    }

    function neededCoreBTCToBuyCollateral(
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        address _collateralToken,
        uint _collateralAmount,
        uint _priceOfCollateral
    ) public view returns (uint) {
        return (_collateralAmount * _priceOfCollateral * libParams.priceWithDiscountRatio)/
            (libConstants.OneHundredPercent*(10 ** ICollaterals(libParams.collaterals).getDecimals(_collateralToken)));
    }

    function addToCollateral(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        uint _addingCollateralAmount
    ) external {

        require(
            theLocker.isLocker,
            "Lockers: no locker"
        );

        // Transfer erc20 token to lockers if collateral is not TNT
        if (theLocker.lockedToken != libConstants.NativeToken) {
            IERC20(theLocker.lockedToken).safeTransferFrom(
                msg.sender,
                address(this),
                _addingCollateralAmount
            );
        }

        theLocker.lockedAmount += _addingCollateralAmount;
    }

    function removeFromCollateral(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _removingCollateralAmount
    ) external {
        require(
            theLocker.isLocker,
            "Lockers: no locker"
        );

        require(
            !isLockerActive(theLocker),
            "Lockers: still active"
        );

        uint _priceOfOneUnitOfCollateral = priceOfOneUnitOfCollateralInBTC(
            libParams,
            theLocker.lockedToken
        );

        uint collateralDecimals = ICollaterals(libParams.collaterals).getDecimals(theLocker.lockedToken);

        // Capacity of locker = (locker's collateral value in CoreBTC) * (collateral ratio) - (minted CoreBTC)
        uint lockerCapacity = (theLocker.lockedAmount * _priceOfOneUnitOfCollateral *
            libConstants.OneHundredPercent)/
                (libParams.collateralRatio * (10 ** collateralDecimals)) - theLocker.netMinted;

        uint maxRemovableCollateral = (lockerCapacity * (10 ** collateralDecimals))/_priceOfOneUnitOfCollateral;

        require(
            _removingCollateralAmount <= maxRemovableCollateral,
            "Lockers: more than max removable collateral"
        );

        require(
            theLocker.lockedAmount - _removingCollateralAmount >= ICollaterals(libParams.collaterals).getMinLockedAmount(theLocker.lockedToken),
            "Lockers: less than min collateral"
        );

        theLocker.lockedAmount -= _removingCollateralAmount;
    }

    function priceOfOneUnitOfCollateralInBTC(
        DataTypes.lockersLibParam memory libParams,
        address _collateralToken
    ) public view returns (uint) {
        uint collateralDecimals = ICollaterals(libParams.collaterals).getDecimals(_collateralToken);

        return IPriceOracle(libParams.priceOracle).equivalentOutputAmount(
            (10**collateralDecimals), // 1 Collateral is 10^collateralDecimals
            collateralDecimals,
            ICoreBTC(libParams.coreBTC).decimals(),
            _collateralToken,
            libParams.coreBTC
        );
    }

    function lockerCollateralInCoreBTC(
        DataTypes.locker storage theLocker,
        DataTypes.lockersLibParam memory libParams
    ) public view returns (uint) {

        return IPriceOracle(libParams.priceOracle).equivalentOutputAmount(
            theLocker.lockedAmount,
            ICollaterals(libParams.collaterals).getDecimals(theLocker.lockedToken),
            ICoreBTC(libParams.coreBTC).decimals(),
            theLocker.lockedToken,
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
        DataTypes.lockersLibParam memory libParams
    ) external view returns(uint){
        require(
            theLocker.isLocker,
            "Lockers: no locker"
        );

        // calculate collateral value measured in BTC
        uint priceOfCollateral = priceOfOneUnitOfCollateralInBTC(
            libParams,
            theLocker.lockedToken
        );

        require(
            priceOfCollateral > 0,
            "Lockers: invalid price"
        );

        return calculateHealthFactor(
            theLocker,
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
            libParams,
            theLocker.lockedToken
        );

        uint _maxBuyableCollateral = maximumBuyableCollateral(
            theLocker,
            libConstants,
            libParams,
            priceOfCollateral
        );

        return Math.min(_maxBuyableCollateral, theLocker.lockedAmount);
    }

    function getNeededCoreBTCToBuyCollateral(
        DataTypes.lockersLibConstants memory libConstants,
        DataTypes.lockersLibParam memory libParams,
        uint _collateralAmount,
        address _collateralToken
    ) external view returns(uint) {
        uint priceOfCollateral = priceOfOneUnitOfCollateralInBTC(
            libParams,
            _collateralToken
        );

        return neededCoreBTCToBuyCollateral(
            libConstants,
            libParams,
            _collateralToken,
            _collateralAmount,
            priceOfCollateral
        );
    }

    function isLockerActive(
        DataTypes.locker memory theLocker
    ) public view returns (bool) {
        return theLocker.isLocker && (theLocker.inactivationTimestamp == 0 || theLocker.inactivationTimestamp > block.timestamp);
    }

    function revokeRequest(
         mapping(address => DataTypes.locker) storage lockersMapping,
         address[] storage candidateLockers,
         address _lockerTargetAddress
    ) external returns (DataTypes.locker memory lockerRequest){
        require(
            lockersMapping[_lockerTargetAddress].isCandidate,
            "Lockers: no req"
        );

        // Loads locker's information
        lockerRequest = lockersMapping[_lockerTargetAddress];

        // Removes candidate from lockersMapping
        delete lockersMapping[_lockerTargetAddress];
        _removeLockerFromList(candidateLockers, _lockerTargetAddress);
    }

    function isCollateralUnused(
        mapping(address => DataTypes.locker) storage lockersMapping,
        address[] storage targetAddressList,
        address _token
    ) external view returns (bool) {
        uint len = targetAddressList.length;

        for(uint i = 0; i < len; i++) {
            DataTypes.locker memory theLocker = lockersMapping[targetAddressList[i]];
            if (theLocker.lockedToken == _token) {
                return false;
            }
        }
        return true;
    }

    function removeLocker(
        mapping(address => DataTypes.locker) storage lockersMapping,
        mapping(bytes => address) storage lockerTargetAddress,
        address[] storage targetAddressList,
        address _lockerTargetAddress
    ) external returns (DataTypes.locker memory removingLocker){

        require(
            lockersMapping[_lockerTargetAddress].isLocker,
            "Lockers: no locker"
        );

        require(
            !isLockerActive(lockersMapping[_lockerTargetAddress]),
            "Lockers: still active"
        );

        require(
            lockersMapping[_lockerTargetAddress].netMinted == 0,
            "Lockers: 0 net minted"
        );

        require(
            lockersMapping[_lockerTargetAddress].slashingCoreBTCAmount == 0,
            "Lockers: 0 slashing TBTC"
        );

        removingLocker = lockersMapping[_lockerTargetAddress];

        // Removes locker from lockerTargetAddress and lockersMapping
        delete lockerTargetAddress[lockersMapping[_lockerTargetAddress].lockerLockingScript];
        delete lockersMapping[_lockerTargetAddress];

        _removeLockerFromList(targetAddressList, _lockerTargetAddress);
    }

    function moveLocker(
        address[] storage fromList,
        address[] storage toList,
        address _lockerTargetAddress
    ) external {
        _removeLockerFromList(fromList, _lockerTargetAddress);
        toList.push(_lockerTargetAddress);
    }

    function _removeLockerFromList(
        address[] storage targetAddressList,
        address _lockerTargetAddress
    ) private {
        // Find the index of the target address in the list
        uint len = targetAddressList.length;
        uint i = 0;
        for (; i < len; i++) {
            if (targetAddressList[i] == _lockerTargetAddress) {
                break;
            }
        }

        // Exit if the target address cannot be found
        if (i == len) return;

        // If the target address is not at the end of the list,
        // replace it with the last element of the list,
        // then the last element of the list will become invalid
        if (i < len - 1) {
            targetAddressList[i] = targetAddressList[len-1];
        }

        // Remove the invalid element from the end of the list
        targetAddressList.pop();
    }

    // *************** Handling data compatibility after contract upgrade ***************

    function initForMultipleCollateralsFeature(
        mapping(address => DataTypes.locker) storage lockersMapping,
        mapping(address => uint) storage lockerInactivationTimestamp,
        address[] storage candidateLockers,
        address[] storage approvedLockers,
        address[] memory _initialCandidates,
        uint _totalNumberOfCandidates
    ) external {
        // Initialize the `candidateLockers` list
        _initCandidateLockers(lockersMapping, candidateLockers, _initialCandidates, _totalNumberOfCandidates);

        // Initialize the `lockedToken` and `inactivationTimestamp` fields of all lockers in the `candidateLockers` list
        _initLockerUnknownFields(lockersMapping, lockerInactivationTimestamp, candidateLockers);

        // Initialize the `lockedToken` and `inactivationTimestamp` fields of all lockers in the `approvedLockers` list
        _initLockerUnknownFields(lockersMapping, lockerInactivationTimestamp, approvedLockers);
    }

    function _initCandidateLockers(
        mapping(address => DataTypes.locker) storage lockersMapping,
        address[] storage candidateLockers,
        address[] memory _initialCandidates,
        uint _totalNumberOfCandidates
    ) private {
        require(
            candidateLockers.length == 0,
            "Lockers: candidate lockers is already inited"
        );

        require(
            _initialCandidates.length == _totalNumberOfCandidates,
            "Lockers: target address list is invalid"
        );

        for (uint i = 0; i < _totalNumberOfCandidates; i++) {
            address targetAddress = _initialCandidates[i];

            require(
                lockersMapping[targetAddress].isCandidate,
                "Lockers: is not candidate"
            );

            // Detect duplicate candidate addresses
            for (uint j = 0; j < candidateLockers.length; j++) {
                require(
                    targetAddress != candidateLockers[j],
                    "Lockers: duplicate target address"
                );
            }

            candidateLockers.push(targetAddress);
        }
    }

    function _initLockerUnknownFields(
        mapping(address => DataTypes.locker) storage lockersMapping,
        mapping(address => uint) storage lockerInactivationTimestamp,
        address[] storage targetAddressList
    ) private {
        for (uint i = 0; i < targetAddressList.length; i++) {
            DataTypes.locker storage theLocker = lockersMapping[targetAddressList[i]];

            // Init locked token
            if (theLocker.lockedAmount > 0 && theLocker.lockedToken == address(0)) {
                theLocker.lockedToken = address(1);
            }

            // Init inactivation timestamp
            if (theLocker.isLocker && theLocker.inactivationTimestamp == 0 &&
                lockerInactivationTimestamp[targetAddressList[i]] > 0) {
                theLocker.inactivationTimestamp = lockerInactivationTimestamp[targetAddressList[i]];
            }
        }
    }
}
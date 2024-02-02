// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./ILockersStorage.sol";

interface ILockers is ILockersStorage {

     // Events

    event RequestAddLocker(
        address indexed lockerTargetAddress,
        bytes lockerLockingScript,
        uint lockedAmount,
        address lockedToken
    );

    event RevokeAddLockerRequest(
        address indexed lockerTargetAddress,
        bytes lockerLockingScript,
        uint lockedAmount,
        address lockedToken
    );

    event RequestInactivateLocker(
        address indexed lockerTargetAddress,
        uint indexed inactivationTimestamp,
        bytes lockerLockingScript,
        uint lockedAmount,
        uint netMinted,
        address lockedToken
    );

    event ActivateLocker(
        address indexed lockerTargetAddress,
        bytes lockerLockingScript,
        uint lockedAmount,
        uint netMinted,
        address lockedToken
    );

    event LockerAdded(
        address indexed lockerTargetAddress,
        bytes lockerLockingScript,
        uint lockedAmount,
        uint addingTime,
        address lockedToken
    );

    event LockerRemoved(
        address indexed lockerTargetAddress,
        bytes lockerLockingScript,
        uint unlockedAmount,
        address unlockedToken
    );

    event LockerSlashed(
        address indexed lockerTargetAddress,
        uint rewardAmount,
        address indexed rewardRecipient,
        uint amount,
        address indexed recipient,
        uint slashedCollateralAmount,
        uint slashTime,
        bool isForCCBurn,
        address slashedCollateralToken
    );

    event LockerLiquidated(
        address indexed lockerTargetAddress,
        address indexed liquidatorAddress,
        uint collateralAmount,
        uint coreBTCAmount,
        uint liquidateTime,
        address collateralToken
    );

    event LockerSlashedCollateralSold(
        address indexed lockerTargetAddress,
        address indexed buyerAddress,
        uint slashingAmount,
        uint coreBTCAmount,
        uint slashingTime,
        address slashingToken
    );

    event CollateralAdded(
        address indexed lockerTargetAddress,
        uint addedCollateral,
        uint totalCollateral,
        uint addingTime,
        address collateralToken
    );

    event CollateralRemoved(
        address indexed lockerTargetAddress,
        uint removedCollateral,
        uint totalCollateral,
        uint removingTime,
        address collateralToken
    );

    event MintByLocker(
        address indexed lockerTargetAddress,
        address indexed receiver,
        bytes32 bitcoinTxId,
        uint mintedAmount,
        uint lockerFee,
        uint mintingTime
    );

    event BurnByLocker(
        address indexed lockerTargetAddress,
        uint burntAmount,
        uint lockerFee,
        uint burningTime
    );

    event MinterAdded(
        address indexed account
    );

    event MinterRemoved(
        address indexed account
    );

    event BurnerAdded(
        address indexed account
    );

    event BurnerRemoved(
        address indexed account
    );

    event NewLockerPercentageFee(
        uint oldLockerPercentageFee,
        uint newLockerPercentageFee
    );

    event NewPriceWithDiscountRatio(
        uint oldPriceWithDiscountRatio,
        uint newPriceWithDiscountRatio
    );

    event NewPriceOracle(
        address oldPriceOracle,
        address newPriceOracle
    );

    event NewCCBurnRouter(
        address oldCCBurnRouter,
        address newCCBurnRouter
    );

    event NewCoreBTC(
        address oldCoreBTC,
        address newCoreBTC
    );

    event NewCollateralRatio(
        uint oldCollateralRatio,
        uint newCollateralRatio
    );

    event NewLiquidationRatio(
        uint oldLiquidationRatio,
        uint newLiquidationRatio
    );

    event NewSlashCompensationRatio(
        uint oldSlashCompensationRatio,
        uint newSlashCompensationRatio
    );

    event NewCollaterals(
        address oldCollaterals,
        address newCollaterals
    );

    // Read-only functions

    function getLockerTargetAddress(bytes calldata _lockerLockingScript) external view returns (address);

    function isLocker(bytes calldata _lockerLockingScript) external view returns (bool);

    function getLockerLockingScript(address _lockerTargetAddress) external view returns (bytes memory);

    function isLockerActive(address _lockerTargetAddress) external view returns (bool);

    function getLockerCapacity(address _lockerTargetAddress) external view returns (uint);

    function priceOfOneUnitOfCollateralInBTC(address _collateralToken) external view returns (uint);

    function isMinter(address account) external view returns(bool);

    function isBurner(address account) external view returns(bool);

    function getHealthFactor(address _lockerTargetAddress) external view returns(uint);

    function getMaximumBuyableCollateral(address _lockerTargetAddress) external view returns (uint);

    function getNeededCoreBTCToBuyCollateral(
        address _lockerTargetAddress,
        uint _collateralAmount
    ) external view returns(uint);

    function candidateLockers(uint index) external view returns(address);

    function isCollateralUnused(address _token) external view returns (bool);

    // State-changing functions

    function pauseLocker() external;

    function unPauseLocker() external;

    function addMinter(address _account) external;

    function removeMinter(address _account) external;

    function addBurner(address _account) external;

    function removeBurner(address _account) external;

    function mint(bytes calldata _lockerLockingScript, address _receiver, bytes32 _txId, uint _amount) external returns(uint);

    function burn(bytes calldata _lockerLockingScript, uint256 _amount) external returns(uint);

    function setLockerPercentageFee(uint _lockerPercentageFee) external;

    function setPriceWithDiscountRatio(uint _priceWithDiscountRatio) external;

    function setPriceOracle(address _priceOracle) external;

    function setCCBurnRouter(address _ccBurnRouter) external;

    function setCoreBTC(address _coreBTC) external;

    function setCollateralRatio(uint _collateralRatio) external;

    function setLiquidationRatio(uint _liquidationRatio) external;

    function setSlashCompensationRatio(uint _slashCompensationRatio) external;

    function setCollaterals(address _collaterals) external;

    function liquidateLocker(
        address _lockerTargetAddress,
        uint _btcAmount
    ) external returns (bool);

    function addCollateral(
        address _lockerTargetAddress,
        uint _addingCollateralAmount
    ) external payable returns (bool);

    function removeCollateral(
        uint _removingCollateralAmount
    ) external payable returns (bool);

    function requestToBecomeLocker(
        bytes calldata _lockerLockingScript,
        uint _lockedAmount,
        ScriptTypes _lockerRescueType,
        bytes calldata _lockerRescueScript,
        address _lockedToken
    ) external payable returns (bool);

    function revokeRequest() external returns (bool);

    function addLocker(address _lockerTargetAddress) external returns (bool);

    function requestInactivation() external returns (bool);

    function requestActivation() external returns (bool);

    function selfRemoveLocker() external returns (bool);

    function slashIdleLocker(
        address _lockerTargetAddress,
        uint _rewardAmount,
        address _rewardRecipient,
        uint _amount,
        address _recipient
    ) external returns(bool);

    function slashThiefLocker(
        address _lockerTargetAddress,
        uint _rewardAmount,
        address _rewardRecipient,
        uint _amount
    ) external returns(bool);

    function buySlashedCollateralOfLocker(
        address _lockerTargetAddress,
        uint _collateralAmount
    ) external returns (bool);
}
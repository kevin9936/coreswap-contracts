// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/ICollaterals.sol";
import "./interfaces/ILockers.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CollateralsLogic is ICollaterals, Ownable2StepUpgradeable, UUPSUpgradeable {

    // *************** Modifiers ***************

    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "Lockers: address is zero");
        _;
    }

    modifier nonZeroAmount(uint _amount) {
        require(_amount > 0, "Lockers: amount is zero");
        _;
    }

    // Constants
    uint public constant NATIVE_TOKEN_DECIMAL = 18;
    address public constant NATIVE_TOKEN = address(1);

    // Public variables
    address public override lockers;
    mapping(address => uint) public collateralsMap;
    collateral[] public availableCollaterals;

    constructor() {
        _disableInitializers();
    }

    /// @notice                             Gives default params to initiate collaterals
    /// @param _lockers                     Address of lockers contract
    /// @param _minRequiredCORELockedAmount Minimum required locked amount of native token
    function initialize(
        address _lockers,
        uint _minRequiredCORELockedAmount
    ) public initializer {

        Ownable2StepUpgradeable.__Ownable2Step_init();
        UUPSUpgradeable.__UUPSUpgradeable_init();

        _setLockers(_lockers);
        _addCollateral(NATIVE_TOKEN, _minRequiredCORELockedAmount);
    }

    function renounceOwnership() public virtual override onlyOwner {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // *************** External functions ***************

    /**
     * @dev Gets the total number of supported collateral types
     */
    function getTotalNumber() external view override returns (uint) {
        return availableCollaterals.length;
    }

    /// @notice                     Gets the decimals of collateral
    /// @dev                        The decimals of native token is 18
    ///                             The decimals of ERC-20 token needs to be obtained by calling the decimals method
    /// @param _token               The address of collateral
    /// @return                     The decimals of collateral
    function getDecimals(address _token) external view override returns (uint) {
        checkSupported(_token);

        if (_token == NATIVE_TOKEN) {
            return NATIVE_TOKEN_DECIMAL;
        }

        return ERC20(_token).decimals();
    }

    /// @notice                     Gets the minimum required locked amount of the collateral
    /// @param _token               The address of collateral
    /// @return                     The minimum required locked amount of the token
    function getMinLockedAmount(address _token) public view override returns (uint) {
        checkSupported(_token);

        uint index = collateralsMap[_token] - 1;
        return availableCollaterals[index].minLockedAmount;
    }

    /// @dev Gets collateral information stored in the list
    function getCollateral(uint index) external view override returns (collateral memory) {
        require(index < availableCollaterals.length, "Lockers: index out of bound");
        return availableCollaterals[index];
    }

    /// @notice                     Checks if the locked amount is valid
    /// @param _token               The address of collateral
    /// @param _lockedAmount        The amount of collateral intended for locking
    function checkLockedAmount(
        address _token,
        uint _lockedAmount
    ) external view override {
        uint minLockedAmount = getMinLockedAmount(_token);

        if (_lockedAmount < minLockedAmount) {
            revert InsufficientCollateral(_token, _lockedAmount, minLockedAmount);
        }
    }

    /// @notice                     Sets address of lockers contract
    /// @param _lockers             The address of lockers contract
    function setLockers(address _lockers) external override onlyOwner {
        _setLockers(_lockers);
    }

    /// @notice                     Sets minimum required locked amount of collateral
    /// @param _token               The address of collateral
    /// @param _minLockedAmount     The minimum required locked amount of collateral
    function setMinLockedAmount(
        address _token,
        uint _minLockedAmount
    ) external override onlyOwner {
        _setMinLockedAmount(_token, _minLockedAmount);
    }

    /// @notice                     Adds a collateral to available list
    /// @param _token               The address of collateral
    /// @param _minLockedAmount     The minimum required locked amount of collateral
    function addCollateral(
        address _token,
        uint _minLockedAmount
    ) external override onlyOwner {
        _addCollateral(_token, _minLockedAmount);
    }

    /// @notice                     Removes a collateral from available list
    /// @dev                        Only Lockers contract can call this
    /// @param _token               The address of collateral
    function removeCollateral(address _token) external override onlyOwner {
        _removeCollateral(_token);
    }

    // *************** Internal functions ***************

    /// @notice                     Checks whether a token is supported as collateral
    /// @param _token               The address of collateral
    function checkSupported(address _token) internal view nonZeroAddress(_token) {
        require(collateralsMap[_token] > 0, "Lockers: unsupported collateral");
    }

    /// @notice                     Checks whether a token is not supported as collateral
    /// @param _token               The address of collateral
    function checkUnsupported(address _token) internal view nonZeroAddress(_token) {
        require(collateralsMap[_token] == 0, "Lockers: supported collateral");
    }

    function _setLockers(address _lockers) internal nonZeroAddress(_lockers) {
        emit NewLockers(lockers, _lockers);
        lockers = _lockers;
    }

    function _setMinLockedAmount(
        address _token,
        uint _minLockedAmount
    ) internal nonZeroAmount(_minLockedAmount) {
        checkSupported(_token);

        uint index = collateralsMap[_token] - 1;
        collateral storage item = availableCollaterals[index];

        emit NewMinRequiredLockedAmount(_token, item.minLockedAmount, _minLockedAmount);
        item.minLockedAmount = _minLockedAmount;
    }

    function _addCollateral(
        address _token,
        uint _minLockedAmount
    ) internal nonZeroAmount(_minLockedAmount) {
        checkUnsupported(_token);

        collateral memory item = collateral(_token, _minLockedAmount);
        availableCollaterals.push(item);

        collateralsMap[_token] = availableCollaterals.length;

        emit NewSupportedCollateral(_token, _minLockedAmount);
    }

    function _removeCollateral(address _token) internal nonZeroAddress(_token) {
        checkSupported(_token);

        require(
            ILockers(lockers).isCollateralUnused(_token),
            "Lockers: collateral in use"
        );

        uint index = collateralsMap[_token] - 1;
        uint lastIndex = availableCollaterals.length - 1;
        if (index < lastIndex) {
            availableCollaterals[index] = availableCollaterals[lastIndex];
            collateralsMap[availableCollaterals[index].token] = index + 1;
        }

        availableCollaterals.pop();
        delete collateralsMap[_token];

        emit RevokeSupportedCollateral(_token);
    }
}
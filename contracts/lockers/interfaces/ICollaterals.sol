// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../types/DataTypes.sol";

interface ICollaterals {
    // struct
    struct collateral {
        address token;
        uint minLockedAmount;
    }

    // Events
    event NewMinRequiredLockedAmount(
        address indexed token,
        uint oldMinRequiredLockedAmount,
        uint newMinRequiredLockedAmount
    );

    event NewLockers(address oldLockers, address newLockers);

    event NewSupportedCollateral(address indexed token, uint minLockedAmount);

    event RevokeSupportedCollateral(address indexed token);

    // Errors
    error InsufficientCollateral(address collateralToken, uint lockedAmount, uint minLockedAmount);

    // Read-only functions
    function lockers() external view returns (address);

    function getTotalNumber() external view returns (uint);

    function getDecimals(address _token) external view returns (uint);

    function getMinLockedAmount(address _token) external view returns (uint);

    function getCollateral(uint _index) external view returns (collateral memory);

    function checkLockedAmount(address _token, uint _lockedAmount) external view;


    // State-changing functions
    function setLockers(address _lockers) external;

    function setMinLockedAmount(address _token, uint _minLockedAmount) external;

    function addCollateral(address _token, uint _minLockedAmount) external;

    function removeCollateral(address _token) external;
}
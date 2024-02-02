// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../types/DataTypes.sol";

interface ILockersStorage {
    // Read-only functions

    function coreBTC() external view returns(address);

    function ccBurnRouter() external view returns(address);

    function priceOracle() external view returns(address);

    function collaterals() external view returns(address);

    function lockerPercentageFee() external view returns(uint);

    function collateralRatio() external view returns(uint);

    function liquidationRatio() external view returns(uint);

    function priceWithDiscountRatio() external view returns(uint);

    function slashCompensationRatio() external view returns(uint);

    function totalNumberOfCandidates() external view returns(uint);

    function totalNumberOfLockers() external view returns(uint);

    function approvedLockers(uint index) external view returns(address);
}

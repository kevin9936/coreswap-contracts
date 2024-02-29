// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../common/types/ScriptTypesEnum.sol";

interface IBurnRouterStorage {

	// Read-only functions

    function startingBlockNumber() external view returns (uint);

	function relay() external view returns (address);

	function lockers() external view returns (address);

	function coreBTC() external view returns (address);

	function treasury() external view returns (address);

	function transferDeadline() external view returns (uint);

	function protocolPercentageFee() external view returns (uint);

	function slasherPercentageReward() external view returns (uint);

	function bitcoinFee() external view returns (uint); // Bitcoin transaction fee

	function isUsedAsBurnProof(bytes32 _txId) external view returns (bool);

	function bitcoinFeeOracle() external view returns (address);

	function slasher() external view returns (address);

}
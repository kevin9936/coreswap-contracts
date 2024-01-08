// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ICcTransferRouterStorage {

	// // Structures

	/// @notice                    Structure for recording cross-chain transfer requests
	/// @param inputAmount         Amount of locked BTC on source chain
	/// @param recipientAddress    Address of transfer recipient
	/// @param fee                 Amount of fee that is paid to Porter (tx, relayer and porter fees)
	/// @param isUsed              Whether the tx is used or not
	struct ccTransferRequest {
		uint inputAmount;
		address recipientAddress;
		uint fee;
		bool isUsed;
	}

	// Read-only functions
	
	function startingBlockNumber() external view returns (uint);
	
	function protocolPercentageFee() external view returns (uint);

	function version() external view returns (uint);
	
	function chainId() external view returns (uint);

	function appId() external view returns (uint);

	function relay() external view returns (address);

	function instantRouter() external view returns (address);

	function lockers() external view returns (address);

	function coreBTC() external view returns (address);

	function treasury() external view returns (address);

}
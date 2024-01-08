// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ICcTransferRouter {

	// Events

	/// @notice                    	Emits when a cc transfer request gets done
	/// @param lockerLockingScript  Locking script of the locker on bitcoin network
	/// @param lockerScriptType     Script type of the locker locking script
	/// @param lockerTargetAddress  Address of the locker on EVM based target chain
	/// @param user                	Address of coreBTC recipient
	/// @param inputAmount         	Amount of tokens that user locked on source chain
	/// @param receivedAmount      	Amount of tokens that user receives
	/// @param porter          	Address of porter who submitted the request
	/// @param porterFee       	Amount of fee that is paid to Porter (tx, relayer and porter fees)
	/// @param protocolFee         	Amount of fee that is paid to the protocol
	/// @param bitcoinTxId         	Address of porter who submitted the request
	event CCTransfer(
		bytes indexed lockerLockingScript,
		uint lockerScriptType,
		address lockerTargetAddress,
		address indexed user,
		uint inputAmount,
		uint receivedAmount,
		address porter,
		uint porterFee,
		uint protocolFee,
		bytes32 bitcoinTxId
	);

	/// @notice                     Emits when changes made to relay address
    event NewRelay (
        address oldRelay, 
        address newRelay
    );

    /// @notice                     Emits when changes made to InstantRouter address
    event NewInstantRouter (
        address oldInstantRouter, 
        address newInstantRouter
    );

    /// @notice                     Emits when changes made to Lockers address
    event NewLockers (
        address oldLockers, 
        address newLockers
    );

    /// @notice                     Emits when changes made to CoreBTC address
    event NewCoreBTC (
        address oldCoreBTC, 
        address newCoreBTC
    );

    /// @notice                     Emits when changes made to protocol percentage fee
    event NewProtocolPercentageFee (
        uint oldProtocolPercentageFee, 
        uint newProtocolPercentageFee
    );

    /// @notice                     Emits when changes made to Treasury address
    event NewTreasury (
        address oldTreasury, 
        address newTreasury
    );

	// Read-only functions

	function isRequestUsed(bytes32 _txId) external view returns (bool);

	// State-changing functions

	function setStartingBlockNumber(uint _startingBlockNumber) external;

	function setRelay(address _relay) external;

	function setInstantRouter(address _instantRouter) external;

	function setLockers(address _lockers) external;

	function setCoreBTC(address _coreBTC) external;

	function setTreasury(address _treasury) external;

	function setProtocolPercentageFee(uint _protocolPercentageFee) external;


	function lockProof(
		// Bitcoin tx
		bytes calldata _tx,
		// Bitcoin block number
		uint256 _blockNumber,
		// Merkle proof
		bytes calldata _intermediateNodes,
		uint _index,
		bytes calldata _lockerLockingScript
	) external returns (bool);
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../common/types/ScriptTypesEnum.sol";

interface IBurnRouter {

  	// Events

	/// @notice Emits when a burn request gets submitted
    /// @param userTargetAddress Address of the user
    /// @param userScript Script of user on Bitcoin
    /// @param scriptType Script type of the user (for bitcoin address)
    /// @param coreBTCAmount amount of coreBTC that user sent OR Amount of coreBTC after exchanging
    /// @param burntAmount that user will receive (after reducing fees)
	/// @param lockerTargetAddress Address of Locker
	/// @param requestIdOfLocker Index of request between Locker's burn requests
	/// @param deadline of Locker for executing the request (in terms of Bitcoin blocks)
  	event CCBurn(
		address indexed userTargetAddress,
		bytes userScript,
		ScriptTypes scriptType,
		uint coreBTCAmount, 
		uint burntAmount,
		address lockerTargetAddress,
		uint requestIdOfLocker,
		uint indexed deadline
	);

	/// @notice Emits when a burn proof is provided
    /// @param lockerTargetAddress Address of Locker
    /// @param requestIdOfLocker Index of paid request of among Locker's requests
    /// @param bitcoinTxId The hash of tx that paid a burn request
	/// @param bitcoinTxOutputIndex The output index in tx
	event PaidCCBurn(
		address indexed lockerTargetAddress,
		uint requestIdOfLocker,
		bytes32 bitcoinTxId,
		uint bitcoinTxOutputIndex
	);

	/// @notice  Emits when a locker gets slashed for withdrawing BTC without proper reason
	/// @param _lockerTargetAddress	Locker's address on the target chain
	/// @param blockHeight	Block number of the malicious tx
	/// @param txId	Transaction ID of the malicious tx
	/// @param amount Slashed amount
	event LockerDispute(
        address _lockerTargetAddress,
		bytes lockerLockingScript,
    	uint blockHeight,
        bytes32 txId,
		uint amount
    );

	event BurnDispute(
		address indexed userTargetAddress,
		address indexed _lockerTargetAddress,
		bytes lockerLockingScript,
		uint requestIdOfLocker
	);

	/// @notice Emits when relay address is updated
    event NewRelay(
        address oldRelay, 
        address newRelay
    );

	/// @notice Emits when treasury address is updated
    event NewTreasury(
        address oldTreasury, 
        address newTreasury
    );

	/// @notice Emits when lockers address is updated
    event NewLockers(
        address oldLockers, 
        address newLockers
    );

	/// @notice Emits when CoreBTC address is updated
    event NewCoreBTC(
        address oldCoreBTC, 
        address newCoreBTC
    );

	/// @notice Emits when transfer deadline is updated
    event NewTransferDeadline(
        uint oldTransferDeadline, 
        uint newTransferDeadline
    );

	/// @notice Emits when percentage fee is updated
    event NewProtocolPercentageFee(
        uint oldProtocolPercentageFee, 
        uint newProtocolPercentageFee
    );

	/// @notice Emits when slasher percentage fee is updated
    event NewSlasherPercentageFee(
        uint oldSlasherPercentageFee, 
        uint newSlasherPercentageFee
    );

	/// @notice Emits when bitcoin fee is updated
    event NewBitcoinFee(
        uint oldBitcoinFee, 
        uint newBitcoinFee
    );

	/// @notice Emits when bitcoin fee oracle is updated
    event NewBitcoinFeeOracle(
        address oldBitcoinFeeOracle, 
        address newBitcoinFeeOracle
    );

	// Read-only functions

	function isTransferred(address _lockerTargetAddress, uint _index) external view returns (bool);

	// State-changing functions

	function setStartingBlockNumber(uint _startingBlockNumber) external;

	function setRelay(address _relay) external;

	function setLockers(address _lockers) external;

	function setCoreBTC(address _coreBTC) external;

	function setTreasury(address _treasury) external;

	function setTransferDeadline(uint _transferDeadline) external;

	function setProtocolPercentageFee(uint _protocolPercentageFee) external;

	function setSlasherPercentageReward(uint _slasherPercentageReward) external;

	function setBitcoinFee(uint _bitcoinFee) external;

	function setBitcoinFeeOracle(address _bitcoinFeeOracle) external;

	function ccBurn(
		uint _amount, 
		bytes calldata _userScript,
		ScriptTypes _scriptType,
		bytes calldata _lockerLockingScript
	) external returns (uint);

	function burnProof(
		bytes calldata _tx,
		uint _blockNumber,
		bytes memory _intermediateNodes,
		uint _index,
		bytes memory _lockerLockingScript,
        uint[] memory _burnReqIndexes,
        uint[] memory _voutIndexes
	) external returns (bool);

	function disputeBurn(
		bytes calldata _lockerLockingScript,
		uint[] memory _indices
	) external;

    function disputeLocker(
        bytes memory _lockerLockingScript,
		bytes calldata _inputTx,
		bytes calldata _outputTx,
        bytes memory _inputIntermediateNodes,
        uint[] memory _indexesAndBlockNumbers 
		// ^ [inputIndex, inputTxIndex, outputTxIndex, inputTxBlockNumber, outputTxBlockNumber]
    ) external;
}
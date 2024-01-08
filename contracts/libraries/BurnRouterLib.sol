// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../common/relay/interfaces/IBitcoinRelay.sol";
import "../common/libraries/BitcoinHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../routers/BurnRouterStorage.sol";

library BurnRouterLib {

    /// @notice Checks if all outputs of the transaction used to pay a cc burn request
    /// @dev  One output might return the remaining value to the locker
    /// @param _paidOutputCounter  Number of the tx outputs that pay a cc burn request
    /// @param _voutView Outputs view of a transaction
    /// @param _lockerLockingScript Locking script of locker
    /// @param _txId Transaction id
    function updateIsUsedAsBurnProof(
        mapping(bytes32 => bool) storage _isUsedAsBurnProof,
        uint _paidOutputCounter,
        bytes29 _voutView,
        bytes memory _lockerLockingScript,
        bytes32 _txId
    ) internal {
        uint parsedAmount = BitcoinHelper.parseValueHavingLockingScript(_voutView, _lockerLockingScript);
        uint numberOfOutputs = BitcoinHelper.numberOfOutputs(_voutView);

        if (parsedAmount != 0 && _paidOutputCounter + 1 == numberOfOutputs) {
            // One output sends the remaining value to locker
            _isUsedAsBurnProof[_txId] = true;
        } else if (_paidOutputCounter == numberOfOutputs) {
            // All output pays cc burn requests
            _isUsedAsBurnProof[_txId] = true;
        }
    }

    function disputeBurnHelper(
        mapping(address => BurnRouterStorage.burnRequest[]) storage burnRequests,
        address _lockerTargetAddress,
        uint _index,
        uint _transferDeadline,
        uint _lastSubmittedHeight,
        uint _startingBlockNumber
    ) external {
        // Checks that locker has not provided burn proof
        require(
            !burnRequests[_lockerTargetAddress][_index].isTransferred,
            "BurnRouterLogic: already paid"
        );

        // Checks that payback deadline has passed
        require(
            burnRequests[_lockerTargetAddress][_index].deadline < _lastSubmittedHeight,
            "BurnRouterLogic: deadline not passed"
        );

        require(
            burnRequests[_lockerTargetAddress][_index].deadline > _startingBlockNumber + _transferDeadline,
            "BurnRouterLogic: old request"
        );

        // Sets "isTransferred = true" to prevent slashing the locker again
        burnRequests[_lockerTargetAddress][_index].isTransferred = true;
    }

    function disputeLockerHelper(
        mapping(bytes32 => bool) storage _isUsedAsBurnProof,
        uint _transferDeadline,
        address _relay,
        uint _startingBlockNumber,
        bytes32 _inputTxId,
        bytes memory _inputIntermediateNodes,
        uint[] memory _indexesAndBlockNumbers // [inputIndex, inputTxIndex, inputTxBlockNumber]
    ) external {

        // Checks input array sizes
        require(
            _indexesAndBlockNumbers.length == 3,
            "BurnRouterLogic: wrong inputs"
        );

        require(_indexesAndBlockNumbers[2] >= _startingBlockNumber, "BurnRouterLogic: old request");

        require(
            isConfirmed(
                _relay,
                _inputTxId,
                _indexesAndBlockNumbers[2], // Block number
                _inputIntermediateNodes,
                _indexesAndBlockNumbers[1] // Index of input tx in the block
            ),
            "BurnRouterLogic: not finalized"
        );

        /*
            Checks that input tx has not been provided as a burn proof
            note: if a locker executes a cc burn request but doesn't provide burn proof before deadline,
            we consider the transaction as a malicious tx
        */
        require(
            !_isUsedAsBurnProof[_inputTxId],
            "BurnRouterLogic: already used"
        );

        // prevents multiple slashing of locker
        _isUsedAsBurnProof[_inputTxId] = true;

        // Checks that deadline for using the tx as burn proof has passed
        require(
            lastSubmittedHeight(_relay) > _transferDeadline + _indexesAndBlockNumbers[2],
            "BurnRouterLogic: deadline not passed"
        );

    }

    /// @notice Checks inclusion of the transaction in the specified block
    /// @dev Calls the relay contract to check Merkle inclusion proof
    /// @param _relay Address of Relay contract
    /// @param _txId of the transaction
    /// @param _blockNumber Height of the block containing the transaction
    /// @param _intermediateNodes Merkle inclusion proof for the transaction
    /// @param _index Index of transaction in the block
    /// @return True if the transaction was included in the block
    function isConfirmed(
        address _relay,
        bytes32 _txId,
        uint256 _blockNumber,
        bytes memory _intermediateNodes,
        uint _index
    ) public view returns (bool) {

        // Calls relay contract
        bytes memory data = Address.functionStaticCall(
            _relay,
            abi.encodeWithSignature(
                "checkTxProof(bytes32,uint256,bytes,uint256)",
                _txId,
                _blockNumber,
                _intermediateNodes,
                _index
            )
        );

        return abi.decode(data, (bool));
    }

    function lastSubmittedHeight(address _relay) public view returns (uint) {
        return IBitcoinRelay(_relay).lastSubmittedHeight();
    }

    function finalizationParameter(address _relay) external view returns (uint) {
        return IBitcoinRelay(_relay).finalizationParameter();
    }
}
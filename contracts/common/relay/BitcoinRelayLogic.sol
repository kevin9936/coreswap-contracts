// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IBitcoinRelay.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BitcoinRelayLogic is IBitcoinRelay, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {

    // Public variables
    uint constant MAX_FINALIZATION_PARAMETER = 432; // roughly 3 days

    uint public override initialHeight;
    uint public override finalizationParameter;
    address public override btcLightClient;

    constructor() {
        _disableInitializers();
    }

    /// @notice Gives a starting point for the relay
    /// @param  _height The starting height
    /// @param  _btcLightClient BTC light cient address
    function initialize(
        uint256 _height,
        address _btcLightClient
    ) public initializer {

        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        PausableUpgradeable.__Pausable_init();

        // Relay parameters
        btcLightClient = _btcLightClient;

        _setFinalizationParameter(3);
        initialHeight = _height;
    }

    function renounceOwnership() public virtual override onlyOwner {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Pauses the Relay
    /// @dev Only functions with whenPaused modifier can be called
    function pauseRelay() external override onlyOwner {
        _pause();
    }

    /// @notice Unpauses the relay
    /// @dev Only functions with whenNotPaused modifier can be called
    function unpauseRelay() external override onlyOwner {
        _unpause();
    }

    function lastSubmittedHeight() external override view returns(uint) {
        return _lastSubmittedHeight();
    }


    /// @notice External setter for finalizationParameter
    /// @dev Bigger finalization parameter increases security but also increases the delay
    /// @param _finalizationParameter The finalization parameter of Bitcoin
    function setFinalizationParameter(uint _finalizationParameter) external override onlyOwner {
        _setFinalizationParameter(_finalizationParameter);
    }

    /// @notice Checks if a tx is included and finalized on Bitcoin
    /// @dev Checks if the block is finalized, and Merkle proof is valid
    /// @param _txid Desired tx Id in LE form
    /// @param _blockHeight of the desired tx
    /// @param _intermediateNodes Part of the Merkle tree from the tx to the root in LE form (called Merkle proof)
    /// @param _index of the tx in Merkle tree
    /// @return True if the provided tx is confirmed on Bitcoin
    function checkTxProof(
        bytes32 _txid, // In LE form
        uint _blockHeight,
        bytes calldata _intermediateNodes, // In LE form
        uint _index
    ) external view whenNotPaused override returns (bool) {
        require(_txid != bytes32(0), "BitcoinRelay: txid should be non-zero");

        // Revert if the block is not finalized
        require(
            _blockHeight + finalizationParameter < _lastSubmittedHeight() + 1,
            "BitcoinRelay: block is not finalized on the relay"
        );

        // Block header exists on the relay
        require(
            _blockHeight >= initialHeight,
            "BitcoinRelay: the requested height is not submitted on the relay (too old)"
        );

        // Check inclusion of the transaction
        bytes32[] memory nodes = _splitNodes(_intermediateNodes);
        require(
            nodes.length > 0,
            "BitcoinRelay: intermediateNodes empty"
        );

        bytes memory data = Address.functionStaticCall(
            btcLightClient,
            abi.encodeWithSignature(
                "checkTxProof(bytes32,uint32,uint32,bytes32[],uint256)",
                _txid,
                _blockHeight,
                finalizationParameter,
                nodes,
                _index
            )
        );

       return abi.decode(data, (bool));
    }

    /// @notice Internal setter for finalizationParameter
    function _setFinalizationParameter(uint _finalizationParameter) private {
        emit NewFinalizationParameter(finalizationParameter, _finalizationParameter);
        require(
            _finalizationParameter > 0 && _finalizationParameter <= MAX_FINALIZATION_PARAMETER,
            "BitcoinRelay: invalid finalization param"
        );

        finalizationParameter = _finalizationParameter;
    }

    function _lastSubmittedHeight() private view returns(uint) {
        bytes memory data = Address.functionStaticCall(
            btcLightClient,
            abi.encodeWithSignature(
                "getChainTipHeight()"
            )
        );

        return uint(abi.decode(data, (uint32)));

    }

    function _splitNodes(
        bytes memory _intermediateNodes
    ) private pure returns (bytes32[] memory) {
        require(
            _intermediateNodes.length > 0 && _intermediateNodes.length % 32 == 0,
            "BitcoinRelay: intermediateNode invalid length"
        );

        uint256 len = _intermediateNodes.length / 32;
        bytes32[] memory nodeArr = new bytes32[](len);

        for (uint256 i = 0; i < len; i++) {
            bytes32 node;
            assembly {
                node := mload(add(_intermediateNodes, add(32, mul(i, 32))))
            }
            nodeArr[i] = node;
        }

        return nodeArr;
    }
}

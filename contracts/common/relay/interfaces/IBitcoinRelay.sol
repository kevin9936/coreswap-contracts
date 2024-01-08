// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IBitcoinRelay {
    // Events

    event NewFinalizationParameter (
        uint oldFinalizationParameter,
        uint newFinalizationParameter
    );

    // Read-only functions

    function initialHeight() external view returns(uint);

    function lastSubmittedHeight() external view returns(uint);

    function finalizationParameter() external view returns(uint);

    function btcLightClient() external view returns(address);

    // State-changing functions

    function pauseRelay() external;

    function unpauseRelay() external;

    function setFinalizationParameter(uint _finalizationParameter) external;

    function checkTxProof(
        bytes32 txid,
        uint blockHeight,
        bytes calldata intermediateNodes,
        uint index
    ) external view returns (bool);
}
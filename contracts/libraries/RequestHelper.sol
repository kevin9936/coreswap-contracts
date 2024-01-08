// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// A library for parsing cc transfer and cc exchange requests
library RequestHelper {

    /// @notice                     Returns version of the request
    /// @dev                        Determines the version that request belongs to
    /// @param _arbitraryData       Data written in Bitcoin tx
    /// @return parsedValue         The parsed value of version
    function parseVersion(bytes memory _arbitraryData) internal pure returns (uint8 parsedValue) {
        bytes memory slicedBytes = sliceBytes(_arbitraryData, 0, 0);
        assembly {
            parsedValue := mload(add(slicedBytes, 1))
        }
    }

    /// @notice                     Returns chain id of the request
    /// @dev                        Determines the chain that request belongs to
    /// @param _arbitraryData       Data written in Bitcoin tx
    /// @return parsedValue         The parsed value of chain id
    function parseChainId(bytes memory _arbitraryData) internal pure returns (uint16 parsedValue) {
        bytes memory slicedBytes = sliceBytes(_arbitraryData, 1, 2);
        assembly {
            parsedValue := mload(add(slicedBytes, 2))
        }
    }

    /// @notice                     Returns app id of the request
    /// @dev                        Determines the app that request belongs to (e.g. cross-chain transfer app id is 0)
    /// @param _arbitraryData       Data written in Bitcoin tx
    /// @return parsedValue         The parsed value of app id
    function parseAppId(bytes memory _arbitraryData) internal pure returns (uint16 parsedValue) {
        bytes memory slicedBytes = sliceBytes(_arbitraryData, 3, 4);
        assembly {
            parsedValue := mload(add(slicedBytes, 2))
        }
    }

    /// @notice                     Returns recipient address
    /// @dev                        Minted CoreBTC or exchanged tokens will be sent to this address
    /// @param _arbitraryData       Data written in Bitcoin tx
    /// @return parsedValue         The parsed value of recipient address
    function parseRecipientAddress(bytes memory _arbitraryData) internal pure returns (address parsedValue) {
        bytes memory slicedBytes = sliceBytes(_arbitraryData, 5, 24);
        assembly {
            parsedValue := mload(add(slicedBytes, 20))
        }
    }

    /// @notice                     Returns percentage fee (from total minted CoreBTC)
    /// @dev                        This fee goes to Porter who submitted the request
    /// @param _arbitraryData       Data written in Bitcoin tx
    /// @return parsedValue         The parsed value of percentage fee
    function parsePercentageFee(bytes memory _arbitraryData) internal pure returns (uint16 parsedValue) {
        bytes memory slicedBytes = sliceBytes(_arbitraryData, 25, 26);
        assembly {
            parsedValue := mload(add(slicedBytes, 2))
        }
    }

    /// @notice                 Returns a sliced bytes
    /// @param _data            Data that is sliced
    /// @param _start           Start index of slicing
    /// @param _end             End index of slicing
    /// @return _result         The result of slicing
    function sliceBytes(
        bytes memory _data,
        uint _start,
        uint _end
    ) internal pure returns (bytes memory _result) {
        bytes1 temp;
        for (uint i = _start; i < _end + 1; i++) {
            temp = _data[i];
            _result = abi.encodePacked(_result, temp);
        }
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IPriceProxy {
    // Structs
    struct Price {
        // Price
        uint price;
        // Price exponent
        uint32 decimals;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }

    // Events
    event NewOracle(address oldOracle, address newOracle);

    event AddFeedId(string indexed token, bytes32 oldFeedId, bytes32 newFeedId);

    // State-changing functions
    function setOracle(address _oracle) external;

    // Read-only functions
    function oracle() external view returns(address);

    function getFeedId(string memory _pairName) external view returns (bytes32 feedId);

    function getEmaPriceByPairName(
        string memory _pairName
    ) external view returns(Price memory price, string memory err);

    function getEmaPricesByPairNames(
        string memory _pairName0,
        string memory _pairName1
    ) external view returns(Price memory price0, Price memory price1, string memory err);
}
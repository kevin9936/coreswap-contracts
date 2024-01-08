// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IPriceOracle {

    // Events
    event NewAcceptableDelay(uint oldAcceptableDelay, uint newAcceptableDelay);

    event AddPriceProxy(address indexed priceProxy);

    event RemovePriceProxy(address indexed priceProxy);

    event NewBestPriceProxy(address oldBestPriceProxy, address newBestPriceProxy);

    event NewTokenPricePair(address token, string oldPricePair, string newPricePair);

    // Read-only functions

    function acceptableDelay() external view returns (uint);

    function equivalentOutputAmount(
        uint _inputAmount,
        uint _inputDecimals,
        uint _outputDecimals,
        address _inputToken,
        address _outputToken
    ) external view returns (uint);

    function pricePairMap(address _token) external view returns(string memory);

    function priceProxyIdxMap(address _priceOracle) external view returns(uint);

    function getPriceProxyListLength() external view returns (uint);

    function priceProxyList(uint idx) external view returns(address);

    function bestPriceProxy() external view returns(address);

    // State-changing functions

    function addPriceProxy(address _priceProxy) external;

    function removePriceProxy(address _priceProxy) external;

    function setAcceptableDelay(uint _acceptableDelay) external;

    function selectBestPriceProxy(address _priceProxy) external;

    function addTokenPricePair(
        address _token,
        string memory _pairName
    ) external;

    function pauseOracle() external;

    function unPauseOracle() external;
}
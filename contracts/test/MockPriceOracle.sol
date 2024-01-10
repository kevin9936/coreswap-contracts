// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../contracts/oracle/PriceOracle.sol";

contract MockPriceOracle is PriceOracle {
    struct TokenPrice {
        uint256 price;
        uint32 decimals;
        uint256 publishTime;
    }

    mapping (string => TokenPrice) tokenPriceMap;

    constructor(uint256 _acceptableDelay) PriceOracle(_acceptableDelay) {}

    /// @param _pairName    e.g. BTC/USDT CORE/USDT 
    function addPriceOfPricePair(
        string memory _pairName,
        uint256 _price,
        uint32 _decimals,
        uint256 _diffSeconds
    ) external notEmptyPairName(_pairName) onlyOwner {
        tokenPriceMap[_pairName] = TokenPrice(_price,_decimals,block.timestamp-_diffSeconds);
    }
}
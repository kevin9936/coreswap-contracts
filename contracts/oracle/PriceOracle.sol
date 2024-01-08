// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IPriceOracle.sol";
import "./interfaces/IPriceProxy.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract PriceOracle is IPriceOracle, Ownable2Step, Pausable {

    using SafeCast for uint;

    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "PriceOracle: zero address");
        _;
    }

    modifier notEmptyPairName(string memory _pairName) {
        require( bytes(_pairName).length > 0, "PriceOracle: empty pair name" );
        _;
    }

    modifier notSameString(string memory str1, string memory str2) {
        require(!Strings.equal(str1, str2), "PriceOracle: two strings are the same");
        _;
    }

    // Public variables
    mapping (address => string) public override pricePairMap;
    mapping (address => uint) public override priceProxyIdxMap;
    address[] public override priceProxyList;
    uint public override acceptableDelay;
    address public override bestPriceProxy;

    /// @notice                         This contract is used to get relative price of two assets from available oracles
    /// @param _acceptableDelay         Maximum acceptable delay for data given from Oracles
    constructor(uint _acceptableDelay) {
        _setAcceptableDelay(_acceptableDelay);
    }

    function renounceOwnership() public virtual override onlyOwner {}

    /// @notice                 Getter for the length of oracle list
    function getPriceProxyListLength() external view override returns (uint) {
        return priceProxyList.length;
    }

    /// @notice                     Adds a price proxy
    /// @dev                        Only owner can call this
    ///                             The price proxy is an encapsulation of third-party oracle price retrieval methods
    ///                             You can obtain the prices of inputToken/outputToken from price proxy
    /// @param _priceProxy          The address of the price proxy
    function addPriceProxy(
        address _priceProxy
    ) external override nonZeroAddress(_priceProxy) onlyOwner {
        uint idx = priceProxyIdxMap[_priceProxy];
        require( idx == 0, "PriceOracle: price proxy already exists" );

        priceProxyList.push( _priceProxy );
        priceProxyIdxMap[_priceProxy] = priceProxyList.length;

        emit AddPriceProxy(_priceProxy);
    }

    /// @notice                     Removes a price proxy
    /// @dev                        Only owner can call this
    /// @param _priceProxy          The address of the price proxy
    function removePriceProxy(
        address _priceProxy
    ) external override nonZeroAddress(_priceProxy) onlyOwner {
        uint idx = priceProxyIdxMap[_priceProxy];
        require(idx != 0, "PriceOracle: price proxy does not exists");

        require(_priceProxy != bestPriceProxy, "PriceOracle: can not remove best price proxy");

        priceProxyList[idx - 1] = priceProxyList[priceProxyList.length-1];
        priceProxyList.pop();

        delete priceProxyIdxMap[_priceProxy];
        emit RemovePriceProxy(_priceProxy);
    }

    /// @notice                         Finds amount of output token that has equal value
    ///                                 as the input amount of the input token from oracle
    /// @param _inputAmount             Amount of the input token
    /// @param _inputDecimals           Number of input token decimals
    /// @param _outputDecimals          Number of output token decimals
    /// @param _inputToken              Address of the input token
    /// @param _outputToken             Address of output token
    /// @return _outputAmount           Amount of the output token
    function equivalentOutputAmount(
        uint _inputAmount,
        uint _inputDecimals,
        uint _outputDecimals,
        address _inputToken,
        address _outputToken
    ) external view nonZeroAddress(_inputToken) nonZeroAddress(_outputToken) override returns (uint _outputAmount) {
        bool result;
        (result, _outputAmount, /*timestamp*/) = _equivalentOutputAmountFromOracle(
            _inputAmount,
            _inputDecimals,
            _outputDecimals,
            _inputToken,
            _outputToken
        );
        require(result == true, "PriceOracle: oracle does not exist or price is not up to date");
    }

    /// @notice                     Selects a price proxy as the preferred one
    /// @dev                        Only owner can call this
    /// @param _priceProxy          The address of the price proxy
    function selectBestPriceProxy(
        address _priceProxy
    ) external override nonZeroAddress(_priceProxy) onlyOwner {
        uint idx = priceProxyIdxMap[_priceProxy];
        require(idx != 0, "PriceOracle: price proxy does not exists");

        require(_priceProxy != bestPriceProxy, "PriceOracle: price proxy is already best");

        emit NewBestPriceProxy(bestPriceProxy, _priceProxy);
        bestPriceProxy = _priceProxy;
    }

    /// @notice                     Adds mapping between token and price pair
    /// @dev                        Only owner can call this
    /// @param _token               The address of the token
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    function addTokenPricePair(
        address _token,
        string memory _pairName
    ) external override nonZeroAddress(_token) notEmptyPairName(_pairName) onlyOwner  {
        string memory oldPricePair = pricePairMap[_token];

        require(
            !Strings.equal(oldPricePair, _pairName),
            "PriceOracle: price pair already exists"
        );

        pricePairMap[_token] = _pairName;
        emit NewTokenPricePair(_token, oldPricePair, _pairName);
    }

    /// @notice                     Sets acceptable delay for oracle responses
    /// @dev                        If oracle data has not been updated for a while,
    ///                             we will consider the price as invalid
    /// @param _acceptableDelay     Maximum acceptable delay (in seconds)
    function setAcceptableDelay(uint _acceptableDelay) external override onlyOwner {
        _setAcceptableDelay(_acceptableDelay);
    }

    /// @notice                     Pause the oracle, so only the functions can be called which are whenPaused
    /// @dev                        Only owner can pause
    function pauseOracle() external override onlyOwner {
        _pause();
    }

    /// @notice                     Un-pause the oracle, so only the functions can be called which are whenNotPaused
    /// @dev                        Only owner can pause
    function unPauseOracle() external override onlyOwner {
        _unpause();
    }

    /// @notice                     Internal setter for acceptable delay for oracle responses
    /// @dev                        If oracle data has not been updated for a while,
    ///                             we will consider the price as invalid
    /// @param _acceptableDelay     Maximum acceptable delay (in seconds)
    function _setAcceptableDelay(uint _acceptableDelay) private {
        emit NewAcceptableDelay(acceptableDelay, _acceptableDelay);
        require(
            _acceptableDelay > 0,
            "PriceOracle: zero amount"
        );
        acceptableDelay = _acceptableDelay;
    }

    /// @notice                         Finds amount of output token that is equal as the input amount of the input token
    /// @dev                            The oracle is Pyth and Switchboard
    /// @param _inputAmount             Amount of the input token
    /// @param _inputDecimals           Number of input token decimals
    /// @param _outputDecimals          Number of output token decimals
    /// @param _inputToken              Address of the input token
    /// @param _outputToken             Address of output token
    /// @return _result                 True if getting amount was successful
    /// @return _outputAmount           Amount of the output token
    /// @return _timestamp              Timestamp of the result
    function _equivalentOutputAmountFromOracle(
        uint _inputAmount,
        uint _inputDecimals,
        uint _outputDecimals,
        address _inputToken,
        address _outputToken
    ) private view returns (bool, uint _outputAmount, uint _timestamp) {
        if (_inputToken == _outputToken) {
            if (_inputDecimals == _outputDecimals) {
                return (true, _inputAmount, block.timestamp);
            } else {
                return (true, _inputAmount * 10 ** (_outputDecimals+1) / 10 ** (_inputDecimals + 1), block.timestamp);
            }
        }

        (uint price0, uint32 decimals0, uint publishTime0, uint price1, uint32 decimals1, uint publishTime1) =
            _getEmaPricesFromOracle(_inputToken, _outputToken);

        // convert the above calculation to the below one to eliminate precision loss
        uint outputAmount = (uint(price0) * 10**(decimals1))*_inputAmount*(10**(_outputDecimals + 1));
        outputAmount = outputAmount/((10**(_inputDecimals + 1))*(uint(price1) * 10**(decimals0)));

        require(
            _abs(block.timestamp.toInt256() - publishTime0.toInt256()) <= acceptableDelay,
            string(
                abi.encodePacked(
                    "PriceOracle: price is expired",
                    ", token ",
                    Strings.toHexString(_inputToken),
                    ", publishTime ",
                    Strings.toHexString(publishTime0)
                )
            )
        );

        require(
            _abs(block.timestamp.toInt256() - publishTime1.toInt256()) <= acceptableDelay,
            string(
                abi.encodePacked(
                    "PriceOracle: price is expired",
                    ", token ",
                    Strings.toHexString(_outputToken),
                    ", publishTime ",
                    Strings.toHexString(publishTime1)
                )
            )
        );

        // choose earlier publishTime
        return (true, outputAmount, Math.min(publishTime0, publishTime1));
    }

    /// @notice                     Get the EMA prices of two tokens from oracle by their addresses
    /// @param _token0              The address of the token0
    /// @param _token1              The address of the token1
    /// @return price0              The EMA price of the token0
    /// @return decimals0           Decimals of the price0
    /// @return publishTime0        Publish time of the price0
    /// @return price1              The EMA price of the token1
    /// @return decimals1           Decimals of the price1
    /// @return publishTime1        Publish time of the price1
    function _getEmaPricesFromOracle(
        address _token0,
        address _token1
    ) private nonZeroAddress(_token0) nonZeroAddress(_token1)
        view returns(uint price0, uint32 decimals0, uint publishTime0, uint price1, uint32 decimals1, uint publishTime1) {

        return _getEmaPricesByPairNamesFromOracle(pricePairMap[_token0], pricePairMap[_token1]);
    }

    /// @notice                     Get the EMA prices of two tokens from oracle by their pair names
    /// @param _pairName0           The first price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @param _pairName1           The second price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return price0              The EMA price of the first price pair
    /// @return decimals0           Decimals of the price0
    /// @return publishTime0        Publish time of the price0
    /// @return price1              The EMA price of the second price pair
    /// @return decimals1           Decimals of the price1
    /// @return publishTime1        Publish time of the price1
    function _getEmaPricesByPairNamesFromOracle(
        string memory _pairName0,
        string memory _pairName1
    ) internal notEmptyPairName(_pairName0) notEmptyPairName(_pairName1)
        view returns(uint price0, uint32 decimals0, uint publishTime0, uint price1, uint32 decimals1, uint publishTime1) {

        require(bestPriceProxy != address(0), "PriceOracle: best price proxy is empty");

        IPriceProxy.Price memory tokenPrice0;
        IPriceProxy.Price memory tokenPrice1;
        string memory err;

        // call best price proxy firstly
        (tokenPrice0, tokenPrice1, err) = IPriceProxy(bestPriceProxy).getEmaPricesByPairNames(_pairName0, _pairName1);

        if (tokenPrice0.price > 0 && tokenPrice1.price > 0) {
            return (tokenPrice0.price, tokenPrice0.decimals, tokenPrice0.publishTime,
                tokenPrice1.price, tokenPrice1.decimals, tokenPrice1.publishTime);
        }

        // call spare price proxy when the best one is not worked
        for (uint i = 0; i < priceProxyList.length; i++) {

            if (priceProxyList[i] != bestPriceProxy) {
                (tokenPrice0, tokenPrice1, err) = IPriceProxy(priceProxyList[i]).getEmaPricesByPairNames(_pairName0, _pairName1);

                if (tokenPrice0.price > 0 && tokenPrice1.price > 0) {
                    return (tokenPrice0.price, tokenPrice0.decimals, tokenPrice0.publishTime,
                        tokenPrice1.price, tokenPrice1.decimals, tokenPrice1.publishTime);
                }
            }
        }

        require(
            false,
            string(
                abi.encodePacked(
                    "PriceOracle: pairName0 ",
                    _pairName0,
                    ", pairName1 ",
                    _pairName1,
                    ",  ",
                    err
                )
            )
        );
    }

    /// @notice             Returns absolute value
    function _abs(int _value) private pure returns (uint) {
        return _value >= 0 ? uint(_value) : uint(-_value);
    }
}
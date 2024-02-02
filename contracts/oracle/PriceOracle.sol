// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IPriceOracle.sol";
import "./interfaces/IPriceProxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
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

    address public constant NATIVE_TOKEN = address(1);
    uint public constant EARN_EXCHANGE_RATE_DECIMALS = 6;

    // Public variables
    mapping (address => string) public override pricePairMap;
    mapping (address => uint) public override priceProxyIdxMap;
    address[] public override priceProxyList;
    uint public override acceptableDelay;
    address public override bestPriceProxy;

    address public override earnWrappedToken;
    address public override earnStrategy;

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

        if (idx < priceProxyList.length) {
            priceProxyList[idx - 1] = priceProxyList[priceProxyList.length - 1];
            priceProxyIdxMap[priceProxyList[idx - 1]] = idx;
        }

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

    function setEarnWrappedToken(address _earnWrappedToken) external override nonZeroAddress(_earnWrappedToken) onlyOwner {
        require(
            _earnWrappedToken != earnWrappedToken,
            "PriceOracle: earn wrapped token unchanged"
        );

        emit NewEarnWrappedToken(earnWrappedToken, _earnWrappedToken);
        earnWrappedToken = _earnWrappedToken;
    }

    function setEarnStrategy(address _earnStrategy) external override nonZeroAddress(_earnStrategy) onlyOwner {
        require(
            _earnStrategy != earnStrategy,
            "PriceOracle: earn strategy unchanged"
        );

        emit NewEarnStrategy(earnStrategy, _earnStrategy);
        earnStrategy = _earnStrategy;
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

        (IPriceProxy.Price memory price0, uint exchangeRate0, uint exchangeRateDecimals0,
            IPriceProxy.Price memory price1, uint exchangeRate1, uint exchangeRateDecimals1) = _getEmaPricesFromOracle(_inputToken, _outputToken);

        // convert the above calculation to the below one to eliminate precision loss
        uint outputAmount = (uint(price0.price * exchangeRate0) * 10**(price1.decimals + exchangeRateDecimals1))*_inputAmount*(10**(_outputDecimals + 1));
        outputAmount = outputAmount/((10**(_inputDecimals + 1))*(uint(price1.price * exchangeRate1) * 10**(price0.decimals + exchangeRateDecimals0)));

        require(
            _abs(block.timestamp.toInt256() - price0.publishTime.toInt256()) <= acceptableDelay,
            string(
                abi.encodePacked(
                    "PriceOracle: price is expired",
                    ", token ",
                    Strings.toHexString(_inputToken),
                    ", publishTime ",
                    Strings.toHexString(price0.publishTime),
                    ", diffTime ",
                    Strings.toHexString(_abs(block.timestamp.toInt256() - price0.publishTime.toInt256()))
                )
            )
        );

        require(
            _abs(block.timestamp.toInt256() - price1.publishTime.toInt256()) <= acceptableDelay,
            string(
                abi.encodePacked(
                    "PriceOracle: price is expired",
                    ", token ",
                    Strings.toHexString(_outputToken),
                    ", publishTime ",
                    Strings.toHexString(price1.publishTime),
                    ", diffTime ",
                    Strings.toHexString(_abs(block.timestamp.toInt256() - price1.publishTime.toInt256()))
                )
            )
        );

        // choose earlier publishTime
        return (true, outputAmount, Math.min(price0.publishTime, price1.publishTime));
    }

    /// @notice                     Get the EMA prices of two tokens from oracle by their addresses
    /// @param _token0              The address of the token0
    /// @param _token1              The address of the token1
    /// @return price0              The EMA price of the token0
    /// @return exchangeRate0       The exchange rate of the token0/anchorToken0 (e.g. stCore/Core)
    /// @return decimals0           Decimals of the exchangeRate0
    /// @return price1              The EMA price of the token1
    /// @return exchangeRate1       The exchange rate of the token1/anchorToken1 (e.g. stCore/Core)
    /// @return decimals1           Decimals of the exchangeRate1
    function _getEmaPricesFromOracle(
        address _token0,
        address _token1
    ) private nonZeroAddress(_token0) nonZeroAddress(_token1)
        view returns(IPriceProxy.Price memory price0, uint exchangeRate0, uint decimals0,
            IPriceProxy.Price memory price1, uint exchangeRate1, uint decimals1) {

        address anchorToken0;
        address anchorToken1;

        (exchangeRate0, decimals0, anchorToken0) = _getEarnExchangeRateAndAnchorToken(_token0);
        (exchangeRate1, decimals1, anchorToken1) = _getEarnExchangeRateAndAnchorToken(_token1);

        (price0, price1) = _getEmaPricesByPairNamesFromOracle(pricePairMap[anchorToken0], pricePairMap[anchorToken1]);
    }


    /// @notice                     Get the EMA prices of two tokens from oracle by their pair names
    /// @param _pairName0           The first price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @param _pairName1           The second price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return price0              The EMA price of the first price pair
    /// @return price1              The EMA price of the second price pair
    function _getEmaPricesByPairNamesFromOracle(
        string memory _pairName0,
        string memory _pairName1
    ) internal notEmptyPairName(_pairName0) notEmptyPairName(_pairName1)
        view returns(IPriceProxy.Price memory price0, IPriceProxy.Price memory price1) {

        require(bestPriceProxy != address(0), "PriceOracle: best price proxy is empty");

        string memory err;

        // call best price proxy firstly
        (price0, price1, err) = IPriceProxy(bestPriceProxy).getEmaPricesByPairNames(_pairName0, _pairName1);

        if (price0.price > 0 && price1.price > 0) {
            return (price0, price1);
        }

        // call spare price proxy when the best one is not worked
        for (uint i = 0; i < priceProxyList.length; i++) {

            if (priceProxyList[i] != bestPriceProxy) {
                (price0, price1, err) = IPriceProxy(priceProxyList[i]).getEmaPricesByPairNames(_pairName0, _pairName1);

                if (price0.price > 0 && price1.price > 0) {
                    return (price0, price1);
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

    function _getEarnExchangeRateAndAnchorToken(address _token) internal view returns (uint exchangeRate, uint decimals, address anchorToken) {
        if (_token != earnWrappedToken) {
            return (1, 0, _token);
        }

        bytes memory data = Address.functionStaticCall(
            earnStrategy,
            abi.encodeWithSignature(
                "getCurrentExchangeRate()"
            )
        );

        exchangeRate = abi.decode(data, (uint));
        decimals = EARN_EXCHANGE_RATE_DECIMALS;
        anchorToken = NATIVE_TOKEN;

        require(
            exchangeRate >= 10**decimals,
            string(
                abi.encodePacked(
                    "PriceOracle: token ",
                    Strings.toHexString(_token),
                    ", earn rate ",
                    Strings.toHexString(exchangeRate),
                    ", earn decimals ",
                    Strings.toHexString(decimals)
                )
            )
        );
    }

    /// @notice             Returns absolute value
    function _abs(int _value) private pure returns (uint) {
        return _value >= 0 ? uint(_value) : uint(-_value);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity  0.8.4;

import "./AbstractPriceProxy.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract PythPriceProxy is AbstractPriceProxy {
    using SafeCast for int256;
    using SafeCast for uint;

    mapping (string => bytes32) public feedIdMap;

    constructor(address _oracle) AbstractPriceProxy(_oracle) {
    }

    /// @notice                     Adds mapping between price pair name and feed id
    /// @dev                        The feed id is defined by the third-party oracle
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @param _feedId              The feed id of the token price
    function addFeedId(
        string memory _pairName,
        bytes32 _feedId
    ) external nonEmptyPairName(_pairName) nonZeroFeedId(_feedId) onlyOwner  {
        bytes32 oldFeedId = feedIdMap[_pairName];
        require( oldFeedId != _feedId, "Pyth: feedId already exists" );

        feedIdMap[_pairName] = _feedId;
        emit AddFeedId(_pairName, oldFeedId, _feedId);
    }

    /// @notice                     Gets the feed id of the token price by price pair name
    /// @dev                        The feed id is defined by the third-party oracle
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return feedId              The feed id of the token price
    function getFeedId(
        string memory _pairName
    ) external override view returns (bytes32 feedId) {
        return feedIdMap[_pairName];
    }

    /// @notice                     Gets the EMA price of the token by pair name
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return price               The EMA price of the price pair
    /// @return err                 Error message
    function _getEmaPriceByPairName(
        string memory _pairName
    ) internal nonEmptyPairName(_pairName) view override returns(Price memory price, string memory err){
        return _getEmaPriceByFeedId(feedIdMap[_pairName]);
    }

    /// @notice                     Gets the EMA price of the token by feed id
    /// @param _feedId              The feed id of the token price
    ///                             Defined by the third-party oracle
    /// @return price               The EMA price of the price pair
    /// @return err                 Error message
    function _getEmaPriceByFeedId(
        bytes32 _feedId
    ) private nonZeroFeedId(_feedId) view returns(Price memory price, string memory err) {

        try IPyth(oracle).getEmaPrice(_feedId) returns(PythStructs.Price memory priceData) {
            if (priceData.expo > 0) {
                return (price, "Pyth: unsupported feedId");
            }

            price.price = int256(priceData.price).toUint256();
            price.decimals = int256(-priceData.expo).toUint256().toUint32();
            price.publishTime = priceData.publishTime;

        } catch Error(string memory _err) {
            err = _err;
        } catch(bytes memory _err) {
            err = bytesToHex(_err);
        }
    }

}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./AbstractPriceProxy.sol";
import "../interfaces/ISwitchboardPush.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SwitchboardPriceProxy is AbstractPriceProxy {
    using SafeCast for int256;

    // Constants
    uint32 public constant SWITCHBOARD_VALUE_DECIMALS = 18;
    string public constant USDT_PRICE_PAIR_NAME = "USDT/USDT";

    constructor(address _oracle) AbstractPriceProxy(_oracle) {
    }

    /// @notice                     Gets the feed id of the token price by price pair name
    /// @dev                        The feed id is defined by the third-party oracle
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return feedId              The feed id of the token price
    function getFeedId(
        string memory _pairName
    ) external override pure returns(bytes32 feedId) {
        return _getFeedId(_pairName);
    }

    /// @notice                     Gets the EMA price of the token by pair name
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return price               The EMA price of the price pair
    /// @return err                 Error message
    function _getEmaPriceByPairName(
        string memory _pairName
    ) internal view override returns(Price memory price, string memory err) {
        if (Strings.equal(_pairName, USDT_PRICE_PAIR_NAME)) {
            price.price = 1;
            price.publishTime = block.timestamp;
            return (price, err);
        }

        // use latest price
        return _getLatestPriceByFeedId(_getFeedId(_pairName));
    }

    /// @notice                     Gets the latest price of the token by feed id
    /// @param _feedId              The feed id of the token price
    ///                             Defined by the third-party oracle
    /// @return price               The price of the price pair
    /// @return err                 Error message
    function _getLatestPriceByFeedId(
        bytes32 _feedId
    ) private nonZeroFeedId(_feedId) view returns(Price memory price, string memory err) {

        try ISwitchboardPush(oracle).feeds(_feedId) returns (ISwitchboardPush.Feed memory feed) {
            ISwitchboardPush.Result memory result = feed.latestResult;

            price.price = result.value.toUint256();
            price.decimals = SWITCHBOARD_VALUE_DECIMALS;
            price.publishTime = result.updatedAt;

        } catch Error(string memory _err) {
            err = _formatStringErr(_err);
        } catch(bytes memory _err) {
            err = _formatBytesErr(_err);
        }
    }

    /// @notice                     Gets the feed id of the token price by price pair name
    /// @dev                        The calculation rules of the feed id is defined by the third-party oracle
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return feedId              The feed id of the token price
    function _getFeedId(
        string memory _pairName
    ) private nonEmptyPairName(_pairName) pure returns (bytes32 feedId)  {
        assembly {
            feedId := mload(add(_pairName, 32))
        }
    }
}
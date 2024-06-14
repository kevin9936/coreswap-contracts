// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IPriceProxy.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

abstract contract AbstractPriceProxy is IPriceProxy, Ownable2Step {
    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "PriceProxy: zero address");
        _;
    }

    modifier nonZeroFeedId(bytes32 _feedId) {
        require(_feedId != bytes32(0), "PriceProxy: zero feedId");
        _;
    }

    modifier nonEmptyPairName(string memory _pairName) {
        require(bytes(_pairName).length > 0, "PriceProxy: empty pair name");
        _;
    }

    address public override oracle;

    constructor(address _oracle) {
        _setOracle(_oracle);
    }

    function renounceOwnership() public virtual override onlyOwner {}

    /// @notice                     Sets oracle address
    /// @dev                        Only owner can call this
    /// @param _oracle              The address of the third-party oracle contract (e.g. Pyth or Switchboard)
    function setOracle(
        address _oracle
    ) external override onlyOwner {
        _setOracle(_oracle);
    }

    /// @notice                     Get the EMA price of the tokens by pair name
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return price               The EMA price of the price pair
    /// @return err                 Error message
    function getEmaPriceByPairName(
        string memory _pairName
    ) external override view returns(Price memory price, string memory err) {
        return _getEmaPriceByPairName(_pairName);
    }

    /// @notice                     Get the EMA prices of two tokens by their pair names
    /// @param _pairName0           The first price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @param _pairName1           The second price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return price0              The EMA price of the first price pair
    /// @return price1              The EMA price of the second price pair
    /// @return err                 Error message
    function getEmaPricesByPairNames(
        string memory _pairName0,
        string memory _pairName1
    ) external override view returns(Price memory price0, Price memory price1, string memory err) {
        (price0, err) = _getEmaPriceByPairName(_pairName0);

        if (price0.price > 0) {
            (price1, err) = _getEmaPriceByPairName(_pairName1);
        }
    }


    /// @notice                     Sets oracle address
    /// @param _oracle              The address of the third-party oracle contract (e.g. Pyth or Switchboard)
    function _setOracle(
        address _oracle
    ) internal nonZeroAddress(_oracle) {
        require(oracle != _oracle, "PriceProxy: oracle already exists");
        require(_isOracleDeployed(_oracle), "PriceProxy: oracle contract not deployed");

        emit NewOracle(oracle, _oracle);

        oracle = _oracle;
    }

    /// @notice                     Gets the EMA price of the token by pair name
    /// @dev                        To be implemented by derived classes
    /// @param _pairName            The price pair name (e.g. CORE/USDT  BTC/USDT)
    /// @return price               The EMA price of the price pair
    /// @return err                 Error message
    function _getEmaPriceByPairName(
        string memory _pairName
    ) internal view virtual returns(Price memory price, string memory err);

    /// @notice                     Check whether the oracle contract has been deployed
    /// @param _oracle              The address of the third-party oracle contract (e.g. Pyth or Switchboard)
    /// @return                     Returns true if the oracle contract has been deployed
    function _isOracleDeployed(
        address _oracle
    ) private view returns(bool) {
        uint size;
        assembly{
            size := extcodesize(_oracle)
        }
        return size > 0;
    }

    /// @notice                     Converts a `bytes` to its ASCII `string` hexadecimal representation.
    function bytesToHex(
        bytes memory data
    ) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 * data.length + 2);

        str[0] = '0';
        str[1] = 'x';

        for (uint i = 0; i < data.length; i++) {
            str[2 * i + 2] = alphabet[uint8(data[i] >> 4)];
            str[2 * i + 3] = alphabet[uint8(data[i] & 0x0f)];
        }

        return string(str);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./CcTransferRouterStorage.sol";
import "./interfaces/ICcTransferRouter.sol";
import "../libraries/RequestHelper.sol";
import "../lockers/interfaces/ILockers.sol";
import "../erc20/interfaces/ICoreBTC.sol";
import "../common/libraries/BitcoinHelper.sol";
import "../common/relay/interfaces/IBitcoinRelay.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CcTransferRouterLogic is ICcTransferRouter, CcTransferRouterStorage,
    Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {

    using BitcoinHelper for bytes;

    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "CCTransferRouter: address is zero");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice                             Gives default params to initiate cc transfer router
    /// @param _startingBlockNumber         Requests that are included in a block older than _startingBlockNumber cannot be executed
    /// @param _protocolPercentageFee       Percentage amount of protocol fee (min: %0.01)
    /// @param _version                     Version of op return payload
    /// @param _chainId                     Id of the underlying chain
    /// @param _appId                       Id of ccTransfer dApp
    /// @param _relay                       The Relay address to validate data from source chain
    /// @param _lockers                     Lockers' contract address
    /// @param _coreBTC                     CoreDAO BTC ERC20 token address
    /// @param _treasury                    Address of treasury that collects protocol fees
    function initialize(
        uint _startingBlockNumber,
        uint _protocolPercentageFee,
        uint _version,
        uint _chainId,
        uint _appId,
        address _relay,
        address _lockers,
        address _coreBTC,
        address _treasury
    ) public initializer {
        Ownable2StepUpgradeable.__Ownable2Step_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        UUPSUpgradeable.__UUPSUpgradeable_init();

        version = _version;
        chainId = _chainId;
        appId = _appId;
        _setStartingBlockNumber(_startingBlockNumber);
        _setProtocolPercentageFee(_protocolPercentageFee);
        _setRelay(_relay);
        _setLockers(_lockers);
        _setCoreBTC(_coreBTC);
        _setTreasury(_treasury);
    }

    function renounceOwnership() public virtual override onlyOwner {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Setter for starting block number
    function setStartingBlockNumber(uint _startingBlockNumber) external override onlyOwner {
        _setStartingBlockNumber(_startingBlockNumber);
    }

    /// @notice                             Setter for protocol percentage fee
    /// @dev                                Only owner can call this
    /// @param _protocolPercentageFee       Percentage amount of protocol fee
    function setProtocolPercentageFee(uint _protocolPercentageFee) external override onlyOwner {
        _setProtocolPercentageFee(_protocolPercentageFee);
    }

    /// @notice                             Setter for relay
    /// @dev                                Only owner can call this
    /// @param _relay                       Address of the relay contract
    function setRelay(address _relay) external override nonZeroAddress(_relay) onlyOwner {
        _setRelay(_relay);
    }

    /// @notice                             Setter for lockers
    /// @dev                                Only owner can call this
    /// @param _lockers                     Address of the lockers contract
    function setLockers(address _lockers) external override nonZeroAddress(_lockers) onlyOwner {
        _setLockers(_lockers);
    }

    /// @notice                             Setter for instant router
    /// @dev                                Only owner can call this
    /// @param _instantRouter               Address of the instant router contract
    function setInstantRouter(address _instantRouter) external override nonZeroAddress(_instantRouter) onlyOwner {
        _setInstantRouter(_instantRouter);
    }

    /// @notice                             Setter for coreBTC
    /// @dev                                Only owner can call this
    /// @param _coreBTC                     CoreDAO BTC ERC20 token address
    function setCoreBTC(address _coreBTC) external override nonZeroAddress(_coreBTC) onlyOwner {
        _setCoreBTC(_coreBTC);
    }

    /// @notice                             Setter for treasury
    /// @dev                                Only owner can call this
    /// @param _treasury                    Treasury address
    function setTreasury(address _treasury) external override nonZeroAddress(_treasury) onlyOwner {
        _setTreasury(_treasury);
    }

    /// @notice                             Internal setter for protocol percentage fee
    /// @param _protocolPercentageFee       Percentage amount of protocol fee
    function _setProtocolPercentageFee(uint _protocolPercentageFee) private {
        require(
            MAX_PROTOCOL_FEE >= _protocolPercentageFee,
            "CCTransferRouter: protocol fee is out of range"
        );
        emit NewProtocolPercentageFee(protocolPercentageFee, _protocolPercentageFee);
        protocolPercentageFee = _protocolPercentageFee;
    }

    /// @notice Internal setter for starting block number
    function _setStartingBlockNumber(uint _startingBlockNumber) private {
        require(
            _startingBlockNumber > startingBlockNumber,
            "CCTransferRouter: low startingBlockNumber"
        );
        startingBlockNumber = _startingBlockNumber;
    }

    /// @notice                             Internal setter for relay
    /// @param _relay                       Address of the relay contract
    function _setRelay(address _relay) private nonZeroAddress(_relay) {
        emit NewRelay(relay, _relay);
        relay = _relay;
    }

    /// @notice                             Internal setter for relay
    /// @param _lockers                     Address of the lockers contract
    function _setLockers(address _lockers) private nonZeroAddress(_lockers) {
        emit NewLockers(lockers, _lockers);
        lockers = _lockers;
    }

    /// @notice                             Internal setter for instant router
    /// @param _instantRouter               Address of the instant router contract
    function _setInstantRouter(address _instantRouter) private nonZeroAddress(_instantRouter) {
        emit NewInstantRouter(instantRouter, _instantRouter);
        instantRouter = _instantRouter;
    }

    /// @notice                             Internal setter for coreBTC
    /// @param _coreBTC                     CoreDAO BTC ERC20 token address
    function _setCoreBTC(address _coreBTC) private nonZeroAddress(_coreBTC) {
        emit NewCoreBTC(coreBTC, _coreBTC);
        coreBTC = _coreBTC;
    }

    /// @notice                             Internal setter for treasury
    /// @param _treasury                    Treasury address
    function _setTreasury(address _treasury) private nonZeroAddress(_treasury) {
        emit NewTreasury(treasury, _treasury);
        treasury = _treasury;
    }

    /// @notice                             Check if the request has been executed before
    /// @dev                                This is to avoid re-submitting a used request
    /// @param _txId                        The txId of request on the source chain
    /// @return                             True if the request has been executed
    function isRequestUsed(bytes32 _txId) external view override returns (bool) {
        return ccTransferRequests[_txId].isUsed ? true : false;
    }

    /// @notice                             Executes the cross chain transfer request
    /// @dev                                Validates the transfer request
    /// @param _tx                          Bitcoin tx
    /// @param _blockNumber                 The block number of the request tx
    /// @param _intermediateNodes           Merkle proof for tx
    /// @param _index                       Index of tx in the block
    /// @param _lockerLockingScript         Locking script of locker that user has sent BTC to it
    /// @return                             True if the transfer is successful
    function lockProof(
        // Bitcoin tx
        bytes calldata _tx,
        // Bitcoin block number
        uint256 _blockNumber,
        // Merkle proof
        bytes calldata _intermediateNodes,
        uint _index,
        bytes calldata _lockerLockingScript
    ) external nonReentrant override returns (bool) {
        require(_blockNumber >= startingBlockNumber, "CCTransferRouter: request is too old");

        // Finds txId on the source chain
        bytes32 txId = BitcoinHelper.calculateTxId(_tx);

        require(
            !ccTransferRequests[txId].isUsed,
            "CCTransferRouter: request has been used before"
        );

        (, , bytes29 voutView, uint32 lockTime) = _tx.extractTx();
        require(lockTime == 0, "CCTransferRouter: lock time is non -zero");

        // Extracts information from the request
        _saveCCTransferRequest(_lockerLockingScript, voutView, txId);

        // Checks if tx has been confirmed on source chain
        require(
            _isConfirmed(
                txId,
                _blockNumber,
                _intermediateNodes,
                _index
            ),
            "CCTransferRouter: transaction has not been finalized yet"
        );

        // Normal cc transfer request
        (uint receivedAmount, uint _protocolFee, uint _porterFee) = _sendCoreBTC(
            _lockerLockingScript,
            txId
        );
        emit CCTransfer(
            _lockerLockingScript,
            0,
            ILockers(lockers).getLockerTargetAddress(_lockerLockingScript),
            ccTransferRequests[txId].recipientAddress,
            ccTransferRequests[txId].inputAmount,
            receivedAmount,
            _msgSender(),
            _porterFee,
            _protocolFee,
            txId
        );
        return true;
    }

    /// @notice                             Sends minted coreBTC to the user
    /// @param _lockerLockingScript         Locker's locking script
    /// @param _txId                        The transaction ID of the request
    /// @return _remainedAmount             Amount of coreBTC that user receives after reducing fees
    function _sendCoreBTC(bytes memory _lockerLockingScript, bytes32 _txId) private returns (
        uint _remainedAmount,
        uint _protocolFee,
        uint _porterFee
    ) {
        // Gets remained amount after reducing fees
        (_remainedAmount, _protocolFee, _porterFee) = _mintAndReduceFees(_lockerLockingScript, _txId);

        // Transfers rest of tokens to recipient
        ICoreBTC(coreBTC).transfer(
            ccTransferRequests[_txId].recipientAddress,
            _remainedAmount
        );
    }

    /// @notice                             Parses and saves the request
    /// @dev                                Checks that user has sent BTC to a valid locker
    /// @param _lockerLockingScript         Locker's locking script
    /// @param _voutView                    The outputs view of the tx
    /// @param _txId                        The txID of the request
    function _saveCCTransferRequest(
        bytes memory _lockerLockingScript,
        bytes29 _voutView,
        bytes32 _txId
    ) private {

        require(
            ILockers(lockers).isLocker(_lockerLockingScript),
            "CCTransferRouter: no locker with the given locking script exists"
        );

        // Extracts value and opreturn data from request
        ccTransferRequest memory request; // Defines it to save gas
        bytes memory arbitraryData;

        (request.inputAmount, arbitraryData) = BitcoinHelper.parseValueAndDataHavingLockingScript(
            _voutView,
            _lockerLockingScript
        );

        require(arbitraryData.length == 27, "CCTransferRouter: invalid len");

        // Checks that input amount is not zero
        require(request.inputAmount > 0, "CCTransferRouter: input amount is zero");

        // Checks version, chain id and app id
        require(RequestHelper.parseVersion(arbitraryData) == version, "CCTransferRouter: version is not correct");
        require(RequestHelper.parseChainId(arbitraryData) == chainId, "CCTransferRouter: chain id is not correct");
        require(RequestHelper.parseAppId(arbitraryData) == appId, "CCTransferRouter: app id is not correct");

        // Calculates fee
        uint percentageFee = RequestHelper.parsePercentageFee(arbitraryData);
        require(percentageFee <= MAX_PROTOCOL_FEE, "CCTransferRouter: percentage fee is out of range");
        request.fee = percentageFee*request.inputAmount/MAX_PROTOCOL_FEE;

        // Parses recipient address
        request.recipientAddress = RequestHelper.parseRecipientAddress(arbitraryData);

        // Marks the request as used
        request.isUsed = true;

        // Saves the request data
        ccTransferRequests[_txId] = request;
    }

    /// @notice                             Checks if tx has been finalized on source chain
    /// @dev                                Pays relay fee using included ETH in the transaction
    /// @param _txId                        The request tx
    /// @param _blockNumber                 The block number of the tx
    /// @param _intermediateNodes           Merkle proof for tx
    /// @param _index                       Index of tx in the block
    /// @return                             True if the tx is finalized on the source chain
    function _isConfirmed(
        bytes32 _txId,
        uint256 _blockNumber,
        bytes memory _intermediateNodes,
        uint _index
    ) private view returns (bool) {

        // Calls relay contract (transfers all msg.value to it)
        bytes memory data = Address.functionStaticCall(
            relay,
            abi.encodeWithSignature(
                "checkTxProof(bytes32,uint256,bytes,uint256)",
                _txId,
                _blockNumber,
                _intermediateNodes,
                _index
            )
        );

        return abi.decode(data, (bool));
    }

    /// @notice                       Mints coreBTC by calling lockers contract
    /// @param _lockerLockingScript   Locker's locking script
    /// @param _txId                  The transaction ID of the request
    /// @return _remainedAmount       Amount of coreBTC that user receives after reducing all fees (protocol, locker, porter)
    function _mintAndReduceFees(
        bytes memory _lockerLockingScript,
        bytes32 _txId
    ) private returns (uint _remainedAmount, uint _protocolFee, uint _porterFee) {

        // Mints coreBTC for cc transfer router
        // Lockers contract gets locker's fee
        uint mintedAmount = ILockers(lockers).mint(
            _lockerLockingScript,
            address(this),
            _txId,
            ccTransferRequests[_txId].inputAmount
        );

        // Calculates fees
        _protocolFee = ccTransferRequests[_txId].inputAmount*protocolPercentageFee/MAX_PROTOCOL_FEE;
        _porterFee = ccTransferRequests[_txId].fee;

        // Pays Porter fee
        if (_porterFee > 0) {
            ICoreBTC(coreBTC).transfer(_msgSender(), _porterFee);
        }

        // Pays protocol fee
        if (_protocolFee > 0) {
            ICoreBTC(coreBTC).transfer(treasury, _protocolFee);
        }

        _remainedAmount = mintedAmount - _protocolFee - _porterFee;
    }

    receive() external payable {}
}
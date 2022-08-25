// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "./priceOracle/IPriceOracle.sol";
import "./constant/AvaxConstant.sol";
import "./constant/AuroraConstant.sol";
import "./constant/MaticConstant.sol";
import "../../libs/Const.sol";

interface IBNI is IERC20Upgradeable {
    function decimals() external view returns (uint8);
    function mint(address account_, uint256 amount_) external;
    function burn(uint256 amount) external;
    function burnFrom(address account_, uint256 amount_) external;
}

error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

interface Gateway {
    function getCurrentTokenCompositionPerc1() external view returns(
        uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs,
        bytes memory sig
    );
    function getAllPoolInUSD1() external view returns(
        uint[] memory _allPoolInUSDs,
        bytes memory sig
    );
    function getAllPoolInUSDAtNonce1(uint _nonce) external view returns(
        uint[] memory _allPoolInUSDs,
        bytes memory sig
    );
    function getPricePerFullShare1() external view returns(
        uint[] memory _allPoolInUSDs,
        bytes memory sig
    );
    function getAPR1() external view returns(
        uint[] memory _allPoolInUSDs,  uint[] memory _APRs,
        bytes memory sig
    );
    function getDepositTokenComposition1() external view returns(
        uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs,
        bytes memory sig
    );
}


contract BNIMinter is ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    using ECDSAUpgradeable for bytes32;

    enum OperationType { Null, Deposit, Withdrawal }

    struct Operation {
        address account;
        OperationType operation;
        uint pool; // total pool in USD
        uint amount; // amount of USDT or shares
        bool done;
    }

    uint[] public chainIDs;
    address[] public tokens;
    uint[] public targetPercentages;
    mapping(uint => mapping(address => uint)) public tid; // Token indices in arrays

    address public admin;
    IBNI public BNI;
    IPriceOracle public priceOracle;

    string[] public urls;
    address public gatewaySigner;

    address public trustedForwarder;

    Operation[] public operations; // The nonce start from 1.
    mapping(address => uint) public userLastOperationNonce;

    event AddToken(uint indexed chainID, address indexed token, uint indexed tid);
    event RemoveToken(uint indexed chainID, address indexed token, uint indexed tid, uint targetPerc);
    event NewOperation(address indexed account, OperationType indexed operation, uint amount, uint indexed nonce);
    event Mint(address indexed caller, uint indexed amtDeposit, uint indexed shareMinted);
    event Burn(address indexed caller, uint indexed shareBurned);

    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner() || msg.sender == address(admin), "Only owner or admin");
        _;
    }

    function initialize(
        address _admin, address _BNI, address _priceOracle
    ) external initializer {
        __Ownable_init();

        admin = _admin;
        BNI = IBNI(_BNI);
        priceOracle = IPriceOracle(_priceOracle);

        chainIDs.push(MaticConstant.CHAINID);
        chainIDs.push(AvaxConstant.CHAINID);
        chainIDs.push(AuroraConstant.CHAINID);

        tokens.push(MaticConstant.WMATIC);
        tokens.push(AvaxConstant.WAVAX);
        tokens.push(AuroraConstant.WNEAR);

        targetPercentages.push(4000); // 40%
        targetPercentages.push(4000); // 40%
        targetPercentages.push(2000); // 20%

        updateTid();

        urls.push("http://localhost:8000/");
        gatewaySigner = _admin;
    }

    function updateTid() private {
        uint[] memory _chainIDs = chainIDs;
        address[] memory _tokens = tokens;

        uint tokenCnt = _tokens.length;
        for (uint i = 0; i < tokenCnt; i ++) {
            tid[_chainIDs[i]][_tokens[i]] = i;
        }
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function setBiconomy(address _biconomy) external onlyOwner {
        trustedForwarder = _biconomy;
    }

    function isTrustedForwarder(address forwarder) public view returns(bool) {
        return forwarder == trustedForwarder;
    }

    function _msgSender() internal override(ContextUpgradeable) view returns (address ret) {
        if (msg.data.length >= 24 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            return msg.sender;
        }
    }

    function versionRecipient() external pure returns (string memory) {
        return "1";
    }

    function setGatewaySigner(address _signer) external onlyOwner {
        gatewaySigner = _signer;
    }

    function setUrls(string[] memory _urls) external onlyOwner {
        urls = _urls;
    }

    /// @notice After this method called, setTokenCompositionTargetPerc should be called to adjust percentages.
    function addToken(uint _chainID, address _token) external onlyOwner {
        uint _tid = tid[_chainID][_token];
        require ((_tid == 0 && _chainID != chainIDs[0] && _token != tokens[0]), "Already added");

        chainIDs.push(_chainID);
        tokens.push(_token);
        targetPercentages.push(0);

        _tid = tokens.length-1;
        tid[_chainID][_token] = _tid;

        emit AddToken(_chainID, _token, _tid);
    }

    /// @notice After this method called, setTokenCompositionTargetPerc should be called to adjust percentages.
    function removeToken(uint _tid) external onlyOwner {
        uint tokenCnt = tokens.length;
        require(_tid < tokenCnt, "Invalid tid");

        uint _chainID = chainIDs[_tid];
        address _token = tokens[_tid];
        uint _targetPerc = targetPercentages[_tid];

        chainIDs[_tid] = chainIDs[tokenCnt-1];
        chainIDs.pop();
        tokens[_tid] = tokens[tokenCnt-1];
        tokens.pop();
        targetPercentages[_tid] = targetPercentages[tokenCnt-1];
        targetPercentages.pop();

        tid[_chainID][_token] = 0;
        updateTid();

        emit RemoveToken(_chainID, _token, _tid, _targetPerc);
    }

    /// @notice The length of array is based on token count.
    function setTokenCompositionTargetPerc(uint[] calldata _targetPerc) public onlyOwner {
        uint targetCnt = _targetPerc.length;
        require(targetCnt == targetPercentages.length, "Invalid count");

        uint sum;
        for (uint i = 0; i < targetCnt; i ++) {
            targetPercentages[i] = _targetPerc[i];
            sum += _targetPerc[i];
        }
        require(sum == Const.DENOMINATOR, "Invalid parameter");
    }

    /// @notice The length of array is based on token count. And the lengths should be same on the arraies.
    function getEachPoolInUSD(
        uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs
    ) private view returns (uint[] memory pools) {
        uint inputCnt = _tokens.length;
        uint tokenCnt = tokens.length;
        pools = new uint[](tokenCnt);

        for (uint i = 0; i < inputCnt; i ++) {
            uint _chainID = _chainIDs[i];
            address _token = _tokens[i];
            uint _tid = tid[_chainID][_token];
            if (tokenCnt <= _tid) continue;
            if (_tid == 0 && (_chainID != chainIDs[0] || _token != tokens[0])) continue;

            pools[_tid] = _poolInUSDs[i];
        }
    }

    /// @notice The length of array is based on token count. And the lengths should be same on the arraies.
    function getCurrentTokenCompositionPerc(
        uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs
    ) public view returns (
        uint[] memory, address[] memory, uint[] memory pools, uint[] memory percentages
    ) {
        pools = getEachPoolInUSD(_chainIDs, _tokens, _poolInUSDs);
        uint poolCnt = pools.length;

        uint allPool;
        for (uint i = 0; i < poolCnt; i ++) {
            allPool += pools[i];
        }

        percentages = new uint[](poolCnt);
        for (uint i = 0; i < poolCnt; i ++) {
            percentages[i] = allPool == 0 ? targetPercentages[i] : pools[i] * Const.DENOMINATOR / allPool;
        }

        return (chainIDs, tokens, pools, percentages);
    }
    function getCurrentTokenCompositionPerc1() external view returns (
        uint[] memory, address[] memory, uint[] memory, uint[] memory
    ) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getCurrentTokenCompositionPerc1.selector),
            BNIMinter.getCurrentTokenCompositionPercWithSig.selector,
            abi.encode(0)
        );
    }
    function getCurrentTokenCompositionPercWithSig(bytes calldata result, bytes calldata extraData) external view returns(
        uint[] memory, address[] memory, uint[] memory, uint[] memory
    ) {
        extraData;
        (uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs, bytes memory sig)
            = abi.decode(result, (uint[], address[], uint[], bytes));

        address recovered = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_chainIDs, _tokens, _poolInUSDs))
        )).recover(sig);
        require(gatewaySigner == recovered, "Signer is incorrect");

        return getCurrentTokenCompositionPerc(_chainIDs, _tokens, _poolInUSDs);
    }

    /// @notice The length of array is based on network count. And the lengths should be same on the arraies.
    function getAllPoolInUSD(uint[] memory _allPoolInUSDs) public pure returns (uint) {
        uint networkCnt = _allPoolInUSDs.length;
        uint allPoolInUSD;
        for (uint i = 0; i < networkCnt; i ++) {
            allPoolInUSD += _allPoolInUSDs[i];
        }
        return allPoolInUSD;
    }
    function getAllPoolInUSD1() external view returns (uint) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getAllPoolInUSD1.selector),
            BNIMinter.getAllPoolInUSD1WithSig.selector,
            abi.encode(0)
        );
    }
    function getAllPoolInUSD1WithSig(bytes calldata result, bytes calldata extraData) external view returns(uint) {
        extraData;
        (uint[] memory _allPoolInUSDs, bytes memory sig) = abi.decode(result, (uint[], bytes));

        address recovered = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_allPoolInUSDs))
        )).recover(sig);
        require(gatewaySigner == recovered, "Signer is incorrect");

        return getAllPoolInUSD(_allPoolInUSDs);
    }

    function getAllPoolInUSDAtNonce1(uint _nonce) external view returns (uint) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getAllPoolInUSDAtNonce1.selector, _nonce),
            BNIMinter.getAllPoolInUSD1WithSig.selector,
            abi.encode(_nonce)
        );
    }

    /// @notice Can be used for calculate both user shares & APR
    function getPricePerFullShare(uint[] memory _allPoolInUSDs) public view returns (uint) {
        uint _totalSupply = BNI.totalSupply();
        if (_totalSupply == 0) return 1e18;
        return getAllPoolInUSD(_allPoolInUSDs) * 1e18 / _totalSupply;
    }
    function getPricePerFullShare1() external view returns (uint) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getPricePerFullShare1.selector),
            BNIMinter.getPricePerFullShare1WithSig.selector,
            abi.encode(0)
        );
    }
    function getPricePerFullShare1WithSig(bytes calldata result, bytes calldata extraData) external view returns(uint) {
        extraData;
        (uint[] memory _allPoolInUSDs, bytes memory sig) = abi.decode(result, (uint[], bytes));

        address recovered = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_allPoolInUSDs))
        )).recover(sig);
        require(gatewaySigner == recovered, "Signer is incorrect");

        return getPricePerFullShare(_allPoolInUSDs);
    }

    /// @notice The length of array is based on network count. And the lengths should be same on the arraies.
    function getAPR(uint[] memory _allPoolInUSDs, uint[] memory _APRs) public pure returns (uint) {
        uint networkCnt = _allPoolInUSDs.length;
        require(networkCnt == _APRs.length, "Not match array length");

        uint pool = getAllPoolInUSD(_allPoolInUSDs);
        if (pool == 0) return 0;

        uint allApr;
        for (uint i = 0; i < networkCnt; i ++) {
            allApr += (_APRs[i] * _allPoolInUSDs[i]);
        }
        return (allApr / pool);
    }
    function getAPR1() external view returns (uint) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getAPR1.selector),
            BNIMinter.getAPR1WithSig.selector,
            abi.encode(0)
        );
    }
    function getAPR1WithSig(bytes calldata result, bytes calldata extraData) external view returns(uint) {
        extraData;
        (uint[] memory _allPoolInUSDs,  uint[] memory _APRs, bytes memory sig) = abi.decode(result, (uint[], uint[], bytes));

        address recovered = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_allPoolInUSDs, _APRs))
        )).recover(sig);
        require(gatewaySigner == recovered, "Signer is incorrect");

        return getAPR(_allPoolInUSDs, _APRs);
    }

    /// @return the price of USDT in USD.
    function getUSDTPriceInUSD() public virtual view returns(uint, uint8) {
        return priceOracle.getAssetPrice(AvaxConstant.USDT);
    }

    /// @notice The length of array is based on token count. And the lengths should be same on the arraies.
    /// @param _USDTAmt amount of USDT with 6 decimals
    /// @return _USDTAmts amount of USDT should be deposited to each pools
    function getDepositTokenComposition(
        uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs, uint _USDTAmt
    ) public view returns (
        uint[] memory, address[] memory, uint[] memory _USDTAmts
    ) {
        (,, uint[] memory pools, uint[] memory perc) = getCurrentTokenCompositionPerc(_chainIDs, _tokens, _poolInUSDs);
        uint poolCnt = perc.length;
        (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();

        uint allPool = _USDTAmt * 1e12 * USDTPriceInUSD / (10 ** USDTPriceDecimals); // USDT's decimals is 6
        for (uint i = 0; i < poolCnt; i ++) {
            allPool += pools[i];
        }

        uint totalAllocation;
        uint[] memory allocations = new uint[](poolCnt);
        for (uint i = 0; i < poolCnt; i ++) {
            uint target = allPool * targetPercentages[i] / Const.DENOMINATOR;
            if (pools[i] < target) {
                uint diff = target - pools[i];
                allocations[i] = diff;
                totalAllocation += diff;
            }
        }

        _USDTAmts = new uint[](poolCnt);
        for (uint i = 0; i < poolCnt; i ++) {
            _USDTAmts[i] = _USDTAmt * allocations[i] / totalAllocation;
        }

        return (chainIDs, tokens, _USDTAmts);
    }
    function getDepositTokenComposition1(uint _USDTAmt) external view returns (
        uint[] memory, address[] memory, uint[] memory
    ) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getDepositTokenComposition1.selector),
            BNIMinter.getDepositTokenComposition1WithSig.selector,
            abi.encode(_USDTAmt)
        );
    }
    function getDepositTokenComposition1WithSig(bytes calldata result, bytes calldata extraData) external view returns(
        uint[] memory, address[] memory, uint[] memory
    ) {
        (uint _USDTAmt) = abi.decode(extraData, (uint));
        (uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs, bytes memory sig)
            = abi.decode(result, (uint[], address[], uint[], bytes));

        address recovered = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_chainIDs, _tokens, _poolInUSDs))
        )).recover(sig);
        require(gatewaySigner == recovered, "Signer is incorrect");

        return getDepositTokenComposition(_chainIDs, _tokens, _poolInUSDs, _USDTAmt);
    }

    /// @notice The length of array is based on token count. And the lengths should be same on the arraies.
    /// @param _share amount of BNI to be withdrawn
    /// @return _sharePerc percentage of assets which should be withdrawn. It's 18 decimals
    function getWithdrawPerc(address _account, uint _share) public view returns (uint _sharePerc) {
        require(0 < _share && _share <= BNI.balanceOf(_account), "Invalid share amount");
        return (_share * 1e18) / BNI.totalSupply();
    }

    function getNonce() public view returns (uint) {
        return operations.length;
    }

    function getOperation(uint _nonce) public view returns (Operation memory) {
        return operations[_nonce - 1];
    }

    function _checkAndAddOperation(address _account, OperationType _operation, uint _pool, uint _amount) internal {
        uint nonce = userLastOperationNonce[_account];
        if (nonce > 0) {
            Operation memory op = getOperation(nonce);
            require(op.done, "Previous operation not finished");
        }
        operations.push(Operation({
            account: _account,
            operation: _operation,
            pool: _pool,
            amount: _amount,
            done: false
        }));
        nonce = getNonce();
        userLastOperationNonce[_account] = nonce;
        emit NewOperation(_account, _operation, _amount, nonce);
    }

    function _checkAndExitOperation(address _account, OperationType _operation) internal returns (uint _pool, uint _amount) {
        uint nonce = userLastOperationNonce[_account];
        require(nonce > 0, "No operation");

        Operation memory op = getOperation(nonce);
        require(op.operation == _operation && op.done == false, "Already finished");

        operations[nonce - 1].done = true;
        return (op.pool, op.amount);
    }

    /// @param _account account to which BNIs will be minted
    /// @param _pool total pool in USD
    /// @param _USDTAmt USDT with 6 decimals to be deposited
    function initDepositByAdmin(address _account, uint _pool, uint _USDTAmt) external onlyOwnerOrAdmin whenNotPaused {
        _checkAndAddOperation(_account, OperationType.Deposit, _pool, _USDTAmt);
    }

    /// @dev mint BNIs according to the deposited USDT
    /// @param _account account to which BNIs will be minted
    /// @param _USDTAmt the deposited USDT with 6 decimals
    function mintByAdmin(address _account, uint _USDTAmt) external onlyOwnerOrAdmin nonReentrant whenNotPaused {
        (uint pool,) = _checkAndExitOperation(_account, OperationType.Deposit);

        (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
        uint amtDeposit = _USDTAmt * 1e12 * USDTPriceInUSD / (10 ** USDTPriceDecimals); // USDT's decimals is 6

        uint _totalSupply = BNI.totalSupply();
        uint share = (_totalSupply == 0 || pool == 0)  ? amtDeposit : _totalSupply * amtDeposit / pool;
        // When assets invested in strategy, around 0.3% lost for swapping fee. We will consider it in share amount calculation to avoid pricePerFullShare fall down under 1.
        share = share * 997 / 1000;

        BNI.mint(_account, share);
        emit Mint(_account, amtDeposit, share);
    }

    /// @dev mint BNIs according to the deposited USDT
    /// @param _account account to which BNIs will be minted
    /// @param _pool total pool in USD
    /// @param _share amount of BNI to be burnt
    function burnByAdmin(address _account, uint _pool, uint _share) external onlyOwnerOrAdmin nonReentrant {
        require(0 < _share && _share <= BNI.balanceOf(_account), "Invalid share amount");
        _checkAndAddOperation(_account, OperationType.Withdrawal, _pool, _share);

        BNI.burnFrom(_account, _share);
        emit Burn(_account, _share);
    }

    function exitWithdrawalByAdmin(address _account) external onlyOwnerOrAdmin {
        _checkAndExitOperation(_account, OperationType.Withdrawal);
    }
}

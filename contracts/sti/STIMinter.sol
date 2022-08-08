// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "../bni/priceOracle/IPriceOracle.sol";
import "../bni/constant/AuroraConstant.sol";
import "../bni/constant/AvaxConstant.sol";
import "../bni/constant/BscConstant.sol";
import "../bni/constant/EthConstant.sol";
import "../../libs/Const.sol";
import "../../libs/BaseRelayRecipient.sol";

interface ISTI is IERC20Upgradeable {
    function decimals() external view returns (uint8);
    function mint(address account_, uint256 amount_) external;
    function burn(uint256 amount) external;
    function burnFrom(address account_, uint256 amount_) external;
}

error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

interface Gateway {
    function getCurrentTokenCompositionPerc1() external view returns (
        uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs,
        bytes memory sig
    );
    function getAllPoolInUSD1() external view returns (
        uint[] memory _allPoolInUSDs,
        bytes memory sig
    );
    function getPricePerFullShare1() external view returns (
        uint[] memory _allPoolInUSDs,
        bytes memory sig
    );
    function getAPR1() external view returns (
        uint[] memory _allPoolInUSDs,  uint[] memory _APRs,
        bytes memory sig
    );
    function getDepositTokenComposition1() external view returns (
        uint[] memory _chainIDs, address[] memory _tokens, uint[] memory _poolInUSDs,
        bytes memory sig
    );
    function getPoolsUnbonded1(address claimer) external view returns (
        uint[] memory _chainIDs, address[] memory _tokens,
        uint[] memory _waitings, uint[] memory _waitingInUSDs,
        uint[] memory _unbondeds, uint[] memory _unbondedInUSDs,
        uint[] memory _waitForTses,
        bytes memory sig
    );
    function getWithdrawableSharePerc1() external view returns(
        uint[] memory _chainIDs, uint[] memory _sharePercs,
        bytes memory sig
    );
}

contract STIMinter is BaseRelayRecipient, ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    using ECDSAUpgradeable for bytes32;

    uint[] public chainIDs;
    address[] public tokens;
    uint[] public targetPercentages;
    mapping(uint => mapping(address => uint)) public tid; // Token indices in arrays

    address public admin;
    ISTI public STI;
    IPriceOracle public priceOracle;

    string[] public urls;
    address public gatewaySigner;

    event SetAdminWallet(address oldAdmin, address newAdmin);
    event SetBiconomy(address oldBiconomy, address newBiconomy);
    event AddToken(uint chainID, address token, uint tid);
    event RemoveToken(uint chainID, address token, uint targetPerc, uint tid);
    event Mint(address caller, uint amtDeposit, uint shareMinted);
    event Burn(address caller, uint shareBurned);

    modifier onlyOwnerOrAdmin {
        require(msg.sender == owner() || msg.sender == address(admin), "Only owner or admin");
        _;
    }

    function initialize(
        address _admin, address _biconomy,
        address _STI, address _priceOracle
    ) external virtual initializer {
        __Ownable_init();

        admin = _admin;
        trustedForwarder = _biconomy;
        STI = ISTI(_STI);
        priceOracle = IPriceOracle(_priceOracle);

        chainIDs.push(EthConstant.CHAINID);
        tokens.push(Const.NATIVE_ASSET); // ETH
        chainIDs.push(EthConstant.CHAINID);
        tokens.push(EthConstant.MATIC);
        chainIDs.push(BscConstant.CHAINID);
        tokens.push(Const.NATIVE_ASSET); // BNB
        chainIDs.push(AvaxConstant.CHAINID);
        tokens.push(Const.NATIVE_ASSET); // AVAX
        chainIDs.push(AuroraConstant.CHAINID);
        tokens.push(AuroraConstant.WNEAR);

        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%
        targetPercentages.push(2000); // 20%

        updateTid();

        urls.push("http://localhost:8001/");
        gatewaySigner = _admin;
    }

    function updateTid() internal {
        uint[] memory _chainIDs = chainIDs;
        address[] memory _tokens = tokens;

        uint tokenCnt = _tokens.length;
        for (uint i = 0; i < tokenCnt; i ++) {
            tid[_chainIDs[i]][_tokens[i]] = i;
        }
    }

    function setAdmin(address _admin) external onlyOwner {
        address oldAdmin = admin;
        admin = _admin;
        emit SetAdminWallet(oldAdmin, _admin);
    }

    function setBiconomy(address _biconomy) external onlyOwner {
        address oldBiconomy = trustedForwarder;
        trustedForwarder = _biconomy;
        emit SetBiconomy(oldBiconomy, _biconomy);
    }

    function _msgSender() internal override(ContextUpgradeable, BaseRelayRecipient) view returns (address) {
        return BaseRelayRecipient._msgSender();
    }

    function versionRecipient() external pure override returns (string memory) {
        return "1";
    }

    function setGatewaySigner(address _signer) external onlyOwner {
        gatewaySigner = _signer;
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

        emit RemoveToken(_chainID, _token, _targetPerc, _tid);
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
            STIMinter.getCurrentTokenCompositionPercWithSig.selector,
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
            STIMinter.getAllPoolInUSD1WithSig.selector,
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

    /// @notice Can be used for calculate both user shares & APR
    function getPricePerFullShare(uint[] memory _allPoolInUSDs) public view returns (uint) {
        uint _totalSupply = STI.totalSupply();
        if (_totalSupply == 0) return 1e18;
        return getAllPoolInUSD(_allPoolInUSDs) * 1e18 / _totalSupply;
    }
    function getPricePerFullShare1() external view returns (uint) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getPricePerFullShare1.selector),
            STIMinter.getPricePerFullShare1WithSig.selector,
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
            STIMinter.getAPR1WithSig.selector,
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
    function getUSDTPriceInUSD() public view virtual returns(uint, uint8) {
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
            STIMinter.getDepositTokenComposition1WithSig.selector,
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

    ///@return _chainIDs is an array of chain IDs.
    ///@return _tokens is an array of tokens.
    ///@return _waitings is an array of token amounts that is not unbonded.
    ///@return _waitingInUSDs is an array of USD value of token amounts that is not unbonded.
    ///@return _unbondeds is an array of token amounts that is unbonded.
    ///@return _unbondedInUSDs is an array USD value of token amounts that is unbonded.
    ///@return _waitForTses is an array of timestamps to wait to the next claim.
    function getPoolsUnbonded1(address _account) external view returns (
        uint[] memory, // _chainIDs
        address[] memory, // _tokens
        uint[] memory, // _waitings
        uint[] memory, // _waitingInUSDs
        uint[] memory, // _unbondeds
        uint[] memory, // _unbondedInUSDs
        uint[] memory // _waitForTses
    ) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getPoolsUnbonded1.selector, _account),
            STIMinter.getPoolsUnbonded1WithSig.selector,
            abi.encode(_account)
        );
    }
    function getPoolsUnbonded1WithSig(bytes calldata result, bytes calldata) external view returns(
        uint[] memory _chainIDs,
        address[] memory _tokens,
        uint[] memory _waitings,
        uint[] memory _waitingInUSDs,
        uint[] memory _unbondeds,
        uint[] memory _unbondedInUSDs,
        uint[] memory _waitForTses
    ) {
        bytes memory sig;
        (_chainIDs, _tokens, _waitings, _waitingInUSDs, _unbondeds, _unbondedInUSDs, _waitForTses, sig)
            = abi.decode(result, (uint[], address[], uint[], uint[], uint[], uint[], uint[], bytes));

        bytes32 messageHash1 = keccak256(abi.encodePacked(_chainIDs, _tokens, _waitings, _waitingInUSDs, _unbondeds, _unbondedInUSDs));
        bytes32 messageHash2 = keccak256(abi.encodePacked(_waitForTses));
        bytes32 messageHash = keccak256(abi.encodePacked(messageHash1, messageHash2));
        address recovered = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)).recover(sig);
        require(gatewaySigner == recovered, "Signer is incorrect");
    }

    /// @dev mint STIs according to the deposited USDT
    /// @param _pool total USD worth in all pools of STI after deposited
    /// @param _account account to which STIs will be minted
    /// @param _USDTAmt the deposited amount of USDT with 6 decimals
    function mintByAdmin(uint _pool, address _account, uint _USDTAmt) external onlyOwnerOrAdmin nonReentrant whenNotPaused {
        (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
        uint amtDeposit = _USDTAmt * 1e12 * USDTPriceInUSD / (10 ** USDTPriceDecimals); // USDT's decimals is 6
        _pool = (amtDeposit < _pool) ? _pool - amtDeposit : 0;

        uint _totalSupply = STI.totalSupply();
        uint share = (_pool == 0 ||_totalSupply == 0)  ? amtDeposit : _totalSupply * amtDeposit / _pool;
        // When assets invested in strategy, around 0.3% lost for swapping fee. We will consider it in share amount calculation to avoid pricePerFullShare fall down under 1.
        share = share * 997 / 1000;

        STI.mint(_account, share);
        emit Mint(_account, amtDeposit, share);
    }

    /// @param _share amount of STI to be withdrawn
    /// @return _sharePerc percentage of assets which should be withdrawn. It's 18 decimals
    function getWithdrawPerc(address _account, uint _share) public view returns (uint _sharePerc) {
        require(0 < _share && _share <= STI.balanceOf(_account), "Invalid share amount");
        return (_share * 1e18) / STI.totalSupply();
    }

    function getWithdrawableSharePerc1() external view returns (
        uint // _sharePerc
    ) {
        revert OffchainLookup(address(this), urls,
            abi.encodeWithSelector(Gateway.getWithdrawableSharePerc1.selector),
            STIMinter.getWithdrawableSharePerc1WithSig.selector,
            abi.encode(0)
        );
    }
    function getWithdrawableSharePerc1WithSig(bytes calldata result, bytes calldata extraData) external view returns(
        uint _sharePerc
    ) {
        extraData;
        (uint[] memory _chainIDs, uint[] memory _sharePercs, bytes memory sig)
            = abi.decode(result, (uint[], uint[], bytes));

        address recovered = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_chainIDs, _sharePercs))
        )).recover(sig);
        require(gatewaySigner == recovered, "Signer is incorrect");

        uint length = _sharePercs.length;
        if (length > 0) {
            _sharePerc = _sharePercs[0];
        }
        for (uint i = 1; i < length; i++) {
            uint perc = _sharePercs[i];
            if (_sharePerc > perc) _sharePerc = perc;
        }
    }

    /// @dev mint STIs according to the deposited USDT
    /// @param _account account to which STIs will be minted
    /// @param _share amount of STI to be burnt
    function burnByAdmin(address _account, uint _share) external onlyOwnerOrAdmin nonReentrant {
        require(0 < _share && _share <= STI.balanceOf(_account), "Invalid share amount");
        STI.burnFrom(_account, _share);
        emit Burn(_account, _share);
    }

    function setUrls(string[] memory _urls) external onlyOwner {
        urls = _urls;
    }
}

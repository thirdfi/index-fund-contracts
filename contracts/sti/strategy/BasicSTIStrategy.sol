// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../bni/priceOracle/IPriceOracle.sol";
import "../../../interfaces/IERC20UpgradeableExt.sol";
import "../../../interfaces/IUniRouter.sol";
import "../../../interfaces/IStVault.sol";
import "../../../libs/Const.sol";
import "../../../libs/Token.sol";

contract BasicSTIStrategy is PausableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20UpgradeableExt;

    IUniRouter public router;
    IERC20UpgradeableExt public SWAP_BASE_TOKEN; // It has same role with WETH on Ethereum Swaps. Most of tokens have been paired with this token.
    IERC20UpgradeableExt public USDT;
    uint8 usdtDecimals;

    address public admin;
    address public vault;
    IPriceOracle public priceOracle;

    address[] public tokens;
    mapping(address => uint) public pid; // Pool indices in tokens array

    // maps the address to array of the owned tokens, the first key is token address.
    mapping(address => mapping(address => uint[])) public claimer2ReqIds;
    // reqId can be owned by only one address at the time, therefore reqId is present in only one of those arrays in the mapping
    // this mapping stores the index of the reqId in one of those arrays, the first key is token address.
    mapping(address => mapping(uint => uint)) public reqId2Index;

    event AddToken(address token, uint pid);
    event RemoveToken(address token, uint pid);
    event Withdraw(uint sharePerc, uint USDTAmt);
    event Claim(address claimer, address token, uint tokenAmt, uint USDTAmt);
    event EmergencyWithdraw(uint USDTAmt);
    event SetTreasuryWallet(address oldTreasuryWallet, address newTreasuryWallet);
    event SetAdminWallet(address oldAdmin, address newAdmin);

    modifier onlyVault {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function initialize(
        address _admin,
        address _priceOracle,
        address _router, address _SWAP_BASE_TOKEN,
        address _USDT, address _token0
    ) public virtual initializer {
        require(_router != address(0), "Invalid router");
        require(_SWAP_BASE_TOKEN != address(0), "Invalid SWAP_BASE_TOKEN");
        require(_USDT != address(0), "Invalid USDT");
        require(_token0 != address(0), "Invalid token0");
        __Ownable_init();

        admin = _admin;
        priceOracle = IPriceOracle(_priceOracle);
        router = IUniRouter(_router);
        SWAP_BASE_TOKEN = IERC20UpgradeableExt(_SWAP_BASE_TOKEN);

        USDT = IERC20UpgradeableExt(_USDT);
        usdtDecimals = USDT.decimals();
        require(usdtDecimals >= 6, "USDT decimals must >= 6");

        tokens.push(_token0);
        updatePid();

        USDT.safeApprove(address(router), type(uint).max);
        if (_token0 != Const.NATIVE_ASSET) {
            IERC20UpgradeableExt(_token0).safeApprove(address(router), type(uint).max);
        }
    }

    function updatePid() internal {
        address[] memory _tokens = tokens;

        uint tokenCnt = _tokens.length;
        for (uint i = 0; i < tokenCnt; i ++) {
            pid[_tokens[i]] = i;
        }
    }

    function getPoolCount() public view returns (uint) {
        return tokens.length;
    }

    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    function addToken(address _token) external onlyOwner {
        uint _pid = pid[_token];
        require ((_pid == 0 && _token != tokens[0]), "Already added");

        tokens.push(_token);
        _pid = tokens.length-1;
        pid[_token] = _pid;

        if (_token != Const.NATIVE_ASSET && IERC20UpgradeableExt(_token).allowance(address(this), address(router)) == 0) {
            IERC20UpgradeableExt(_token).safeApprove(address(router), type(uint).max);
        }
        emit AddToken(_token, _pid);
    }

    function removeToken(uint _pid) external onlyOwner {
        uint tokenCnt = tokens.length;
        require(_pid < tokenCnt, "Invalid pid");
        uint pool = _getPoolInUSD(_pid);
        require(pool == 0, "Pool is not empty");

        address _token = tokens[_pid];
        tokens[_pid] = tokens[tokenCnt-1];
        tokens.pop();

        pid[_token] = 0;
        updatePid();

        emit RemoveToken(_token, _pid);
    }

    /// @param _USDTAmts amounts of USDT should be deposited to each pools. They have been denominated in USDT decimals
    function invest(address[] memory _tokens, uint[] memory _USDTAmts) external onlyVault {
        _investInternal(_tokens, _USDTAmts);
    }

    function _investInternal(address[] memory _tokens, uint[] memory _USDTAmts) internal {
        uint poolCnt = _tokens.length;
        uint USDTAmt;
        uint[] memory USDTAmts = new uint[](tokens.length);
        for (uint i = 0; i < poolCnt; i ++) {
            uint amount = _USDTAmts[i];
            USDTAmt += amount;
            uint _pid = pid[_tokens[i]];
            USDTAmts[_pid] += amount;
        }
        USDT.safeTransferFrom(vault, address(this), USDTAmt);

        _invest(USDTAmts);
    }

    function _invest(uint[] memory _USDTAmts) internal virtual {
        uint poolCnt = _USDTAmts.length;
        for (uint _pid = 0; _pid < poolCnt; _pid ++) {
            address token = tokens[_pid];
            uint tokenAmt;
            if (token != address(USDT)) {
                uint USDTAmt = _USDTAmts[_pid];
                (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
                (uint TOKENPriceInUSD, uint8 TOKENPriceDecimals) = priceOracle.getAssetPrice(token);
                uint8 tokenDecimals = _assetDecimals(token);
                uint numerator = USDTPriceInUSD * (10 ** (TOKENPriceDecimals + tokenDecimals));
                uint denominator = TOKENPriceInUSD * (10 ** (USDTPriceDecimals + usdtDecimals));
                uint amountOutMin = USDTAmt * numerator * 90 / (denominator * 100);

                if (token == Const.NATIVE_ASSET) {
                    tokenAmt = _swapForETH(address(USDT), USDTAmt, amountOutMin);
                } else if (token == address(SWAP_BASE_TOKEN)) {
                    tokenAmt = _swap(address(USDT), token, USDTAmt, amountOutMin);
                } else {
                    tokenAmt = _swap2(address(USDT), token, USDTAmt, amountOutMin);
                }
            } else {
                tokenAmt = _USDTAmts[_pid];
            }

            IStVault stVault = getStVault(_pid);
            if (address(stVault) != address(0)) {
                if (token == Const.NATIVE_ASSET) {
                    stVault.depositETH{value: tokenAmt}();
                } else {
                    stVault.deposit(tokenAmt);
                }
            }
        }
    }

    function withdrawPerc(address _claimer, uint _sharePerc) external onlyVault returns (uint USDTAmt) {
        require(_sharePerc <= 1e18, "Over 100%");
        USDTAmt = _withdraw(_claimer, _sharePerc);
        if (USDTAmt > 0) {
            USDT.safeTransfer(vault, USDTAmt);
        }
        emit Withdraw(_sharePerc, USDTAmt);
    }

    function _withdraw(address _claimer, uint _sharePerc) internal virtual returns (uint USDTAmt) {
        uint poolCnt = tokens.length;
        for (uint i = 0; i < poolCnt; i ++) {
            USDTAmt += _withdrawFromPool(_claimer, i, _sharePerc);
        }
    }

    function _withdrawFromPool(address _claimer, uint _pid, uint _sharePerc) internal virtual returns (uint USDTAmt) {
        IStVault stVault = getStVault(_pid);
        if (address(stVault) != address(0)) {
            uint reqId;
            (USDTAmt, reqId) = _withdrawStVault(stVault, _sharePerc);
            if (reqId > 0) {
                addReqId(tokens[_pid], _claimer, reqId);
            }
        } else {
            address token = tokens[_pid];
            uint amount = _balanceOf(token, address(this)) * _sharePerc / 1e18;
            if (0 < amount) {
                if (token == address(USDT)) {
                    USDTAmt = amount;
                } else {
                    USDTAmt = _swapForUSDT(token, amount);
                }
            }
        }
    }

    function _withdrawStVault(IStVault _stVault, uint _sharePerc) private returns (uint USDTAmt, uint reqId) {
        uint amount = _stVault.balanceOf(address(this)) * _sharePerc / 1e18;
        if (0 < amount) {
            (uint tokenAmt, uint _reqId) = _stVault.withdraw(amount);
            if (tokenAmt > 0) {
                USDTAmt = _swapForUSDT(address(_stVault.token()), tokenAmt);
            }
            reqId = _reqId;
        }
    }

    function _swapForUSDT(address token, uint amount) internal returns (uint USDTAmt) {
        (uint USDTPriceInUSD, uint8 USDTPriceDecimals) = getUSDTPriceInUSD();
        (uint TOKENPriceInUSD, uint8 TOKENPriceDecimals) = priceOracle.getAssetPrice(address(token));
        uint8 tokenDecimals = _assetDecimals(token);
        uint numerator = TOKENPriceInUSD * (10 ** (USDTPriceDecimals + usdtDecimals));
        uint denominator = USDTPriceInUSD * (10 ** (TOKENPriceDecimals + tokenDecimals));
        uint amountOutMin = amount * numerator * 95 / (denominator * 100);

        if (address(token) == address(Const.NATIVE_ASSET)) {
            USDTAmt = _swapETH(address(USDT), amount, amountOutMin);
        } else if (address(token) == address(SWAP_BASE_TOKEN)) {
            USDTAmt = _swap(address(token), address(USDT), amount, amountOutMin);
        } else{
            USDTAmt = _swap2(address(token), address(USDT), amount, amountOutMin);
        }
    }

    function _swap(address _tokenA, address _tokenB, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = _tokenB;
        return (router.swapExactTokensForTokens(_amt, _minAmount, path, address(this), block.timestamp))[1];
    }

    function _swap2(address _tokenA, address _tokenB, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](3);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        path[2] = _tokenB;
        return (router.swapExactTokensForTokens(_amt, _minAmount, path, address(this), block.timestamp))[2];
    }

    function _swapETH(address _tokenB, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(SWAP_BASE_TOKEN);
        path[1] = _tokenB;
        return (router.swapExactETHForTokens{value: _amt}(_minAmount, path, address(this), block.timestamp))[1];
    }

    function _swapForETH(address _tokenA, uint _amt, uint _minAmount) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = _tokenA;
        path[1] = address(SWAP_BASE_TOKEN);
        return (router.swapExactTokensForETH(_amt, _minAmount, path, address(this), block.timestamp))[1];
    }

    function withdrawFromPool(address _claimer, uint _pid, uint _sharePerc) external onlyVault returns (uint USDTAmt) {
        require(_sharePerc <= 1e18, "Over 100%");
        USDTAmt = _withdrawFromPool(_claimer, _pid, _sharePerc);
        if (USDTAmt > 0) {
            USDT.safeTransfer(vault, USDTAmt);
        }
    }

    function emergencyWithdraw() external onlyVault {
        _pause();
        // 1e18 == 100% of share
        uint USDTAmt = _withdraw(address(this), 1e18);
        if (USDTAmt > 0) {
            USDT.safeTransfer(vault, USDTAmt);
        }
        emit EmergencyWithdraw(USDTAmt);
    }

    function claimEmergencyWithdrawal() external onlyVault {
        _claimAllAndTransfer(address(this));
    }

    function getEmergencyWithdrawalUnbonded() public view returns (
        uint waitingInUSD, uint unbondedInUSD, uint waitForTs
    ) {
        return _getAllUnbonded(address(this));
    }

    /// @param _USDTAmts amounts of USDT should be deposited to each pools. They have been denominated in USDT decimals
    function reinvest(address[] memory _tokens, uint[] memory _USDTAmts) external onlyVault {
        _unpause();
        _investInternal(_tokens, _USDTAmts);
    }

    function addReqId(address _token, address _claimer, uint _reqId) internal {
        uint[] storage reqIds = claimer2ReqIds[_token][_claimer];

        reqIds.push(_reqId);
        reqId2Index[_token][_reqId] = reqIds.length - 1;
    }

    function removeReqId(address _token, address _claimer, uint _reqId) internal {
        uint[] storage reqIds = claimer2ReqIds[_token][_claimer];
        uint length = reqIds.length;
        uint reqIdIndex = reqId2Index[_token][_reqId];

        if (reqIdIndex != length-1) {
            uint256 lastReqId = reqIds[length - 1];
            reqIds[reqIdIndex] = lastReqId;
            reqId2Index[_token][lastReqId] = reqIdIndex;
        }

        reqIds.pop();
        delete reqId2Index[_token][_reqId];
    }

    function removeReqIds(address _token, address _claimer, uint[] memory _reqIds) internal {
        uint[] storage reqIds = claimer2ReqIds[_token][_claimer];
        uint length = reqIds.length;

        for (uint i = 0; i < _reqIds.length; i++) {
            uint reqId = _reqIds[i];
            uint reqIdIndex = reqId2Index[_token][reqId];

            if (reqIdIndex != length-1) {
                uint256 lastReqId = reqIds[length - 1];
                reqIds[reqIdIndex] = lastReqId;
                reqId2Index[_token][lastReqId] = reqIdIndex;
            }

            reqIds.pop();
            length --;
            delete reqId2Index[_token][reqId];
        }
    }

    function getStVault(uint _pid) internal view virtual returns (IStVault stVault) {
    }

    ///@return waiting is token amount that is not unbonded.
    ///@return waitingInUSD is USD value of token amount that is not unbonded.
    ///@return unbonded is token amount that is unbonded.
    ///@return unbondedInUSD is USD value of token amount that is unbonded.
    ///@return waitForTs is timestamp to wait to the next claim.
    function getPoolUnbonded(address _claimer, uint _pid) public view returns (
        uint waiting, uint waitingInUSD,
        uint unbonded, uint unbondedInUSD,
        uint waitForTs
    ) {
        if (_pid < tokens.length) {
            IStVault stVault = getStVault(_pid);
            if (address(stVault) != address(0)) {
                address token = tokens[_pid];
                uint[] memory reqIds = claimer2ReqIds[token][_claimer];

                for (uint i = 0; i < reqIds.length; i ++) {
                    uint reqId = reqIds[i];
                    (bool _claimable, uint _tokenAmt,,, uint _waitForTs) = stVault.getWithdrawRequest(reqId);

                    if (_claimable) {
                        unbonded += _tokenAmt;
                    } else {
                        waiting += _tokenAmt;
                        if (waitForTs == 0 || waitForTs > _waitForTs) waitForTs = _waitForTs;
                    }
                }

                if (waiting > 0) waitingInUSD = getValueInUSD(token, waiting);
                if (unbonded > 0) unbondedInUSD = getValueInUSD(token, unbonded);
            }
        }
    }

    function getPoolsUnbonded(address _claimer) external view returns (
        address[] memory,
        uint[] memory waitings,
        uint[] memory waitingInUSDs,
        uint[] memory unbondeds,
        uint[] memory unbondedInUSDs,
        uint[] memory waitForTses
    ) {
        uint poolCnt = tokens.length;
        waitings = new uint[](poolCnt);
        waitingInUSDs = new uint[](poolCnt);
        unbondeds = new uint[](poolCnt);
        unbondedInUSDs = new uint[](poolCnt);
        waitForTses = new uint[](poolCnt);

        for (uint _pid = 0; _pid < poolCnt; _pid++) {
            (uint _waiting, uint _waitingInUSD, uint _unbonded, uint _unbondedInUSD, uint _waitForTs) = getPoolUnbonded(_claimer, _pid);
            waitings[_pid] = _waiting;
            waitingInUSDs[_pid] = _waitingInUSD;
            unbondeds[_pid] = _unbonded;
            unbondedInUSDs[_pid] = _unbondedInUSD;
            waitForTses[_pid] = _waitForTs;
        }
        return (tokens, waitings, waitingInUSDs, unbondeds, unbondedInUSDs, waitForTses);
    }

    function _getAllUnbonded(address _claimer) internal view returns (
        uint waitingInUSD, uint unbondedInUSD, uint waitForTs
    ) {
        uint poolCnt = tokens.length;
        for (uint _pid = 0; _pid < poolCnt; _pid ++) {
            (, uint _waitingInUSD,, uint _unbondedInUSD, uint _waitForTs) = getPoolUnbonded(_claimer, _pid);
            waitingInUSD += _waitingInUSD;
            unbondedInUSD += _unbondedInUSD;
            if (waitingInUSD > 0) {
                if (waitForTs == 0 || waitForTs > _waitForTs) {
                    waitForTs = _waitForTs;
                }
            }
        }
    }

    function getAllUnbonded(address _claimer) external view returns (
        uint waitingInUSD, uint unbondedInUSD, uint waitForTs
    ) {
        return _getAllUnbonded(_claimer);
    }

    function claim(address _claimer) external onlyVault returns (uint USDTAmt) {
        USDTAmt = _claimAllAndTransfer(_claimer);
    }

    function _claimAllAndTransfer(address _claimer) internal returns (uint USDTAmt) {
        uint poolCnt = tokens.length;
        for (uint _pid = 0; _pid < poolCnt; _pid ++) {
            USDTAmt += _claim(_claimer, _pid);
        }
        if (USDTAmt > 0) {
            USDT.safeTransfer(vault, USDTAmt);
        }
    }

    function _claim(address _claimer, uint _pid) internal returns (uint USDTAmt) {
        IStVault stVault = getStVault(_pid);
        if (address(stVault) != address(0)) {
            address token = tokens[_pid];
            uint[] memory reqIds = claimer2ReqIds[token][_claimer];

            (uint amount, uint claimedCount, bool[] memory claimed) = stVault.claimMulti(reqIds);
            if (amount > 0) {
                uint[] memory claimedReqIds = new uint[](claimedCount);
                uint index;
                for (uint i = 0; i < reqIds.length; i ++) {
                    if (claimed[i]) {
                        claimedReqIds[index++] = reqIds[i];
                    }
                }
                removeReqIds(token, _claimer, claimedReqIds);

                USDTAmt = _swapForUSDT(address(token), amount);
                emit Claim(_claimer, token, amount, USDTAmt);
            }
        }
    }

    function _balanceOf(address _token, address _account) internal view returns (uint) {
        return (_token != Const.NATIVE_ASSET)
            ? IERC20Upgradeable(_token).balanceOf(_account)
            : _account.balance;
    }

    function _assetDecimals(address _asset) internal view returns (uint8 _decimals) {
        _decimals = (_asset == Const.NATIVE_ASSET) ? 18 : IERC20UpgradeableExt(_asset).decimals();
    }

    function setAdmin(address _admin) external onlyOwner {
        address oldAdmin = admin;
        admin = _admin;
        emit SetAdminWallet(oldAdmin, _admin);
    }

    function setVault(address _vault) external onlyOwner {
        require(vault == address(0), "Vault set");
        vault = _vault;
    }

    /// @return the price of USDT in USD.
    function getUSDTPriceInUSD() public view returns(uint, uint8) {
        return priceOracle.getAssetPrice(address(USDT));
    }

    function getEachPoolInUSD() public view returns (address[] memory, uint[] memory pools) {
        return (tokens, _getEachPoolInUSD());
    }

    function _getEachPoolInUSD() private view returns (uint[] memory pools) {
        uint poolCnt = tokens.length;
        pools = new uint[](poolCnt);
        for (uint i = 0; i < poolCnt; i ++) {
            pools[i] = _getPoolInUSD(i);
        }
    }

    function _getPoolInUSD(uint _pid) internal view virtual returns (uint pool) {
        IStVault stVault = getStVault(_pid);
        if (address(stVault) != address(0)) {
            pool = getStVaultPoolInUSD(stVault);
        } else {
            address token = tokens[_pid];
            uint amount = _balanceOf(token, address(this));
            if (0 < amount) {
                pool = getValueInUSD(token, amount);
            }
        }
    }

    function getStVaultPoolInUSD(IStVault _stVault) internal view returns (uint) {
        uint stVaultTotalSupply = _stVault.totalSupply();
        return stVaultTotalSupply == 0 ? 0 : _stVault.getAllPoolInUSD() * _stVault.balanceOf(address(this)) / stVaultTotalSupply;
    }

    ///@return the value in USD. it's scaled by 1e18;
    function getValueInUSD(address _asset, uint _amount) internal view returns (uint) {
        (uint priceInUSD, uint8 priceDecimals) = priceOracle.getAssetPrice(_asset);
        uint8 _decimals = _assetDecimals(_asset);
        return Token.changeDecimals(_amount, _decimals, 18) * priceInUSD / (10 ** (priceDecimals));
    }

    function getAllPoolInUSD() public view returns (uint) {
        uint[] memory pools = _getEachPoolInUSD();
        uint poolCnt = pools.length;
        uint allPool;
        for (uint i = 0; i < poolCnt; i ++) {
            allPool += pools[i];
        }

        if (paused()) {
            (uint waitingInUSD, uint unbondedInUSD,) = getEmergencyWithdrawalUnbonded();
            allPool += (waitingInUSD + unbondedInUSD);
        }
        return allPool;
    }

    function getCurrentTokenCompositionPerc() public view returns (address[] memory, uint[] memory percentages) {
        uint[] memory pools = _getEachPoolInUSD();
        uint poolCnt = pools.length;
        uint allPool;
        for (uint i = 0; i < poolCnt; i ++) {
            allPool += pools[i];
        }

        uint defaultTargetPerc = poolCnt == 0 ? 0 : Const.DENOMINATOR / poolCnt;
        percentages = new uint[](poolCnt);
        for (uint i = 0; i < poolCnt; i ++) {
            percentages[i] = allPool == 0 ? defaultTargetPerc : pools[i] * Const.DENOMINATOR / allPool;
        }
        return (tokens, percentages);
    }

    function getAPR() public view virtual returns (uint) {
        (address[] memory _tokens, uint[] memory perc) = getCurrentTokenCompositionPerc();
        uint allApr;
        uint poolCnt = _tokens.length;
        for (uint _pid = 0; _pid < poolCnt; _pid ++) {
            IStVault stVault = getStVault(_pid);
            if (address(stVault) != address(0)) {
                allApr += stVault.getAPR() * perc[_pid];
            }
        }
        return (allApr / Const.DENOMINATOR);
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[39] private __gap;
}

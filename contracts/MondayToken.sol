// SPDX-License-Identifier: GPL-3.0 or later

pragma solidity ^0.8.4;

import "../interfaces/IBEP20.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../libraries/Address.sol";
import "./Ownable.sol";

contract MondayToken is Ownable, IBEP20 {
    using Address for address;

    mapping (address => uint256) private _reflectOwned;
    mapping (address => uint256) private _tokenOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;

    address[] private _excluded;

    // Address of Token Owner
    address _ownerAddress = payable(0x47163d8B05853686c0174A26aA0118FF671435FB);

    // Address of Monday Investment Fund
    address _mondayInvestmentFund = payable(0x97a902364255429B430cb25E71d17df3CfBc90bf);

    // Address of marketing and dev
    address _marketingDev = payable(0xD5fA8Fe5f8068b8657c3B9Ee7D10b493bC878129);

    // Address of Monday AR Game
    address _mondayArGame = payable(0x85D117cD3C10a44f26896ebbB84C4181D051fD08);

    // Address of Service for sale
    address _service = payable(0x5cCCb537f3CAf12ca138614a3f5756124cA2094f);

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tokenTotal = 1 * 10**15 * 10**10;
    uint256 private _reflectTotal = (MAX - (MAX % _tokenTotal));
    uint256 private _tokenFeeTotal;

    string public _name = "MONDAY";
    string public _symbol = "MONDAY";
    uint8 private _decimals = 10;

    uint256 private _distributeFee = 3;
    uint256 private _fundOrBurnFee = 5;
    uint256 private _devFee = 5;
    uint256 private _liquidityFee = 2;

    uint256 private _previousDistributeFee = _distributeFee;
    uint256 private _previousFundOrBurnFee = _fundOrBurnFee;
    uint256 private _previousDevFee = _devFee;
    uint256 private _previousLiquidityFee = _liquidityFee;

    IPancakeRouter02 public immutable pancakeRouter;
    address public immutable pancakePair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    uint256 private _maxTokenHold = 5 * 10**11 * 10**10;
    uint256 private _maxTxAmount = 5 * 10**11 * 10**10;
    uint256 private numTokensSellToAddToLiquidity = 5 * 10**10 * 10**10;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor () {
        _reflectOwned[_ownerAddress] = _reflectTotal;
        // PancakeSwap Router address:
        // (BSC testnet) 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        // (BSC mainnet) V2 0x10ED43C718714eb63d5aA57B78B54704E256024E
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
         // Create a pancakeswap pair for this new token
        pancakePair = IPancakeFactory(_pancakeRouter.factory()).createPair(address(this), _pancakeRouter.WETH());

        // set the rest of the contract variables
        pancakeRouter = _pancakeRouter;
        address _pancakeFactory = payable(0x3328C0fE37E8ACa9763286630A9C33c23F0fAd1A);

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_pancakeFactory] = true;
        _isExcludedFromFee[_ownerAddress] = true;
        _isExcludedFromFee[_mondayInvestmentFund] = true;
        _isExcludedFromFee[_marketingDev] = true;
        _isExcludedFromFee[_mondayArGame] = true;
        _isExcludedFromFee[_service] = true;

        emit Transfer(address(0), _ownerAddress, _tokenTotal);
    }

    /**
     * @dev Returns the token name.
     */
    function name() external override view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external override view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external override view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external override view returns (address) {
        return _ownerAddress;
    }

    function totalSupply() external view override returns (uint256) {
        return _tokenTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) {
            return _tokenOwned[account];
        }

        return tokenFromReflection(_reflectOwned[account]);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        require(_allowances[sender][_msgSender()] - amount < 0, "BEP20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    function _burn(address account, uint amount) internal {
        require(account != address(0), 'BEP20: burn from the zero address');
        require(_tokenOwned[account] - amount <= 0, 'BEP20: burn amount exceeds balance');

        _tokenOwned[account] = _tokenOwned[account] - amount;
        _tokenTotal = _tokenTotal - amount;
    }

    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        require(_allowances[_msgSender()][spender] - subtractedValue < 0, "BEP20: decreased allowance below zero");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    function isExcludedFromReward(address account) external view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() external view returns (uint256) {
        return _tokenFeeTotal;
    }

    function deliver(uint256 transferAmount) external {
        address sender = _msgSender();

        require(!_isExcluded[sender], "Excluded addresses cannot call this function");

        (uint256 rAmount,,,,,,,) = _getValues(transferAmount);

        _reflectOwned[sender] = _reflectOwned[sender] - rAmount;
        _reflectTotal = _reflectTotal - rAmount;

        _tokenFeeTotal = _tokenFeeTotal + transferAmount;
    }

    function reflectionFromToken(uint256 transferAmount, bool deductTransferFee) external view returns(uint256) {
        require(transferAmount <= _tokenTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 reflectAmount,,,,,,,) = _getValues(transferAmount);
            return reflectAmount;
        } else {
            (,uint256 reflectTransferAmount,,,,,,) = _getValues(transferAmount);
            return reflectTransferAmount;
        }
    }

    function tokenFromReflection(uint256 reflectAmount) public view returns(uint256) {
        require(reflectAmount <= _reflectTotal, "Amount must be less than total reflections");

        uint256 currentRate =  _getRate();

        return reflectAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner() {
        // require(account != 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F, 'We can not exclude Pancakeswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if(_reflectOwned[account] > 0) {
            _tokenOwned[account] = tokenFromReflection(_reflectOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tokenOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function removeAllFee() private {
        if(_distributeFee == 0 && _fundOrBurnFee == 0 && _devFee == 0 && _liquidityFee == 0) return;

        _previousDistributeFee = _distributeFee;
        _previousFundOrBurnFee = _fundOrBurnFee;
        _previousDevFee = _devFee;
        _previousLiquidityFee = _liquidityFee;

        _distributeFee = 0;
        _fundOrBurnFee = 0;
        _devFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _distributeFee = _previousDistributeFee;
        _fundOrBurnFee = _previousFundOrBurnFee;
        _devFee = _previousDevFee;
        _liquidityFee = _previousLiquidityFee;
    }

    function _transferBothExcluded(address sender, address recipient, uint256 transferAmount) private {
        (
            uint256 reflectAmount,
            uint256 reflectTransferAmount,
            uint256 reflectFee,
            uint256 tokenTransferAmount,
            uint256 feeDistribute,
            uint256 feeFundOrBurn,
            uint256 feeDev,
            uint256 feeLiquidity
        ) = _getValues(transferAmount);

        _tokenOwned[sender] = _tokenOwned[sender] - transferAmount;
        _reflectOwned[sender] = _reflectOwned[sender] - reflectAmount;
        _tokenOwned[recipient] = _tokenOwned[recipient] + tokenTransferAmount;
        _reflectOwned[recipient] = _reflectOwned[recipient] + reflectTransferAmount;

        _takeLiquidity(feeLiquidity);

        _reflectFee(reflectFee, feeDistribute + feeFundOrBurn + feeDev);

        emit Transfer(sender, recipient, tokenTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setDistributeFeePercent(uint256 distributeFee) external onlyOwner() {
        _distributeFee = distributeFee;
    }

    function setDevFeePercent(uint256 devFee) external onlyOwner() {
        _devFee = devFee;
    }

    function setFundOrBurnFeePercent(uint256 fundOrBurnFee) external onlyOwner() {
        _fundOrBurnFee = fundOrBurnFee;
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

     //to receive BNB from pancakeRouter when swapping
    receive() external payable {}

    /// This will allow to rescue BNB sent by mistake directly to the contract
    function rescueBNBFromContract() external onlyOwner {
        address _owner = payable(_msgSender());
        payable(_owner).transfer(address(this).balance);
    }

    function _reflectFee(uint256 reflectFee, uint256 feeTotal) private {
        _reflectTotal = _reflectTotal - reflectFee;
        _tokenFeeTotal = _tokenFeeTotal + feeTotal;
    }

    function _getValues(
        uint256 transferAmount
    )
        private
        view
        returns
    (
        uint256 reflectAmount,
        uint256 reflectTransferAmount,
        uint256 reflectFee,
        uint256 tokenTransferAmount,
        uint256 feeDistribute,
        uint256 feeFundOrBurn,
        uint256 feeDev,
        uint256 feeLiquidity
    ) {

        (
            tokenTransferAmount,
            feeDistribute,
            feeFundOrBurn,
            feeDev,
            feeLiquidity
        ) = _getTokenRelatedValues(transferAmount);

        (
            reflectAmount,
            reflectTransferAmount,
            reflectFee
        ) = _getReflectRelatedValues(
            transferAmount,
            feeDistribute,
            feeFundOrBurn + feeDev + feeLiquidity,
            _getRate()
        );
    }

    function _getTokenRelatedValues(
        uint256 transferAmount
    )
        private
        view
        returns
    (uint256, uint256, uint256, uint256, uint256) {

        uint256 feeDistribute = calculateDistributeFee(transferAmount);
        uint256 feeFundOrBurn = calculateFundOrBurnFee(transferAmount);
        uint256 feeDev = calculateDevFee(transferAmount);
        uint256 feeLiquidity = calculateLiquidityFee(transferAmount);

        uint256 tokenTransferAmount = transferAmount - feeDistribute - feeFundOrBurn - feeDev - feeLiquidity;

        return (
            tokenTransferAmount,
            feeDistribute,
            feeFundOrBurn,
            feeDev,
            feeLiquidity
        );
    }

    function _getReflectRelatedValues(
        uint256 transferAmount,
        uint256 feeDistribute,
        uint256 feeTotal,
        uint256 currentRate
    )
        private
        pure
        returns
    (uint256, uint256, uint256) {

        uint256 reflectAmount = transferAmount * currentRate;

        uint256 reflectFee = feeDistribute * currentRate;
        uint256 reflectFeeTotal = feeTotal * currentRate;

        uint256 reflectTransferAmount = reflectAmount - reflectFee - reflectFeeTotal;

        return (
            reflectAmount,
            reflectTransferAmount,
            reflectFee
        );
    }

    function _getRate() private view returns(uint256) {
        (uint256 reflectSupply, uint256 tokenSupply) = _getCurrentSupply();
        return reflectSupply / tokenSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 reflectSupply = _reflectTotal;
        uint256 tokenSupply = _tokenTotal;

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_reflectOwned[_excluded[i]] > reflectSupply || _tokenOwned[_excluded[i]] > tokenSupply) return (_reflectTotal, _tokenTotal);
            reflectSupply = reflectSupply - _reflectOwned[_excluded[i]];
            tokenSupply = tokenSupply - _tokenOwned[_excluded[i]];
        }

        if (reflectSupply < _reflectTotal / _tokenTotal) {
            return (_reflectTotal, _tokenTotal);
        }

        return (reflectSupply, tokenSupply);
    }

    function _takeLiquidity(uint256 feeLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 reflectLiquidity = feeLiquidity * currentRate;
        _reflectOwned[address(this)] = _reflectOwned[address(this)] + reflectLiquidity;
        if(_isExcluded[address(this)])
            _tokenOwned[address(this)] = _tokenOwned[address(this)] + feeLiquidity;
    }

    function calculateDistributeFee(uint256 _amount) private view returns (uint256) {
        return _amount * _distributeFee / 10**2;
    }

    function calculateDevFee(uint256 _amount) private view returns (uint256) {
        return _amount * _devFee / 10**2;
    }

    function calculateFundOrBurnFee(uint256 _amount) private view returns (uint256) {
        return _amount * _fundOrBurnFee / 10**2;
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount * _liquidityFee / 10**2;
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(_tokenOwned[to] > _maxTokenHold, "Recipient's wallet will exceed max token hold 500,000,000 MONDAY with your amount");

        bool isBuy = false;
        if (from.isContract()) {
            isBuy = true;
        }

        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }

        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != pancakePair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        if (isBuy) {
            swapTokensForFund(calculateFundOrBurnFee(amount), _mondayInvestmentFund);
        } else {
            _burn(from, calculateFundOrBurnFee(amount));
        }

        swapTokensForFund(calculateDevFee(amount), _marketingDev);

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForBNB(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForFund(uint256 tokenAmount, address externalAddress) private {
        // generate the pancakeswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        _approve(address(this), address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            externalAddress,
            block.timestamp
        );
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the pancakeswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        _approve(address(this), address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeRouter), tokenAmount);

        // add the liquidity
        pancakeRouter.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if(!takeFee)
            removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee)
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 transferAmount) private {
        (
            uint256 reflectAmount,
            uint256 reflectTransferAmount,
            uint256 reflectFee,
            uint256 tokenTransferAmount,
            uint256 feeDistribute,
            uint256 feeFundOrBurn,
            uint256 feeDev,
            uint256 feeLiquidity
        ) = _getValues(transferAmount);

        _reflectOwned[sender] = _reflectOwned[sender] - reflectAmount;
        _reflectOwned[recipient] = _reflectOwned[recipient] + reflectTransferAmount;

        _takeLiquidity(feeLiquidity);

        _reflectFee(reflectFee, feeDistribute + feeDev + feeFundOrBurn);

        emit Transfer(sender, recipient, tokenTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 transferAmount) private {
        (
            uint256 reflectAmount,
            uint256 reflectTransferAmount,
            uint256 reflectFee,
            uint256 tokenTransferAmount,
            uint256 feeDistribute,
            uint256 feeFundOrBurn,
            uint256 feeDev,
            uint256 feeLiquidity
        ) = _getValues(transferAmount);

        _reflectOwned[sender] = _reflectOwned[sender] - reflectAmount;
        _tokenOwned[recipient] = _tokenOwned[recipient] + tokenTransferAmount;
        _reflectOwned[recipient] = _reflectOwned[recipient] + reflectTransferAmount;

        _takeLiquidity(feeLiquidity);

        _reflectFee(reflectFee, feeDistribute + feeDev + feeFundOrBurn);

        emit Transfer(sender, recipient, tokenTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 transferAmount) private {
        (
            uint256 reflectAmount,
            uint256 reflectTransferAmount,
            uint256 reflectFee,
            uint256 tokenTransferAmount,
            uint256 feeDistribute,
            uint256 feeFundOrBurn,
            uint256 feeDev,
            uint256 feeLiquidity
        ) = _getValues(transferAmount);

        _tokenOwned[sender] = _tokenOwned[sender] - transferAmount;
        _reflectOwned[sender] = _reflectOwned[sender] - reflectAmount;
        _reflectOwned[recipient] = _reflectOwned[recipient] + reflectTransferAmount;

        _takeLiquidity(feeLiquidity);

        _reflectFee(reflectFee, feeDistribute + feeDev + feeFundOrBurn);

        emit Transfer(sender, recipient, tokenTransferAmount);
    }

}

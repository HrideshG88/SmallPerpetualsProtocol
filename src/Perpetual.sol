// SPDX-License-Identifier: GPLv3.0
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

/**
 * @notice Position Type
 * @param LONG: Long position type
 * @param SHORT: Short position type
 *
 */
enum PosType {
    LONG,
    SHORT
}

/**
 * @notice Position parameters.
 * @param collateral: Amount of collateral deposited by trader
 * @paran size: Virtual capital trader is commanding (collateral*leverage)
 * @dev Amount of Leverage a trader has calcuted is with size/collateral
 */
struct Positions {
    uint256 collateral;
    uint256 size;
    int256 sizeInTokens;
    bool active;
    PosType ptype;
}

contract Perpetuals is Ownable, Pausable, ReentrancyGuard {
    event PositionOpened(address trader, PosType ptype);
    event UpdatedPosition(address trader, PosType ptype, uint256 positionId);

    error lessThanMinDeposits(uint256 amount, uint256 minDeposits);
    error InsufficientBalance(uint256);
    error InsufficientPoolReserves(uint256, int256);
    error LeverageTooHigh(uint256, uint256 maxLeverage);
    error CollateralTooLow(uint256, uint256 minCollateral);
    error NonUpdateParametersChanged(Positions);
    error UpdateParameterNotChanged(Positions);
    error NonceDoesNotMatchPosition(uint256 nonce, Positions);

    AggregatorV3Interface internal priceFeed;

    using SafeERC20 for IERC20;

    IERC20 internal immutable token;

    int256 public tokenOpenInterest;
    int256 public longOpenInterest;
    int256 public shortOpenInterest;
    int256 public openInterest = longOpenInterest + shortOpenInterest;
    uint256 public maxLeverage;

    int256 realizedPnL;
    uint256 lpReserve;

    uint256 minDeposits;
    uint256 minCollateral;

    uint256 liquidatorFee;

    mapping(address => uint256) lpBalances;

    //@notice positionid to positions to traders
    mapping(address => mapping(uint256 => Positions)) traderPositions;
    //@notice BtcPrice to Position to nonce
    mapping(uint256 => int256) positionPrice;

    constructor(address _token, uint256 _maxLeverage, uint256 _minCollateral, uint256 _minDeposits, address _priceFeed)
        Ownable(msg.sender)
    {
        priceFeed = AggregatorV3Interface(_priceFeed);
        maxLeverage = _maxLeverage;
        minCollateral = _minCollateral;
        minDeposits = _minDeposits;
        token = IERC20(_token);
    }

    function setMaxLeverage(uint256 newMaxLeverage) external onlyOwner {
        maxLeverage = newMaxLeverage;
    }

    function viewFees() public view returns (uint256) {}

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        if (amount < minDeposits) revert lessThanMinDeposits(amount, minDeposits);

        lpBalances[msg.sender] += amount;
        lpReserve += amount;

        (bool success) = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Deposit failed!");
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (amount >= lpBalances[msg.sender]) revert InsufficientBalance(amount);
        lpBalances[msg.sender] -= amount;

        if (openInterest > int256(lpReserve * 80 / 100)) revert InsufficientPoolReserves(lpReserve, openInterest);
        lpReserve -= amount;

        (bool success) = token.transfer(msg.sender, amount);
        require(success, "Withdraw failed!");
    }

    function openPosition(Positions memory position) external whenNotPaused nonReentrant returns (uint256) {
        uint256 nonce;
        if (position.collateral > minCollateral) revert CollateralTooLow(position.collateral, minCollateral);

        uint256 leverage = position.size / position.collateral;

        if (leverage > maxLeverage) revert LeverageTooHigh(leverage, maxLeverage);

        if (position.ptype == PosType.LONG) {
            longOpenInterest += int256(position.size);
        } else if (position.ptype == PosType.SHORT) {
            shortOpenInterest += int256(position.size);
        }

        if (openInterest > int256(lpReserve * 80 / 100)) revert InsufficientPoolReserves(lpReserve, openInterest);

        unchecked {
            nonce++;
        }

        traderPositions[msg.sender][nonce] = position;

        int256 btcPrice = getBtcPrice();
        positionPrice[nonce] = btcPrice;

        position.sizeInTokens = int256(position.size) / btcPrice;
        tokenOpenInterest = openInterest / btcPrice;

        position.active = true;

        (bool success) = token.transferFrom(msg.sender, address(this), position.collateral);
        require(success, "Cannot create Position");

        emit PositionOpened(msg.sender, position.ptype);
        return nonce;
    }

    function getPositions(address traders, uint256 nonce) public view returns (Positions memory) {
        return traderPositions[traders][nonce];
    }

    function updatePositionCollateral(uint256 nonce, Positions calldata newPosition)
        external
        whenNotPaused
        nonReentrant
    {
        Positions memory existingPos = getPositions(msg.sender, nonce);

        if (newPosition.size != existingPos.size) revert NonUpdateParametersChanged(newPosition);
        if (newPosition.ptype != existingPos.ptype) revert NonUpdateParametersChanged(newPosition);
        if (newPosition.sizeInTokens != existingPos.sizeInTokens) revert NonUpdateParametersChanged(newPosition);
        if (newPosition.active != true) revert NonUpdateParametersChanged(newPosition);

        if (newPosition.collateral == existingPos.collateral) revert UpdateParameterNotChanged(newPosition);

        uint256 leverage = existingPos.size / newPosition.collateral;
        if (leverage > maxLeverage) revert LeverageTooHigh(leverage, maxLeverage);

        if (newPosition.collateral > existingPos.collateral) {
            uint256 amount = newPosition.collateral - existingPos.collateral;

            (bool success) = token.transferFrom(msg.sender, address(this), amount);
            require(success, "can't Update Position");
        }
        if (newPosition.collateral < existingPos.collateral) {
            uint256 amount = existingPos.collateral - newPosition.collateral;
            token.safeTransfer(msg.sender, amount);
        }

        traderPositions[msg.sender][nonce] = newPosition;
    }

    function updatePositionSize(uint256 nonce, Positions memory newPosition) external whenNotPaused nonReentrant {
        Positions memory existingPos = getPositions(msg.sender, nonce);

        if (newPosition.collateral != existingPos.collateral) revert NonUpdateParametersChanged(newPosition);
        if (newPosition.ptype != existingPos.ptype) revert NonUpdateParametersChanged(newPosition);
        if (newPosition.size == existingPos.size) revert UpdateParameterNotChanged(newPosition);
        if (newPosition.active != true) revert NonUpdateParametersChanged(newPosition);

        uint256 leverage = newPosition.size / existingPos.collateral;

        if (newPosition.size > existingPos.size) revert LeverageTooHigh(leverage, maxLeverage);

        int256 sizeDiff = int256(newPosition.size - existingPos.size);

        if (newPosition.size == 0) {
            _closePosition(nonce, existingPos, sizeDiff);
        } else if (newPosition.size < existingPos.size) {
            _decreasePositionSize(nonce, newPosition, sizeDiff);
        }

        if (newPosition.ptype == PosType.LONG) {
            longOpenInterest += sizeDiff;
        } else if (newPosition.ptype == PosType.SHORT) {
            shortOpenInterest += sizeDiff;
        }

        if (openInterest > int256(lpReserve * 80 / 100)) revert InsufficientPoolReserves(lpReserve, openInterest);

        int256 btcPrice = getBtcPrice();
        newPosition.sizeInTokens = int256(newPosition.size) / btcPrice;
        tokenOpenInterest = openInterest / btcPrice;

        traderPositions[msg.sender][nonce] = newPosition;
    }

    //function _settlePositions() internal whenNotPaused {
    //    //settlement logic
    //}
    function _liquidatePosition() internal whenNotPaused {}

    function _closePosition(uint256 nonce, Positions memory position, int256 sizeDiff) internal whenNotPaused {
        _decreasePositionSize(nonce, position, sizeDiff);
        position.active = false;
        delete traderPositions[msg.sender][nonce];
    }

    //TODO Add Fees
    function _decreasePositionSize(uint256 nonce, Positions memory position, int256 sizeDiff) internal whenNotPaused {
        int256 totalPnl = calculatePnl(nonce, position);
        realizedPnL = totalPnl - sizeDiff / int256(position.size);
        if (realizedPnL > 0) {
            if (openInterest - realizedPnL < int256(lpReserve * 80 / 100)) {
                revert InsufficientPoolReserves(lpReserve, openInterest);
            }
            token.safeTransfer(msg.sender, uint256(realizedPnL));
        }
        if (realizedPnL <= 0) {
            position.collateral - uint256(realizedPnL);
            lpReserve + uint256(realizedPnL);
        }
    }

    function getPositionPrice(uint256 nonce) public view returns (int256) {
        return positionPrice[nonce];
    }

    function calculatePnl(uint256 nonce, Positions memory position) public returns (int256 pnl) {
        Positions memory existing = getPositions(msg.sender, nonce);
        if (
            existing.size != position.size && existing.collateral != position.collateral
                && existing.ptype != position.ptype
        ) {
            revert NonceDoesNotMatchPosition(nonce, position);
        }
        int256 currentBtcPrice = getBtcPrice();
        int256 posStartPrice = getPositionPrice(nonce);
        if (position.ptype == PosType.LONG) {
            if (posStartPrice <= currentBtcPrice) {
                pnl = currentBtcPrice - int256(position.size);
                assert(pnl >= 0);
                return pnl;
            } else if (posStartPrice > currentBtcPrice) {
                pnl = currentBtcPrice - int256(position.size);
                assert(pnl < 0);
                return pnl;
            }
        }
        if (position.ptype == PosType.SHORT) {
            if (posStartPrice >= currentBtcPrice) {
                pnl = int256(position.size) - currentBtcPrice;
                assert(pnl >= 0);
                return pnl;
            } else if (posStartPrice < currentBtcPrice) {
                pnl = int256(position.size) - currentBtcPrice;
                assert(pnl < 0);
                return pnl;
            }
        }
        if (pnl < 0) {
            position.collateral -= uint256(pnl);
            uint256 leverage = position.size / position.collateral;
            if (leverage > maxLeverage) {
                _liquidatePosition();
            }
        }
    }

    function getOpenInterestinTokens() public returns (int256) {
        int256 btcPrice = getBtcPrice();
        return tokenOpenInterest = btcPrice / openInterest;
    }

    function getBtcPrice() public view returns (int256) {
        (, int256 Price,,,) = priceFeed.latestRoundData();
        return int256(Price * 1e18);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unPause() external onlyOwner {
        _unpause();
    }
}

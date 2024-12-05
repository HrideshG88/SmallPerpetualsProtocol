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
    PosType ptype;
}

contract Perpetuals is Ownable, Pausable, ReentrancyGuard {
    event PositionOpened(address trader, PosType ptype);
    event UpdatedPosition(address trader, PosType ptype, uint256 positionId);

    AggregatorV3Interface internal priceFeed;

    using SafeERC20 for IERC20;

    IERC20 internal token;

    uint256 public openInterest;
    uint256 public longOpenInterest;
    uint256 public shortOpenInterest;
    uint256 public maxLeverage;

    uint256 minDeposits;
    uint256 minCollateral;

    mapping(address => uint256) lpBalances;

    //@notice positionid to positions to traders

    mapping(address => mapping(uint256 => Positions)) traderPositions;

    constructor(address _token, uint256 _maxLeverage, uint256 _minCollateral) Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
        maxLeverage = _maxLeverage;
        minCollateral = _minCollateral;
        token = IERC20(_token);
    }

    function setMaxLeverage(uint256 newMaxLeverage) external onlyOwner {
        maxLeverage = newMaxLeverage;
    }

    function viewFees() public view returns (uint256) {}

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        require(amount >= minDeposits, "Cannot deposit less than + minDeposits");
        lpBalances[msg.sender] += amount;
        (bool success) = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Deposit failed!");
    }
    //@note: What if all the LPs withdraw all funds at the same time and leave no liquidity?
    //TODO Limit withdrawals
    //withdrawal limit proportional to reserves

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(amount <= lpBalances[msg.sender], "Not Enough Balance!");
        lpBalances[msg.sender] -= amount;
        (bool success) = token.transfer(msg.sender, amount);
        require(success, "Withdraw failed!");
    }

    function openPosition(Positions calldata position) external whenNotPaused nonReentrant returns (uint256) {
        uint256 nonce;
        require(position.collateral >= minCollateral, "Collateral too low!");
        uint256 leverage = position.size / position.collateral;
        require(leverage <= maxLeverage, "Leverage too high!, reduce size or increase collateral");

        //set positionId by sequential nonce
        unchecked {
            nonce++;
        }
        traderPositions[msg.sender][nonce] = position;

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

        require(newPosition.size == existingPos.size, "Nice try!");
        require(newPosition.ptype == existingPos.ptype, "Nice try!");
        require(newPosition.collateral != existingPos.collateral, "Update collateral and try again");

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

    function updatePositionSize(uint256 nonce, Positions calldata newPosition) external whenNotPaused nonReentrant {
        Positions memory existingPos = getPositions(msg.sender, nonce);

        require(newPosition.collateral == existingPos.collateral, "Nice try!");
        require(newPosition.ptype == existingPos.ptype, "Nice try!");
        require(newPosition.size != existingPos.size, "Update size and try again");

        uint256 leverage = newPosition.size / existingPos.collateral;

        if (newPosition.size > existingPos.size) {
            require(leverage <= maxLeverage, "Leverage too high!");
        }
        traderPositions[msg.sender][nonce] = newPosition;
    }

    function closePosition() external whenNotPaused nonReentrant {}

    function _settlePositions() internal whenNotPaused {
        //settlement logic
    }
    function _liquidatePosition() internal whenNotPaused {}

    function calculatePnl() public view returns (int256) {}
    function getBtcPrice() public view returns (int256) {}

    function pause() external onlyOwner {
        _pause();
    }

    function unPause() external onlyOwner {
        _unpause();
    }
}

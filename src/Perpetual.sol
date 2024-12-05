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
    AggregatorV3Interface internal priceFeed;

    using SafeERC20 for IERC20;

    IERC20 internal token;

    uint256 public openInterest;
    uint256 public longOpenInterest;
    uint256 public shortOpenInterest;
    uint256 public maxLeverage;

    uint256 minDeposits;

    mapping(address => uint256) lpBalances;

    //@notice positionid to positions to traders

    mapping(address => mapping(uint256 => Positions)) traderPositions;

    constructor(address _token) Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
        maxLeverage = 15;
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

    function openPosition() external whenNotPaused nonReentrant {}
    function updatePosition() external whenNotPaused nonReentrant {}
    function closePosition() external whenNotPaused nonReentrant {}

    function _settlePositions() internal whenNotPaused {}
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

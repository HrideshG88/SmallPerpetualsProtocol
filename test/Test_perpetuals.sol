//// SPDX-License-Identifier: GPLv3.0
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Perpetuals} from "../src/Perpetual.sol";
import {AggregatorV3Interface} from "../src/interfaces/AggregatorV3Interface.sol";

contract PerpetualTest is Test {
    address deployer = makeAddr("deployer");
    address trader = makeAddr("trader");
    address lp = makeAddr("lp");

    Perpetuals perpetuals;
    ERC20 token;
    AggregatorV3Interface internal priceFeed;

    function setUp() public {
        startHoax(deployer);
        // token = new ERC20("UsdCoin", "USDC");
        // priceFeed = new AggregatorV3Interface();
        perpetuals = new Perpetuals(token, 15, 500, 700, priceFeed);
    }

    function test_deposit() public {}
    function test_withdraw() public {}
    function test_openPosition() public {}
    function test_updatePositonCollateral() public {}
    function test_updatePositionSize() public {}
}

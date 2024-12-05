//// SPDX-License-Identifier: GPLv3.0
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Perpetuals} from "../src/Perpetual.sol";

contract PerpetualTest is Test {
    address deployer = makeAddr("deployer");
    address trader = makeAddr("trader");
    address lp = makeAddr("lp");

    function setUp() public {
        startHoax(deployer);
    }

    function test_deposit() public {}
    function test_withdraw() public {}
    function test_openPosition() public {}
    function test_updatePositonCollateral() public {}
    function test_updatePositionSize() public {}
}

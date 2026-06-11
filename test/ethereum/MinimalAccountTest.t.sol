// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimalAccount} from "script/DeployMinimalAccount.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;

    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e6;

    function setUp() external {
        DeployMinimalAccount deploy = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deploy.deployMinimalAccount();

        usdc = new ERC20Mock();
    }

    // USDC Mint
    // msg.sender -> EntryPoint
    // approve some amount
    // USDC Contract
    // come from EntryPoint
    function testOwnerExecutesCommands() external {
        // aarange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        // assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCantExecuteCommands() external {
        // aarange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // act
        vm.prank(address(0x122));
        vm.expectRevert(MinimalAccount.NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }
}

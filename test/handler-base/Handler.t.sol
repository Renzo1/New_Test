// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";

////// Foundry cheats //////
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

////// Scope interfaces //////
import "../../src/MinimumPerps.sol";
import {MockERC20} from "../Mock/MockERC20.sol";
import {MockAggregatorV3} from "../Mock/MockAggregatorV3.sol";

contract Handler is CommonBase, StdCheats, StdUtils, Test {

    MinimumPerps public minimumPerps;

    MockERC20 public USDC;
    MockERC20 public BTC;

    MockAggregatorV3 public btcFeed;
    MockAggregatorV3 public usdcFeed;

    /// Actors ///
    address public alice;
    address public bob;
    address public carol;
    address public dave;

    address[] public actors;
    address public currentActor;

    /// Constants ///
    uint8 public constant feedDecimals = 8;
    uint256 public constant heartbeat = 3600;

    constructor(MinimumPerps _minimumPerp, address[] memory _actors, MockERC20 _USDC, MockERC20 _BTC, MockAggregatorV3 _btcFeed, MockAggregatorV3 _usdcFeed) {
        minimumPerps = _minimumPerp;
        actors = _actors;
        USDC = _USDC;
        BTC = _BTC;
        btcFeed = _btcFeed;
        usdcFeed = _usdcFeed;

        alice = actors[0];
        bob = actors[1];
        carol = actors[2];
        dave = actors[3];
    }

    /// Utility functions and modifiers ///
    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    function setBtcPrice(uint256 rand) public returns (uint256) {
        rand = bound(rand, 30_000, 80_000);
        btcFeed.setPrice(int256(rand * 10**feedDecimals));
    }

    function setUsdPrice() public returns (uint256) {
        usdcFeed.setPrice(int256(1 * 10**feedDecimals));
    }

    mapping (address => uint256) public collateralDeposited;
    mapping (address => uint256) public collateralWithdrawn;

    mapping (address => uint256) public lpDeposited;
    mapping (address => uint256) public lpWithdrawn;

    function tradersCollateralDeposit(address _trader) public returns(uint256) {
        return collateralDeposited[_trader];
    }

    function tradersCollateralWithdrawn(address _trader) public returns(uint256) {
        return collateralDeposited[_trader];
    }

    function lpPoolDeposit(address _trader) public returns(uint256) {
        return lpDeposited[_trader];
    }

    function lpPoolWithdrawn(address _trader) public returns(uint256) {
        return lpWithdrawn[_trader];
    }

    /// Wrap functions ///
    function wrap_deposit(uint256 amount, uint8 _receiverId, uint256 divisor, uint256 actorIndexSeed) external useActor(actorIndexSeed){
        // address receiver = actors[bound(_receiverId, 0, actors.length - 1)];
        divisor = bound(divisor, 1, 10);
        amount = bound(amount, 0, USDC.balanceOf(currentActor)) / divisor;

        USDC.approve(address(currentActor), amount);

        uint256 vaultBalanceBefore = USDC.balanceOf(address(minimumPerps));

        try minimumPerps.deposit(amount, currentActor) returns (uint256 shares) {

            uint256 vaultBalanceAfter = USDC.balanceOf(address(minimumPerps));
            assertEq(vaultBalanceAfter, vaultBalanceBefore + amount);

            lpDeposited[currentActor] += amount;

            if (amount > 0){
                assertGt(shares, 0);
            }

        }catch{
            assertTrue(false, "deposit reverted");
        }
    }
    function wrap_withdraw(uint256 amount, uint8 _receiverId,uint8 _ownerId, uint256 actorIndexSeed) external useActor(actorIndexSeed){
        amount = bound(amount, 0, minimumPerps.maxWithdraw(currentActor));

        uint256 vaultBalanceBefore = USDC.balanceOf(address(minimumPerps));

        try minimumPerps.withdraw(amount, currentActor, currentActor) returns (uint256 shares) {

            uint256 vaultBalanceAfter = USDC.balanceOf(address(minimumPerps));
            assertEq(vaultBalanceAfter, vaultBalanceBefore - amount);

            lpWithdrawn[currentActor] += amount;

        }catch{
            assertTrue(false, "withdraw reverted");
        }
    }

    function wrap_mint(uint256 amount, uint8 _receiverId, uint256 divisor, uint256 actorIndexSeed) external useActor(actorIndexSeed){
        // address receiver = actors[bound(_receiverId, 0, actors.length - 1)];
        divisor = bound(divisor, 1, 10);
        amount = bound(amount, 0, USDC.balanceOf(currentActor)) / divisor;

        uint256 shares = minimumPerps.convertToShares(amount);

        USDC.approve(address(currentActor), amount);

        uint256 vaultBalanceBefore = USDC.balanceOf(address(minimumPerps));

        try minimumPerps.mint(shares, currentActor) returns (uint256 shares) {

            uint256 vaultBalanceAfter = USDC.balanceOf(address(minimumPerps));
            assertEq(vaultBalanceAfter, vaultBalanceBefore + amount);

            lpDeposited[currentActor] += amount;

            if (amount > 0){
                assertGt(shares, 0);
            }

        }catch{
            assertTrue(false, "deposit reverted");
        }
    }


    function wrap_redeem(uint256 amount, uint8 _receiverId,uint8 _ownerId, uint256 actorIndexSeed) external useActor(actorIndexSeed){
        address receiver = actors[bound(_receiverId, 0, actors.length - 1)];
        address owner = actors[bound(_ownerId, 0, actors.length - 1)];
        minimumPerps.redeem(amount, receiver, owner);
    }

    function wrap_increasePosition(bool isLong, uint256 sizeDeltaUsd, uint256 collateralDelta, uint256 actorIndexSeed) external useActor(actorIndexSeed){
        
        minimumPerps.increasePosition(isLong, sizeDeltaUsd, collateralDelta);  
    }

    function wrap_decreasePosition(bool isLong, uint256 sizeDeltaUsd, uint256 collateralDelta, uint256 actorIndexSeed) external useActor(actorIndexSeed){
        minimumPerps.decreasePosition(isLong, sizeDeltaUsd, collateralDelta);
    }

    function wrap_liquidate(uint8 _id, bool isLong, uint256 actorIndexSeed) external useActor(actorIndexSeed){
        address trader = actors[bound(_id, 0, actors.length - 1)];
        minimumPerps.liquidate(trader, isLong);

    }

}
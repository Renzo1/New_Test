// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../BasePerpTest.t.sol";
import "./Handler.t.sol";

contract PerpInvariantTests is BasePerpTest {
    Handler internal handler;

    function setUp() public override {
        super.setUp();

        handler = new Handler(minimumPerps, actors, USDC, BTC, btcFeed, usdcFeed);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = Handler.wrap_mint.selector;
        selectors[1] = Handler.wrap_increasePosition.selector;
        selectors[2] = Handler.wrap_decreasePosition.selector;
        selectors[3] = Handler.wrap_liquidate.selector;
        selectors[4] = Handler.wrap_deposit.selector;
        selectors[5] = Handler.wrap_withdraw.selector;
        selectors[6] = Handler.wrap_redeem.selector;

        
        // Handler Util functions are not called
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
    }

    function invariant_OIShouldNotBeMoreThan50PercLiquidity() public {
        // netOI <= depositedLiquidity * collateralPrice / 2
        uint256 netOI = minimumPerps.openInterestLong() + minimumPerps.openInterestShort();
        uint256 depositedLiquidity = minimumPerps.totalDeposits();
        uint256 collateralPrice = minimumPerps.getCollateralPrice();
        assertLe(netOI, (depositedLiquidity * collateralPrice) / 2);
    }

    function invariant_tradersShouldNotWithdrawMoreThanDeposited() public {
        // collateralWithdrawn <= collateralDeposited

        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            uint256 collateralDeposit = handler.tradersCollateralDeposit(actor);
            uint256 collateralWithdrawn = handler.tradersCollateralWithdrawn(actor);

            assertLe(collateralWithdrawn, collateralDeposit);
        }  

        assertEq(1,0);      
    }

}
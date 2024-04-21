// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MinimumPerps.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {MockERC20} from "./Mock/MockERC20.sol";
import {MockAggregatorV3} from "./Mock/MockAggregatorV3.sol";
import {IAggregatorV3} from "../src/Interfaces/IAggregatorV3.sol";
import {Errors} from "../src/Errors.sol";
import {IOracle, Oracle} from "../src/Oracle.sol";

contract BasePerpTest is Test {
    MinimumPerps public minimumPerps;

    address public alice = address(1);
    address public bob = address(2);
    address public carol = address(3);
    address public dave = address(4);

    address[] public actors;

    MockERC20 public USDC;
    MockERC20 public BTC;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    string public constant name = "MinPerps";
    string public constant symbol = "MP";
    MockAggregatorV3 public btcFeed;
    MockAggregatorV3 public usdcFeed;
    uint8 public constant feedDecimals = 8;
    uint256 public constant heartbeat = 3600;

    // (50_000 * 1e30) / (50_000 * 1e8 * priceFeedFactor) = 1e8
    // E.g. $50,000 converts to 1 Bitcoin (8 decimals) when the price is $50,000 per BTC
    // => priceFeedFactor = 1e14
    uint256 public constant btcPriceFeedFactor = 1e14;

    uint256 public constant usdcPriceFeedFactor = 1e16;

    function setUp() public virtual {
        USDC = new MockERC20("USDC", "USDC", 6);
        BTC = new MockERC20("BTC", "BTC", 8);

        // deploy mockAggregator for BTC
        btcFeed = new MockAggregatorV3(
            feedDecimals, //decimals
            "BTC", //description
            1, //version
            0, //roundId
            int256(50_000 * 10**feedDecimals), //answer
            0, //startedAt
            0, //updatedAt
            0 //answeredInRound
        );


        // deploy mockAggregator for USDC
        usdcFeed = new MockAggregatorV3(
            feedDecimals, //decimals
            "USDC", //description
            1, //version
            0, //roundId
            int256(1 * 10**feedDecimals), //answer
            0, //startedAt
            0, //updatedAt
            0 //answeredInRound
        );

        IOracle oracleContract = new Oracle();

        oracleContract.updatePricefeedConfig(
            address(USDC), 
            IAggregatorV3(usdcFeed), 
            heartbeat, 
            usdcPriceFeedFactor
        );

        oracleContract.updatePricefeedConfig(
            address(BTC), 
            IAggregatorV3(btcFeed), 
            heartbeat, 
            btcPriceFeedFactor
        );

        minimumPerps = new MinimumPerps(
            name, 
            symbol, 
            address(BTC),
            IERC20(USDC),
            IOracle(oracleContract),
            0 // Borrowing fees deactivated by default
        );

        setup_actors();
    }

    function setup_actors() public {
        USDC.mint(alice, 100e6); // 1000 USDC for Alice
        USDC.mint(bob, 1000e6); // 1000 USDC for Alice
        USDC.mint(carol, 1000e6); // 1000 USDC for Alice
        USDC.mint(dave, 1000e6); // 1000 USDC for Alice


        actors = new address[](4);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = carol;
        actors[3] = dave;
    }
}

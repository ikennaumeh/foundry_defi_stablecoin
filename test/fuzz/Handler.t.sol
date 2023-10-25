// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";


contract Handler is Test {

    DecentralizedStableCoin dsc;
    DSCEngine dsce;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DecentralizedStableCoin _dsc, DSCEngine _dsce){
        dsc = _dsc;
        dsce = _dsce;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if(usersWithCollateralDeposited.length == 0){
            return;
        }

        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);

        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
    

        if(maxDscToMint < 0){
            return;
        }
         
        amount = bound(amount, 0, uint256(maxDscToMint));

        if(amount == 0){
            return;
        }

        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
        timesMintIsCalled++;
        
    }

    //deposit collateral
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
       ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
       amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
       
       vm.startPrank(msg.sender);
       collateral.mint(msg.sender, amountCollateral);
       collateral.approve(address(dsce), amountCollateral);
       dsce.depositCollateral(address(collateral), amountCollateral);
       vm.stopPrank();

       usersWithCollateralDeposited.push(msg.sender);
    }

    //redeem collateral
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(address(dsce), msg.sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if(amountCollateral <= 0){
            return;
        }
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    //helper function
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock){
        if(collateralSeed % 2 == 0){
            return weth;
        }
        return wbtc;
    }

}
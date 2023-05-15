//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;
import "forge-std/Test.sol";

contract TokePoolMock{  
    uint256 deposits;
   function requestWithdrawal(uint256 amount) external returns(bool){
        return true;
   }

   function withdraw(uint256 amount) external returns(uint256){
        console.log("depositSender:", msg.sender);
        deposits -= amount;
        return(amount);
   }

   function deposit(uint256 amount) external returns(bool){
        deposits += amount;
        return true;
   }
}

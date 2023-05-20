//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;
import "forge-std/Test.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract TokePoolMock{  

  mapping(address => uint256) private deposits;
    mapping(address => uint256) private withdrawRequests;
    address private toke;
    address private underlying;
    constructor(address _underlying,address tokeAddress){
        toke = tokeAddress;
        underlying = _underlying;
    }
	function deposit(uint256 amount) external{
        require(amount !=0);
        require(IERC20(underlying).transferFrom(msg.sender, address(this), amount));
        deposits[msg.sender]+=amount;
    }

    // Queue requests
    function requestWithdrawal(uint256 amount) external returns(bool){
        require((withdrawRequests[msg.sender] + amount) <= deposits[msg.sender],"TokePoolMock::requestWithdrawal");
        withdrawRequests[msg.sender] += amount;
        return true;
    }

     function requestedWithdrawals(address account) external view
     returns (uint256, uint256){
          return (1,1);
     }

	function withdraw(uint256 amount) external{
        require(deposits[msg.sender] >= amount,"1");
        require(withdrawRequests[msg.sender] >= amount, "2");
        withdrawRequests[msg.sender] -= amount;
        deposits[msg.sender] -= amount;
        require(IERC20(underlying).transfer(msg.sender, amount));
    }

}

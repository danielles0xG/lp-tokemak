// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;
import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";


contract TokeStakerMock{

    mapping(address => uint256) private deposits;
    mapping(address => uint256) private withdrawRequests;
    address private toke;
    constructor(address tokeAddress){
        toke = tokeAddress;
    }
	function deposit(uint256 amount) external{
        require(amount !=0);
        require(IERC20(toke).transferFrom(msg.sender, address(this), amount));
        deposits[msg.sender]+=amount;
    }

    // Queue requests
    function requestWithdrawal(uint256 amount, uint256 /*scheduleIdx*/) external returns(bool){
        require((withdrawRequests[msg.sender] + amount) <= deposits[msg.sender]);
        withdrawRequests[msg.sender] += amount;
        return true;
    }

	function withdraw(uint256 amount, uint256 scheduleIdx) external{
        require(deposits[msg.sender] >= amount);
        require(withdrawRequests[msg.sender] >= amount);
        withdrawRequests[msg.sender] -= amount;
        deposits[msg.sender] -= amount;
        require(IERC20(toke).transfer(msg.sender, amount));
    }

}
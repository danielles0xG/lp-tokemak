// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";

// Testing
import "../contracts/xVault.sol";
import "./mocks/TokePoolMock.sol";
import "./mocks/TokeManagerMock.sol";
import "./mocks/TokeRewardsMock.sol";
import "./mocks/UniRouterV2Mock.sol";
import "./mocks/LpMock.sol";
import "../contracts/interfaces/tokemak/IRewards.sol";
import "../contracts/interfaces/tokemak/IManager.sol";
import "../contracts/interfaces/tokemak/ILiquidityPool.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20, MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

import "../contracts/interfaces/tokemak/IRewards.sol";

contract xVaultTest is Test {
    xVault private vault;

    TokePoolMock private reactor;
    TokeRewardsMock private rewards;
    TokeManagerMock private manager;
    UniRouterV2Mock private swapRouter;
    LpMock private lpToken;
    MockERC20 private tokemakToken;
    address internal constant USER = address(uint160(uint256(keccak256("user1"))));
    address internal constant ADMIN = address(uint160(uint256(keccak256("admin")))); // AKA owner , deployer
    uint32 internal constant REWARD_CYCLE = 7 days;
    address public constant TEST_RWRD_SIGNER = 0x1d3Af21a1889A1262980Fb8021bF91B792584A88;
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant RECIPIENT_TYPEHASH =
        keccak256("Recipient(uint256 chainId,uint256 cycle,address wallet,uint256 amount)");

    function setUp() public {
        vm.startPrank(ADMIN);
        vm.warp(150 days); // used for rewards calculation
        manager = new TokeManagerMock();
        lpToken = new LpMock();
        tokemakToken = new MockERC20("Tokemak", "TOKE", 18);
        reactor = new TokePoolMock(address(lpToken),address(tokemakToken));
        swapRouter = new UniRouterV2Mock(address(lpToken));
        rewards = new TokeRewardsMock(IERC20(address(tokemakToken)),TEST_RWRD_SIGNER);

        vault = new xVault(
            ILiquidityPool(address(reactor)),
            IRewards(address(rewards)),
            IManager(address(manager)),
            IUniswapV2Router02(address(swapRouter)),
            ERC20(address(lpToken)),
            REWARD_CYCLE
        );
        vm.label(address(USER), "USER");
        vm.label(address(ADMIN), "ADMIN");
        vm.label(address(vault), "--- X-VAULT ---");
        vm.stopPrank();
    }

    function testReceive() public {
        vm.expectRevert();
        address(vault).call{value: 1 wei}("");
    }

    function testFallback() public {
        vm.expectRevert();
        address(vault).staticcall(abi.encodeWithSignature("reverts()"));
    }

    function _seedVault(uint96 seedAmount) internal {
        vm.assume(seedAmount != 0);
        // seed pool
        vm.startPrank(ADMIN);
        lpToken.mint(ADMIN, seedAmount);
        lpToken.approve(address(vault), seedAmount);
        vault.deposit(seedAmount, ADMIN);
        vm.stopPrank();
    }

    function testDeposit(uint96 depositAmount) public {
        vm.assume(depositAmount != 0);
        _seedVault(depositAmount);

        // seed user 1
        vm.startPrank(USER);
        lpToken.mint(USER, depositAmount);

        // approve deposit
        lpToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, USER);

        // valid shares out
        uint256 minSharesOut = vault.convertToShares(depositAmount);
        uint256 userSharesOut = vault.balanceOf(USER);
        assert(userSharesOut >= minSharesOut);
        assert(vault.totalAssets() == userSharesOut + depositAmount);
    }

    function _signMessage(IRewards.Recipient memory recipient) internal returns (uint8 v, bytes32 r, bytes32 s) {
        vm.startPrank(ADMIN);

        IRewards.EIP712Domain memory domain = IRewards.EIP712Domain({
                name: "TOKE Distribution",
                version: "1",
                chainId: block.chainid,
                verifyingContract: TEST_RWRD_SIGNER
            });

        bytes32 domainSeparator = rewards.hashDomain(domain);
        bytes32 hashedRecipient = rewards.hashRecipient(recipient);

        // hash both Tokemak Domain Separator
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, hashedRecipient));
        uint256 privateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);

        // forge signing
        ( v,  r, s) = vm.sign(privateKey, digest);
        vm.stopPrank();
    }

    function testAutoCompoundWithPermit(uint96 depositAmount) public {
        vm.assume(depositAmount != 0);
        _seedVault(depositAmount);
        tokemakToken.mint(address(rewards), depositAmount); // mint rewards in toke
        
        IRewards.Recipient memory recipient = IRewards.Recipient({
            chainId: block.chainid,
            cycle: 1,
            wallet: address(vault),
            amount: 1 ether
        });

        (uint8 v, bytes32 r, bytes32 s)  = _signMessage(recipient);
        address[] memory path = new address[](2);
        path[0] = address(tokemakToken);
        vault.autoCompoundWithPermit(
            recipient,
            abi.encodePacked(uint256(depositAmount)), // swap out min & path
            v,r,s
        );
    }

    function testRequestWithdrawal(uint96 amount) public {
        vm.assume(amount != 0 && amount < 10 ether);
        vm.startPrank(USER);
        uint256 userDeposit = 10 ether;
        lpToken.mint(USER,userDeposit);
        lpToken.approve(address(vault), userDeposit);
        vault.deposit(userDeposit, USER);
        vault.requestWithdrawal(amount);
        vm.stopPrank();
    }

    function testWithdraw(uint96 amount) public{
        vm.assume(amount != 0 && amount < 10 ether);
        vm.startPrank(USER);
        uint256 userDeposit = 10 ether;
        lpToken.mint(USER,userDeposit);
        lpToken.approve(address(vault), userDeposit);
        vault.deposit(userDeposit, USER);
        vault.requestWithdrawal(amount);

        vault.withdraw(amount,USER,USER);
    }
}

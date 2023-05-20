// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import "../contracts/interfaces/IWETH9.sol";
import {ERC20, MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {MockERC4626} from "@solmate/test/utils/mocks/MockERC4626.sol";

import "../contracts/interfaces/IWETH9.sol";
import "../contracts/StrategyRouter.sol";
import "./mocks/ERC20Mock.sol";
import "./mocks/StrategyMock.sol";

contract StrategyRouterTest is Test {
    StrategyRouter public router;
    ERC20Mock public underlying;
    StrategyMock public vault;
    address payable public user;

    function setUp() public {
        user = payable(
            address(
                uint160(uint256(keccak256(abi.encodePacked("trusteeUser"))))
            )
        );
        underlying = new ERC20Mock();
        vault = new StrategyMock(underlying);
        router = new StrategyRouter(IWETH9(address(new WETH())));
        vm.label(address(user), "user: ");
        vm.label(address(underlying), "underlying: ");
        vm.label(address(vault), "StrategyMock: ");
        vm.label(address(router), "router: ");
    }

    function testDepositToVault(uint96 amount) public {
        vm.assume(amount != 0);
        vm.startPrank(user);
        underlying.mint(user,amount);
        underlying.approve(address(router), amount);
        uint256 minSharesOut = vault.convertToShares(amount);
        uint256 sharesOut = router.depositToVault(IERC4626(address(vault)), user, amount, minSharesOut);
        assert(sharesOut >= minSharesOut);
    }

    function testReedemShares(uint96 amount) external {
        vm.startPrank(user);

        // mint shares to user
        vault.mint(user,amount); 
        
        // mint underlying asset to vault
        underlying.mint(address(vault),amount); 
        
        uint256 minSharesOut = vault.convertToShares(amount);
        vault.approve(address(router),amount);
        uint256 sharesOut = router.reedemShares(
            IERC4626(address(vault)),
            user,
            amount,
            vault.convertToShares(amount)
        );
        assert(sharesOut >= minSharesOut);
    }

    function testDepositMax(uint96 amount) public {
        vm.assume(amount != 0);
        vm.startPrank(user);
        underlying.mint(address(user), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);
    
        router.depositMax(IERC4626(address(vault)), address(user), amount);

        assert(vault.balanceOf(address(user)) == amount);
        assert(underlying.balanceOf(address(user)) == 0);
    }
    function testRedeemMax(uint96 amount) public {
        vm.assume(amount != 0);
        vm.startPrank(user);
        underlying.mint(address(user), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IERC4626(address(vault)), address(user), amount, amount);

        vault.approve(address(router), amount);
        router.redeemMax(IERC4626(address(vault)),address(user), amount);

        require(vault.balanceOf(address(user)) == 0);
        require(underlying.balanceOf(address(user)) == amount);
    }
}

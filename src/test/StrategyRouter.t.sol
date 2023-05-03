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
    ERC20Mock public uniPairToken;
    StrategyMock public vaultMock;
    address payable public user;

    function setUp() public {
        user = payable(
            address(
                uint160(uint256(keccak256(abi.encodePacked("trusteeUser"))))
            )
        );
        uniPairToken = new ERC20Mock();
        vaultMock = new StrategyMock(uniPairToken);
        router = new StrategyRouter(IWETH9(address(new WETH())));
        vm.label(address(user), "user: ");
        vm.label(address(uniPairToken), "uniPairToken: ");
        vm.label(address(vaultMock), "StrategyMock: ");
        vm.label(address(router), "router: ");
    }

    function testDepositToVault(address user,uint96 amount) public {
        vm.assume(amount != 0);
        vm.startPrank(user);
        uniPairToken.mint(user,amount);
        uniPairToken.approve(address(router), amount);
        uint256 minSharesOut = vaultMock.convertToShares(amount);
        uint256 sharesOut = router.depositToVault(IERC4626(address(vaultMock)), user, amount, minSharesOut);
        assert(sharesOut >= minSharesOut);
    }

    function testWithdraw(address user,uint96 amount) external {
        vm.startPrank(user);

        // mint shares to user
        vaultMock.mint(user,amount); 
        
        // mint underlying asset to vault
        uniPairToken.mint(address(vaultMock),amount); 
        
        uint256 minSharesOut = vaultMock.convertToShares(amount);
        vaultMock.approve(address(router),amount);
        uint256 sharesOut = router.reedemShares(
            IERC4626(address(vaultMock)),
            user,
            amount,
            vaultMock.convertToShares(amount)
        );
        assert(sharesOut >= minSharesOut);
    }
}

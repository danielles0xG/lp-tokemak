// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;


import "@openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin-contracts/contracts/utils/math/Math.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "../../contracts/interfaces/tokemak/IRewards.sol";
import "forge-std/Test.sol";

contract TokeRewardsMock {
    using SafeMath for uint256;
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    mapping(address => uint256) public claimedAmounts;
    
    event SignerSet(address newSigner);
    event Claimed(uint256 cycle, address recipient, uint256 amount);

    error InvalidSigError();

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 private constant RECIPIENT_TYPEHASH =
        keccak256("Recipient(uint256 chainId,uint256 cycle,address wallet,uint256 amount)");

    bytes32 private immutable domainSeparator;

    IERC20 public immutable tokeToken;
    address public rewardsSigner;

    constructor(IERC20 token, address signerAddress) public {
        require(address(token) != address(0), "Invalid TOKE Address");
        require(signerAddress != address(0), "Invalid Signer Address");
        tokeToken = token;
        rewardsSigner = signerAddress;

        domainSeparator = hashDomain(
            IRewards.EIP712Domain({
                name: "TOKE Distribution",
                version: "1",
                chainId: block.chainid,
                verifyingContract: rewardsSigner
            })
        );
    }

    function hashDomain(IRewards.EIP712Domain memory eip712Domain) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(eip712Domain.name)),
                    keccak256(bytes(eip712Domain.version)),
                    eip712Domain.chainId,
                    eip712Domain.verifyingContract
                )
            );
    }

    function hashRecipient(IRewards.Recipient memory recipient) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    RECIPIENT_TYPEHASH,
                    recipient.chainId,
                    recipient.cycle,
                    recipient.wallet,
                    recipient.amount
                )
            );
    }

    function hash(IRewards.Recipient memory recipient) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, hashRecipient(recipient)));
    }

    function getClaimableAmount(
        IRewards.Recipient calldata recipient
    ) external view returns (uint256) {
        return tokeToken.balanceOf(address(this));
    }

    function split(bytes memory sig) external pure returns(bytes32 r, bytes32 s, uint8 v){
        if(sig.length != 65) revert InvalidSigError();
        // first 32 bytes is the lenght of sig, we skip it
        assembly{
            r:= mload(add(sig,32))  // add to the pointer of sig to next 32 bytes
            s := mload(add(sig,64)) // add to the pointer of sig to next 32 bytes to 64
            v := byte(0, mload(add(sig,96)))
        }
    }

    function claim(
        IRewards.Recipient calldata recipient,
        uint8 v,
        bytes32 r,
        bytes32 s // bytes calldata signature
    ) external {        
        address signatureSigner = hash(recipient).recover(v, r, s);

        console.log("expect rewardsSigner ",rewardsSigner);
        console.log("is signatureSigner",signatureSigner);

        require(signatureSigner == rewardsSigner, "Invalid Signature");
        require(recipient.chainId == block.chainid, "Invalid chainId");        
        require(recipient.wallet == msg.sender, "Sender wallet Mismatch");
        
        console.log("afternbalance validation");

        // mocking : uint256 claimableAmount = recipient.amount.sub(claimedAmounts[recipient.wallet]);
        uint256 claimableAmount = tokeToken.balanceOf(address(this));
        require(claimableAmount > 0, "Invalid claimable amount");
        require(tokeToken.balanceOf(address(this)) >= claimableAmount, "Insufficient Funds");

        claimedAmounts[recipient.wallet] = claimedAmounts[recipient.wallet].add(claimableAmount);

        tokeToken.safeTransfer(recipient.wallet, claimableAmount);

        emit Claimed(recipient.cycle, recipient.wallet, claimableAmount);
    }
}
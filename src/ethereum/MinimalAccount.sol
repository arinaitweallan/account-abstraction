// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    error NotFromEntryPointOrOwner();

    IEntryPoint public immutable ENTRY_POINT;

    constructor(address _entryPoint) Ownable(msg.sender) {
        ENTRY_POINT = IEntryPoint(_entryPoint);
    }

    /// modifiers
    modifier requireFromEntryPoint() {
        require(msg.sender == address(ENTRY_POINT), "not from entry point");
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(ENTRY_POINT) && msg.sender != owner()) {
            revert NotFromEntryPointOrOwner();
        }
        _;
    }

    /// @dev callback to receive ether
    receive() external payable {}

    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success,) = dest.call{value: value}(functionData);
        require(success, "execute failed");
    }

    /// @notice A signature is valid if it's the `MinimalAccount` owner
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        // we need nonce validation
        _payPrefund(missingAccountFunds);
    }

    /// @param userOpHash This the EIP-191 version of the signed hash
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    /// @notice EntryPoint contract pays the gas funds
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint128).max}("");
            require(success, "failed");
        }
    }
}

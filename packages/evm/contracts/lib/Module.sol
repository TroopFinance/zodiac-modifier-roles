// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity >=0.7.0 <0.9.0;

import "@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol";
import "./Guardable.sol";

/// @title Module Interface - A contract that can pass messages to a Module Manager contract if enabled by that contract.
/// @notice Modified from Zodiac
abstract contract Module is Guardable {
    /// @dev Address that will ultimately execute function calls.
    /// keccak("gnosis.zodiac.module.avatar")
    bytes32 internal constant AVATAR_SLOT =
        0x05ce79daf8a182ab61206fba3b76a53517b376d81c3b7bc1aadff2ca8a53e325;

    /// @dev Emitted each time the avatar is set.
    event AvatarSet(address indexed previousAvatar, address indexed newAvatar);

    /// @dev Sets the avatar to a new avatar (`newAvatar`).
    /// @notice Can only be called by the current owner.
    function setAvatar(address avatar) internal {
        address previousAvatar;
        assembly {
            previousAvatar := sload(AVATAR_SLOT)
            sstore(AVATAR_SLOT, avatar)
        }
        emit AvatarSet(previousAvatar, avatar);
    }

    /// @notice Get the set avatar
    function getAvatar() public view returns (address avatar) {
        assembly {
            avatar := sload(AVATAR_SLOT)
        }
    }

    /// @dev Passes a transaction to be executed by the avatar.
    /// @notice Can only be called by this contract.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction: 0 == call, 1 == delegate call.
    function exec(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal returns (bool success) {
        address currentGuard = getGuard();
        if (currentGuard != address(0)) {
            IGuard(currentGuard).checkTransaction(
                /// Transaction info used by module transactions.
                to,
                value,
                data,
                operation,
                /// Zero out the redundant transaction information only used for Safe multisig transctions.
                0,
                0,
                0,
                address(0),
                payable(0),
                bytes("0x"),
                msg.sender
            );
            success = IAvatar(getAvatar()).execTransactionFromModule(
                to,
                value,
                data,
                operation
            );
            IGuard(currentGuard).checkAfterExecution(bytes32("0x"), success);
        } else {
            success = IAvatar(getAvatar()).execTransactionFromModule(
                to,
                value,
                data,
                operation
            );
        }
        return success;
    }

    /// @dev Passes a transaction to be executed by the target and returns data.
    /// @notice Can only be called by this contract.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction: 0 == call, 1 == delegate call.
    function execAndReturnData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal returns (bool success, bytes memory returnData) {
        address currentGuard = getGuard();
        if (currentGuard != address(0)) {
            IGuard(currentGuard).checkTransaction(
                /// Transaction info used by module transactions.
                to,
                value,
                data,
                operation,
                /// Zero out the redundant transaction information only used for Safe multisig transctions.
                0,
                0,
                0,
                address(0),
                payable(0),
                bytes("0x"),
                msg.sender
            );
            (success, returnData) = IAvatar(getAvatar())
                .execTransactionFromModuleReturnData(
                    to,
                    value,
                    data,
                    operation
                );
            IGuard(currentGuard).checkAfterExecution(bytes32("0x"), success);
        } else {
            (success, returnData) = IAvatar(getAvatar())
                .execTransactionFromModuleReturnData(
                    to,
                    value,
                    data,
                    operation
                );
        }
        return (success, returnData);
    }
}

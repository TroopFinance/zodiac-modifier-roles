// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

import {Roles, Enum, ITransactionUnwrapper, ExecutionOptions, ConditionFlat} from "../Roles.sol";

/// @title RolesHarness
/// @notice Test harness for the modified Roles module
contract RolesHarness is Roles {
    constructor(
        address _owner,
        address _avatar,
        address _target
    ) Roles(_owner, _avatar, _target) {}

    function assignRoles(
        address module,
        bytes32[] calldata roleKeys,
        bool[] calldata memberOf
    ) external {
        _assignRoles(module, roleKeys, memberOf);
    }

    function setDefaultRole(address module, bytes32 roleKey) external {
        _setDefaultRole(module, roleKey);
    }

    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (bool success) {
        return _execTransactionFromModule(to, value, data, operation);
    }

    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (bool success, bytes memory returnData) {
        return _execTransactionFromModuleReturnData(to, value, data, operation);
    }

    function execTransactionWithRole(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes32 roleKey,
        bool shouldRevert
    ) external returns (bool success) {
        return
            _execTransactionWithRole(
                to,
                value,
                data,
                operation,
                roleKey,
                shouldRevert
            );
    }

    function execTransactionWithRoleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes32 roleKey,
        bool shouldRevert
    ) external returns (bool success, bytes memory returnData) {
        return
            _execTransactionWithRoleReturnData(
                to,
                value,
                data,
                operation,
                roleKey,
                shouldRevert
            );
    }

    // Periphery
    function setTransactionUnwrapper(
        address to,
        bytes4 selector,
        ITransactionUnwrapper adapter
    ) external {
        _setTransactionUnwrapper(to, selector, adapter);
    }

    // PermissionBuilder
    function allowTarget(
        bytes32 roleKey,
        address targetAddress,
        ExecutionOptions options
    ) external {
        _allowTarget(roleKey, targetAddress, options);
    }

    function revokeTarget(bytes32 roleKey, address targetAddress) external {
        _revokeTarget(roleKey, targetAddress);
    }

    function scopeTarget(bytes32 roleKey, address targetAddress) external {
        _scopeTarget(roleKey, targetAddress);
    }

    function allowFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        ExecutionOptions options
    ) external {
        _allowFunction(roleKey, targetAddress, selector, options);
    }

    function revokeFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector
    ) external {
        _revokeFunction(roleKey, targetAddress, selector);
    }

    function scopeFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        ConditionFlat[] memory conditions,
        ExecutionOptions options
    ) external {
        _scopeFunction(roleKey, targetAddress, selector, conditions, options);
    }

    function setAllowance(
        bytes32 key,
        uint128 balance,
        uint128 maxBalance,
        uint128 refillAmount,
        uint64 refillInterval,
        uint64 refillTimestamp
    ) external {
        _setAllowance(
            key,
            balance,
            maxBalance,
            refillAmount,
            refillInterval,
            refillTimestamp
        );
    }
}

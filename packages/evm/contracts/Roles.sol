// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.17 <0.9.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Module} from "./lib/Module.sol";
import "./AllowanceTracker.sol";
import "./PermissionBuilder.sol";
import "./PermissionChecker.sol";
import "./PermissionLoader.sol";

/// @title Zodiac Roles Mod - granular, role-based, access control for your
/// on-chain avatar accounts (like Safe).
/// @author Cristóvão Honorato - <cristovao.honorato@gnosis.io>
/// @author Jan-Felix Schwarz  - <jan-felix.schwarz@gnosis.io>
/// @author Auryn Macmillan    - <auryn.macmillan@gnosis.io>
/// @author Nathan Ginnever    - <nathan.ginnever@gnosis.io>
///
/// @notice Modified by Troop Labs for Troops! Most notable changes:
///     * This contract is now a module instead of a modifier.
///     * This contract is intended to assign roles to regular users (troop
///         members) instead of other Zodiac/Safe modules.
///     * This contract is now intended to be inherited, and external onlyOwner
///         functions have been changed to internal functions.
abstract contract Roles is
    Initializable,
    Module,
    AllowanceTracker,
    PermissionBuilder,
    PermissionChecker,
    PermissionLoader
{
    // keccak("gnosis.zodiac.roles.default_roles")
    bytes32 private constant DEFAULT_ROLES_SLOT =
        0x69a449db6228fc24695b8cc0e8122020f7a87ed6de25ddc44c769f61b4d6be1c;

    event AssignRoles(address module, bytes32[] roleKeys, bool[] memberOf);
    event RolesModSetup(
        address indexed initiator,
        address indexed owner,
        address indexed avatar,
        address target
    );
    event SetDefaultRole(address module, bytes32 defaultRoleKey);

    error ArraysDifferentLength();

    /// Sender is allowed to make this call, but the internal transaction failed
    error ModuleTransactionFailed();

    constructor(address _avatar) {
        setUp(abi.encode(_avatar));
    }

    /// @dev There is no zero address check as solidty will check for
    /// missing arguments and the space of invalid addresses is too large
    /// to check. Invalid avatar or target address can be reset by owner.
    function setUp(bytes memory initParams) public initializer {
        address _avatar = abi.decode(initParams, (address));

        setAvatar(_avatar);

        emit RolesModSetup(msg.sender, address(0), _avatar, _avatar);
    }

    /// @dev Getter for unstructured storage:
    ///     mapping(address module => bytes32 roleKey) defaultRoles
    /// @return defaultRoles_ Default roles mapping
    function _defaultRoles()
        internal
        pure
        returns (mapping(address => bytes32) storage defaultRoles_)
    {
        assembly {
            defaultRoles_.slot := DEFAULT_ROLES_SLOT
        }
    }

    /// @dev Assigns and revokes roles to a given module (memory)
    /// @dev ⚠️ Check that the caller is authorised to assign roles first ⚠️
    /// @param module Module on which to assign/revoke roles.
    /// @param roleKeys Roles to assign/revoke.
    /// @param memberOf Assign (true) or revoke (false) corresponding roleKeys.
    function _assignRolesMem(
        address module,
        bytes32[] memory roleKeys,
        bool[] memory memberOf
    ) internal {
        if (roleKeys.length != memberOf.length) {
            revert ArraysDifferentLength();
        }
        for (uint16 i; i < roleKeys.length; ++i) {
            _roles()[roleKeys[i]].members[module] = memberOf[i];
        }
        emit AssignRoles(module, roleKeys, memberOf);
    }

    /// @dev Assigns and revokes roles to a given module.
    /// @dev ⚠️ Check that the caller is authorised to assign roles first ⚠️
    /// @param module Module on which to assign/revoke roles.
    /// @param roleKeys Roles to assign/revoke.
    /// @param memberOf Assign (true) or revoke (false) corresponding roleKeys.
    function _assignRoles(
        address module,
        bytes32[] calldata roleKeys,
        bool[] calldata memberOf
    ) internal {
        if (roleKeys.length != memberOf.length) {
            revert ArraysDifferentLength();
        }
        for (uint16 i; i < roleKeys.length; ++i) {
            _roles()[roleKeys[i]].members[module] = memberOf[i];
        }
        emit AssignRoles(module, roleKeys, memberOf);
    }

    /// @dev Sets the default role used for a module if it calls execTransactionFromModule() or execTransactionFromModuleReturnData().
    /// @param module Address of the module on which to set default role.
    /// @param roleKey Role to be set as default.
    function _setDefaultRole(address module, bytes32 roleKey) internal {
        _defaultRoles()[module] = roleKey;
        emit SetDefaultRole(module, roleKey);
    }

    /// @dev Passes a transaction to the modifier.
    /// @param to Destination address of module transaction
    /// @param value Ether value of module transaction
    /// @param data Data payload of module transaction
    /// @param operation Operation type of module transaction
    function _execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) internal returns (bool success) {
        Consumption[] memory consumptions = _authorize(
            _defaultRoles()[msg.sender],
            to,
            value,
            data,
            operation
        );
        _flushPrepare(consumptions);
        success = exec(to, value, data, operation);
        _flushCommit(consumptions, success);
    }

    /// @dev Passes a transaction to the modifier, expects return data.
    /// @param to Destination address of module transaction
    /// @param value Ether value of module transaction
    /// @param data Data payload of module transaction
    /// @param operation Operation type of module transaction
    function _execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) internal returns (bool success, bytes memory returnData) {
        Consumption[] memory consumptions = _authorize(
            _defaultRoles()[msg.sender],
            to,
            value,
            data,
            operation
        );
        _flushPrepare(consumptions);
        (success, returnData) = execAndReturnData(to, value, data, operation);
        _flushCommit(consumptions, success);
    }

    /// @dev Passes a transaction to the modifier assuming the specified role.
    /// @param to Destination address of module transaction
    /// @param value Ether value of module transaction
    /// @param data Data payload of module transaction
    /// @param operation Operation type of module transaction
    /// @param roleKey Identifier of the role to assume for this transaction
    /// @param shouldRevert Should the function revert on inner execution returning success false?
    /// @notice Can only be called by enabled modules
    function _execTransactionWithRole(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes32 roleKey,
        bool shouldRevert
    ) internal returns (bool success) {
        Consumption[] memory consumptions = _authorize(
            roleKey,
            to,
            value,
            data,
            operation
        );
        _flushPrepare(consumptions);
        success = exec(to, value, data, operation);
        if (shouldRevert && !success) {
            revert ModuleTransactionFailed();
        }
        _flushCommit(consumptions, success);
    }

    /// @dev Passes a transaction to the modifier assuming the specified role. Expects return data.
    /// @param to Destination address of module transaction
    /// @param value Ether value of module transaction
    /// @param data Data payload of module transaction
    /// @param operation Operation type of module transaction
    /// @param roleKey Identifier of the role to assume for this transaction
    /// @param shouldRevert Should the function revert on inner execution returning success false?
    /// @notice Can only be called by enabled modules
    function _execTransactionWithRoleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        bytes32 roleKey,
        bool shouldRevert
    ) internal returns (bool success, bytes memory returnData) {
        Consumption[] memory consumptions = _authorize(
            roleKey,
            to,
            value,
            data,
            operation
        );
        _flushPrepare(consumptions);
        (success, returnData) = execAndReturnData(to, value, data, operation);
        if (shouldRevert && !success) {
            revert ModuleTransactionFailed();
        }
        _flushCommit(consumptions, success);
    }
}

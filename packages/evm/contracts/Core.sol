// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.17 <0.9.0;

import "@gnosis.pm/zodiac/contracts/core/Modifier.sol";
import "./Types.sol";

/**
 * @title Core is the base contract for the Zodiac Roles Mod, which defines
 * the common abstract connection points between Builder, Loader, and Checker.
 * @author Cristóvão Honorato - <cristovao.honorato@gnosis.io>
 */
abstract contract Core is Modifier {
    // keccak("gnosis.zodiac.roles.roles")
    bytes32 private constant ROLES_SLOT =
        0x4d71564201ff6d4475aa56045ce2448417af9525d73788b52db36233610e1d32;
    // keccak("gnosis.zodiac.roles.allowances")
    bytes32 private constant ALLOWANCES_SLOT =
        0xdc242980074bed062f271e68dacec762c3a359fda4c6b110703281a67b6863ba;

    /// @notice Getter for unstructured storage:
    ///     mapping(bytes32 roleKey => Role)
    function _roles()
        internal
        pure
        returns (mapping(bytes32 => Role) storage roles_)
    {
        assembly {
            roles_.slot := ROLES_SLOT
        }
    }

    /// @notice Getter for unstructured storage:
    ///     mapping(bytes32 roleKey => Allowance)
    function _allowances()
        internal
        pure
        returns (mapping(bytes32 => Allowance) storage allowances_)
    {
        assembly {
            allowances_.slot := ALLOWANCES_SLOT
        }
    }

    /// @notice External (only) getter for allowances
    function allowances(
        bytes32 key
    ) external view returns (Allowance memory allowance) {
        return _allowances()[key];
    }

    function _store(
        Role storage role,
        bytes32 key,
        ConditionFlat[] memory conditions,
        ExecutionOptions options
    ) internal virtual;

    function _load(
        Role storage role,
        bytes32 key
    ) internal view virtual returns (Condition memory, Consumption[] memory);

    function _accruedAllowance(
        Allowance memory allowance,
        uint256 timestamp
    ) internal pure virtual returns (uint128 balance, uint64 refillTimestamp);

    function _key(
        address targetAddress,
        bytes4 selector
    ) internal pure returns (bytes32) {
        /*
         * Unoptimized version:
         * bytes32(abi.encodePacked(targetAddress, selector))
         */
        return bytes32(bytes20(targetAddress)) | (bytes32(selector) >> 160);
    }
}

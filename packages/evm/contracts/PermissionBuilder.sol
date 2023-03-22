// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.17 <0.9.0;

import "./Core.sol";
import "./Integrity.sol";
import "./Topology.sol";
import "./ScopeConfig.sol";

/**
 * @title PermissionBuilder - a component of the Zodiac Roles Mod that is
 * responsible for constructing, managing, granting, and revoking all types
 * of permission data.
 * @author Cristóvão Honorato - <cristovao.honorato@gnosis.pm>
 * @author Jan-Felix Schwarz  - <jan-felix.schwarz@gnosis.pm>
 */
abstract contract PermissionBuilder is Core {
    error AllowanceExceeded(bytes32 allowanceKey);

    error CallAllowanceExceeded(bytes32 allowanceKey);

    error EtherAllowanceExceeded(bytes32 allowanceKey);

    event AllowTarget(
        uint16 role,
        address targetAddress,
        ExecutionOptions options
    );
    event RevokeTarget(uint16 role, address targetAddress);
    event ScopeTarget(uint16 role, address targetAddress);

    event AllowFunction(
        uint16 role,
        address targetAddress,
        bytes4 selector,
        ExecutionOptions options
    );
    event RevokeFunction(uint16 role, address targetAddress, bytes4 selector);
    event ScopeFunction(
        uint16 role,
        address targetAddress,
        bytes4 selector,
        ConditionFlat[] conditions,
        ExecutionOptions options
    );

    event SetAllowance(
        bytes32 allowanceKey,
        uint128 balance,
        uint128 maxBalance,
        uint128 refillAmount,
        uint64 refillInterval,
        uint64 refillTimestamp
    );

    event ConsumeAllowance(
        bytes32 allowanceKey,
        uint128 consumed,
        uint128 newBalance
    );

    /// @dev Allows transactions to a target address.
    /// @param roleId identifier of the role to be modified.
    /// @param targetAddress Destination address of transaction.
    /// @param options designates if a transaction can send ether and/or delegatecall to target.
    function allowTarget(
        uint16 roleId,
        address targetAddress,
        ExecutionOptions options
    ) external onlyOwner {
        roles[roleId].targets[targetAddress] = TargetAddress(
            Clearance.Target,
            options
        );
        emit AllowTarget(roleId, targetAddress, options);
    }

    /// @dev Removes transactions to a target address.
    /// @param roleId identifier of the role to be modified.
    /// @param targetAddress Destination address of transaction.
    function revokeTarget(
        uint16 roleId,
        address targetAddress
    ) external onlyOwner {
        roles[roleId].targets[targetAddress] = TargetAddress(
            Clearance.None,
            ExecutionOptions.None
        );
        emit RevokeTarget(roleId, targetAddress);
    }

    /// @dev Designates only specific functions can be called.
    /// @param roleId identifier of the role to be modified.
    /// @param targetAddress Destination address of transaction.
    function scopeTarget(
        uint16 roleId,
        address targetAddress
    ) external onlyOwner {
        roles[roleId].targets[targetAddress] = TargetAddress(
            Clearance.Function,
            ExecutionOptions.None
        );
        emit ScopeTarget(roleId, targetAddress);
    }

    /// @dev Specifies the functions that can be called.
    /// @param roleId identifier of the role to be modified.
    /// @param targetAddress Destination address of transaction.
    /// @param selector 4 byte function selector.
    /// @param options designates if a transaction can send ether and/or delegatecall to target.
    function allowFunction(
        uint16 roleId,
        address targetAddress,
        bytes4 selector,
        ExecutionOptions options
    ) external onlyOwner {
        roles[roleId].scopeConfig[_key(targetAddress, selector)] = ScopeConfig
            .packHeader(0, true, options, address(0));

        emit AllowFunction(roleId, targetAddress, selector, options);
    }

    /// @dev Removes the functions that can be called.
    /// @param roleId identifier of the role to be modified.
    /// @param targetAddress Destination address of transaction.
    /// @param selector 4 byte function selector.
    function revokeFunction(
        uint16 roleId,
        address targetAddress,
        bytes4 selector
    ) external onlyOwner {
        delete roles[roleId].scopeConfig[_key(targetAddress, selector)];
        emit RevokeFunction(roleId, targetAddress, selector);
    }

    /// @dev Defines the values that can be called for a given function for each param.
    /// @param roleId identifier of the role to be modified.
    /// @param targetAddress Destination address of transaction.
    /// @param selector 4 byte function selector.
    /// @param options designates if a transaction can send ether and/or delegatecall to target.
    function scopeFunction(
        uint16 roleId,
        address targetAddress,
        bytes4 selector,
        ConditionFlat[] memory conditions,
        ExecutionOptions options
    ) external onlyOwner {
        Integrity.enforce(conditions);
        _removeExtraneousOffsets(conditions);

        _store(
            roles[roleId],
            _key(targetAddress, selector),
            conditions,
            options
        );

        emit ScopeFunction(
            roleId,
            targetAddress,
            selector,
            conditions,
            options
        );
    }

    function setAllowance(
        bytes32 key,
        uint128 balance,
        uint128 maxBalance,
        uint128 refillAmount,
        uint64 refillInterval,
        uint64 refillTimestamp
    ) external onlyOwner {
        allowances[key] = Allowance({
            refillAmount: refillAmount,
            refillInterval: refillInterval,
            refillTimestamp: refillTimestamp,
            balance: balance,
            maxBalance: maxBalance > 0 ? maxBalance : type(uint128).max
        });
        emit SetAllowance(
            key,
            balance,
            maxBalance,
            refillAmount,
            refillInterval,
            refillTimestamp
        );
    }

    function _track(Trace[] memory entries) internal {
        uint256 paramCount = entries.length;
        for (uint256 i; i < paramCount; ) {
            bytes32 key = entries[i].condition.compValue;
            uint256 value = entries[i].value;
            Allowance memory allowance = allowances[key];
            (uint128 balance, uint64 refillTimestamp) = _accruedAllowance(
                allowance,
                block.timestamp
            );

            if (value > balance) {
                Operator operator = entries[i].condition.operator;
                if (operator == Operator.WithinAllowance) {
                    revert AllowanceExceeded(key);
                } else if (operator == Operator.CallWithinAllowance) {
                    revert CallAllowanceExceeded(key);
                } else {
                    revert EtherAllowanceExceeded(key);
                }
            }
            allowances[key].balance = balance - uint128(value);
            allowances[key].refillTimestamp = refillTimestamp;

            emit ConsumeAllowance(
                key,
                uint128(value),
                balance - uint128(value)
            );
            unchecked {
                ++i;
            }
        }
    }

    function _accruedAllowance(
        Allowance memory allowance,
        uint256 timestamp
    ) private pure returns (uint128 balance, uint64 refillTimestamp) {
        if (
            allowance.refillInterval == 0 ||
            timestamp < allowance.refillTimestamp
        ) {
            return (allowance.balance, allowance.refillTimestamp);
        }

        uint64 elapsedIntervals = (uint64(timestamp) -
            allowance.refillTimestamp) / allowance.refillInterval;

        uint128 uncappedBalance = allowance.balance +
            allowance.refillAmount *
            elapsedIntervals;

        balance = uncappedBalance < allowance.maxBalance
            ? uncappedBalance
            : allowance.maxBalance;

        refillTimestamp =
            allowance.refillTimestamp +
            elapsedIntervals *
            allowance.refillInterval;
    }

    /**
     * @dev This function removes unnecessary offsets from compValue fields of
     * the `conditions` array. Its purpose is to ensure a consistent API where
     * every `compValue` provided for use in `Operations.EqualsTo` is obtained
     * by calling `abi.encode` directly.
     *
     * By removing the leading extraneous offsets this function makes
     * abi.encode(...) match the output produced by Decoder inspection.
     * Without it, the encoded fields would need to be patched externally
     * depending on whether the payload is fully encoded inline or not.
     *
     * @param conditions Array of ConditionFlat structs to remove extraneous
     * offsets from
     */
    function _removeExtraneousOffsets(
        ConditionFlat[] memory conditions
    ) private view returns (ConditionFlat[] memory) {
        uint256 count = conditions.length;
        for (uint256 i; i < count; ) {
            if (
                conditions[i].operator == Operator.EqualTo &&
                Topology.isInline(conditions, i) == false
            ) {
                bytes memory compValue = conditions[i].compValue;
                uint256 length = compValue.length;
                assembly {
                    compValue := add(compValue, 32)
                    mstore(compValue, sub(length, 32))
                }
                conditions[i].compValue = compValue;
            }

            unchecked {
                ++i;
            }
        }
        return conditions;
    }
}

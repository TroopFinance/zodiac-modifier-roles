// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@gnosis.pm/zodiac/contracts/guard/BaseGuard.sol";

/// @title Guardable - A contract that manages fallback calls made to this contract
contract Guardable {
    /// @dev Guard
    /// keccak("gnosis.zodiac.guardable.guard")
    bytes32 internal constant GUARD_SLOT =
        0x56bad610fa8c88084970c138f43b8d2788b1b7ea55c6f57c2d6ddc4eca2fc215;

    event ChangedGuard(address guard);

    /// `guard` does not implement IERC165.
    error NotIERC165Compliant(address guard);

    /// @dev Set a guard that checks transactions before execution.
    /// @param guard The address of the guard to be used or the 0 address to disable the guard.
    function setGuard(address guard) internal {
        if (guard != address(0)) {
            if (!BaseGuard(guard).supportsInterface(type(IGuard).interfaceId))
                revert NotIERC165Compliant(guard);
        }
        assembly {
            sstore(GUARD_SLOT, guard)
        }
        emit ChangedGuard(guard);
    }

    function getGuard() public view returns (address guard) {
        assembly {
            guard := sload(GUARD_SLOT)
        }
    }
}

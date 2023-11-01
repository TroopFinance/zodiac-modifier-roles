// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.17 <0.9.0;

import "./adapters/Types.sol";

/**
 * @title Periphery - a coordinating component that facilitates plug-and-play
 * functionality for the Zodiac Roles Mod through the use of adapters.
 * @author Cristóvão Honorato - <cristovao.honorato@gnosis.io>
 */
abstract contract Periphery {
    event SetUnwrapAdapter(
        address to,
        bytes4 selector,
        ITransactionUnwrapper adapter
    );

    /// keccak("gnosis.zodiac.roles.periphery.unwrappers")
    bytes32 internal constant UNWRAPPERS_SLOT =
        0x48e11d58bcccb65f4d3198eb47b87f8ac1bd3c553f89457788c0d4b0eab35961;

    function _unwrappers()
        internal
        pure
        returns (mapping(bytes32 => ITransactionUnwrapper) storage unwrappers_)
    {
        assembly {
            unwrappers_.slot := UNWRAPPERS_SLOT
        }
    }

    function unwrappers(
        bytes32 target
    ) public view returns (ITransactionUnwrapper) {
        return _unwrappers()[target];
    }

    function _setTransactionUnwrapper(
        address to,
        bytes4 selector,
        ITransactionUnwrapper adapter
    ) internal {
        _unwrappers()[
            bytes32(bytes20(to)) | (bytes32(selector) >> 160)
        ] = adapter;
        emit SetUnwrapAdapter(to, selector, adapter);
    }

    function getTransactionUnwrapper(
        address to,
        bytes4 selector
    ) internal view returns (ITransactionUnwrapper) {
        return _unwrappers()[bytes32(bytes20(to)) | (bytes32(selector) >> 160)];
    }
}

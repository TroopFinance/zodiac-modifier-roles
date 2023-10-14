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

    mapping(bytes32 => ITransactionUnwrapper) public unwrappers;

    function _setTransactionUnwrapper(
        address to,
        bytes4 selector,
        ITransactionUnwrapper adapter
    ) internal {
        unwrappers[bytes32(bytes20(to)) | (bytes32(selector) >> 160)] = adapter;
        emit SetUnwrapAdapter(to, selector, adapter);
    }

    function getTransactionUnwrapper(
        address to,
        bytes4 selector
    ) internal view returns (ITransactionUnwrapper) {
        return unwrappers[bytes32(bytes20(to)) | (bytes32(selector) >> 160)];
    }
}

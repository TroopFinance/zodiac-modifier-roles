// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@gnosis.pm/zodiac/contracts/core/Modifier.sol";
import "./Types.sol";

abstract contract Core is OwnableUpgradeable {
    mapping(uint16 => Role) internal roles;

    function _storeBitmap(
        mapping(bytes32 => bytes32) storage bitmap,
        bytes32 key,
        BitmapBuffer memory value
    ) internal virtual;

    function _loadBitmap(
        mapping(bytes32 => bytes32) storage bitmap,
        bytes32 key
    ) internal view virtual returns (BitmapBuffer memory);

    function _pack(
        ParameterConfigFlat[] calldata config,
        ExecutionOptions options
    ) internal pure virtual returns (BitmapBuffer memory, BitmapBuffer memory);

    function _unpack(
        BitmapBuffer memory scopeConfig,
        BitmapBuffer memory compValues
    ) internal pure virtual returns (ParameterConfig[] memory result);

    function _key(
        address targetAddress,
        bytes4 selector
    ) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(targetAddress, selector));
    }
}
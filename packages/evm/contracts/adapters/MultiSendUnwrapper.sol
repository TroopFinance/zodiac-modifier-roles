// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.17 <0.9.0;

import "./Types.sol";

contract MultiSendUnwrapper is ITransactionUnwrapper {
    bytes4 private constant SELECTOR = 0x8d80ff0a;
    uint256 private constant OFFSET_START = 68;

    function unwrap(
        address,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external pure returns (UnwrappedTransaction[] memory) {
        if (value != 0) {
            revert();
        }
        if (operation != Enum.Operation.DelegateCall) {
            revert();
        }
        _validateHeader(data);
        uint256 count = _validateEntries(data);
        return _unwrapEntries(data, count);
    }

    function _validateHeader(bytes calldata data) private pure {
        // first 4 bytes are the selector for multiSend(bytes)
        if (bytes4(data) != SELECTOR) {
            revert();
        }

        // the following 32 bytes are the offset to the bytes param
        // (always 0x20)
        if (bytes32(data[4:]) != bytes32(uint256(0x20))) {
            revert();
        }

        // the following 32 bytes are the length of the bytes param
        uint256 length = uint256(bytes32(data[36:]));

        // validate that the total calldata length matches
        // it's the 4 + 32 + 32 bytes checked above + the <length> bytes
        // padded to a multiple of 32
        if (4 + _ceil32(32 + 32 + length) != data.length) {
            revert();
        }
    }

    function _validateEntries(
        bytes calldata data
    ) private pure returns (uint256 count) {
        uint256 offset = OFFSET_START;

        // data is padded to 32 bytes we can't simply do offset < data.length
        for (; offset + 32 < data.length; ) {
            // Per transaction:
            // Operation   1  bytes
            // To          20 bytes
            // Value       32 bytes
            // Length      32 bytes
            // Data        Length bytes
            uint8 operation = uint8(bytes1(data[offset:]));
            if (operation > 1) {
                revert();
            }

            uint256 length = uint256(bytes32(data[offset + 53:]));
            if (offset + 85 + length > data.length) {
                revert();
            }

            offset += 85 + length;
            count++;
        }

        if (count == 0) {
            revert();
        }
    }

    function _unwrapEntries(
        bytes calldata data,
        uint256 count
    ) private pure returns (UnwrappedTransaction[] memory result) {
        result = new UnwrappedTransaction[](count);

        uint256 offset = OFFSET_START;
        for (uint256 i; i < count; ) {
            result[i].operation = Enum.Operation(uint8(bytes1(data[offset:])));
            offset += 1;

            result[i].to = address(bytes20(data[offset:]));
            offset += 20;

            result[i].value = uint256(bytes32(data[offset:]));
            offset += 32;

            uint256 length = uint256(bytes32(data[offset:]));
            offset += 32;

            result[i].dataOffset = offset;
            result[i].dataLength = length;
            offset += length;

            unchecked {
                ++i;
            }
        }
    }

    function _ceil32(uint256 length) private pure returns (uint256) {
        // pad size. Source: http://www.cs.nott.ac.uk/~psarb2/G51MPC/slides/NumberLogic.pdf
        return ((length + 32 - 1) / 32) * 32;
    }
}

// SPDX-License-Identifier: GPL-3.0 or later

pragma solidity ^0.8.4;

abstract contract Context {

    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() {}

    /**
     * @dev Returns message sender
     */
    function _msgSender() internal view virtual returns (address) {
        return payable(msg.sender);
    }

    /**
     * @dev Returns message content
     */
    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

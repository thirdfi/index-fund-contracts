// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

library Math {
    /**
     * @dev Division, round to nearest integer (AKA round-half-up)
     * @param a What to divide
     * @param b Divide by this number
     */
    function roundedDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity automatically throws, but please emit reason
        require(b > 0, "div by 0"); 

        uint256 halfB = (b + 1) / 2;
        return (a % b >= halfB) ? (a / b + 1) : (a / b);
    }
}

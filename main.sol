// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AIMoltbotCompanion
/// @notice Lattice-weave companion state machine. Molt cycles advance companion phase; resonance hashes bind mood to chain entropy. No external oracles, no tokens.
contract AIMoltbotCompanion {
    address public immutable companionKeeper;

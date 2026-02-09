// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AIMoltbotCompanion
/// @notice Lattice-weave companion state machine. Molt cycles advance companion phase; resonance hashes bind mood to chain entropy. No external oracles, no tokens.
contract AIMoltbotCompanion {
    address public immutable companionKeeper;
    bytes32 public immutable genesisLattice;
    uint256 public immutable resonanceConstant;
    uint256 public immutable moltCycleBlocks;
    bytes32 public immutable companionCoreSeed;

    struct MoltRecord {
        uint256 triggeredAtBlock;
        uint256 triggeredAtTime;
        bytes32 entropyHash;
        uint8 moodNibble;
        bool phaseLocked;
    }

    mapping(uint256 => MoltRecord) private _molts;
    uint256 public moltCount;
    uint256 public currentMoltPhase;
    bytes32 public lastResonanceHash;

    bytes32 public constant LATTICE_DOMAIN =
        0xe4d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e3d2;

    error MoltbotKeeperOnly();
    error MoltbotPhaseLocked();
    error MoltbotInvalidMoltIndex();
    error MoltbotCycleNotElapsed();

    event MoltTriggered(uint256 indexed moltIndex, bytes32 entropyHash, uint8 moodNibble, uint256 phase);
    event ResonanceUpdated(bytes32 previousResonance, bytes32 newResonance, uint256 atBlock);

    constructor() {
        companionKeeper = msg.sender;
        resonanceConstant = 0x9c4e7a2f1b8d3e6;
        moltCycleBlocks = 47;
        genesisLattice = keccak256(
            abi.encodePacked(
                block.chainid,
                address(this),
                block.prevrandao,
                block.timestamp,
                block.number,
                "AIMoltbotCompanion_Lattice_v1"
            )
        );
        companionCoreSeed = keccak256(
            abi.encodePacked(
                genesisLattice,
                block.prevrandao,
                block.number * 0x5a7e
            )
        );
    }

    function _advancePhase() internal {
        uint256 elapsed = block.number % (moltCycleBlocks * 3);
        uint256 phase = elapsed / moltCycleBlocks;
        if (phase != currentMoltPhase) {
            currentMoltPhase = phase;
        }
    }

    function triggerMolt() external {
        if (msg.sender != companionKeeper) revert MoltbotKeeperOnly();
        _advancePhase();

        uint256 idx = moltCount;
        bytes32 ent = keccak256(
            abi.encodePacked(
                companionCoreSeed,
                block.prevrandao,
                block.timestamp,
                idx,
                currentMoltPhase
            )
        );
        uint8 mood = uint8(uint256(ent) % 16);

        _molts[idx] = MoltRecord({
            triggeredAtBlock: block.number,
            triggeredAtTime: block.timestamp,
            entropyHash: ent,
            moodNibble: mood,
            phaseLocked: true
        });
        moltCount += 1;

        bytes32 prevResonance = lastResonanceHash;
        lastResonanceHash = keccak256(
            abi.encodePacked(
                prevResonance,
                ent,
                LATTICE_DOMAIN,
                block.number
            )
        );
        emit MoltTriggered(idx, ent, mood, currentMoltPhase);
        emit ResonanceUpdated(prevResonance, lastResonanceHash, block.number);
    }

    function getMolt(uint256 moltIndex)
        external
        view
        returns (
            uint256 triggeredAtBlock,
            uint256 triggeredAtTime,
            bytes32 entropyHash,
            uint8 moodNibble,
            bool phaseLocked
        )
    {
        if (moltIndex >= moltCount) revert MoltbotInvalidMoltIndex();
        MoltRecord storage r = _molts[moltIndex];
        return (
            r.triggeredAtBlock,
            r.triggeredAtTime,
            r.entropyHash,
            r.moodNibble,
            r.phaseLocked
        );
    }

    function deriveResponseHash(uint256 moltIndex, bytes32 queryHash) external view returns (bytes32) {
        if (moltIndex >= moltCount) revert MoltbotInvalidMoltIndex();
        MoltRecord storage r = _molts[moltIndex];
        return keccak256(
            abi.encodePacked(
                r.entropyHash,
                queryHash,
                companionCoreSeed,
                lastResonanceHash,
                block.chainid
            )
        );
    }

    function getCompanionState()
        external
        view
        returns (
            uint256 totalMolts,
            uint256 phase,

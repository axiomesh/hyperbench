// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Governance contract is a system contract that needn't be deployed
// this is only used for generate governance ABI
interface Governance {
    function propose(uint8 proposalType, string calldata  title, string calldata desc, uint64 blockNumber, bytes calldata extra) external;

    function vote(uint64 proposalID, uint8 voteResult, bytes calldata extra) external;

    function proposal(uint64 proposalID) external view returns (bytes calldata proposal);
}
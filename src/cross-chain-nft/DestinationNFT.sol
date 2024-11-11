// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC721A} from "@ERC721A/contracts/ERC721A.sol";
import {ERC721AQueryable} from "@ERC721A/contracts/extensions/ERC721AQueryable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC721A} from "@ERC721A/contracts/IERC721A.sol";
import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";

/// @dev Owner should be source chain NFT contract
contract DestinationNFT is ERC721A, ERC721AQueryable, Ownable {
    error ForbiddenCaller();
    error ForbiddenNetwork();
    error ForbiddenContract();

    struct TeleportData {
        address from;
        address to;
        uint256[] tokens;
        bool transfer;
    }

    /// @dev Consider changing it into 'bytes32 private immutable'
    string private baseURI;
    uint256 private constant MSG_GAS_LIMIT = 600_000;
    IGateway private immutable i_trustedGateway;
    address private immutable i_sourceContract;
    uint16 private immutable i_sourceNetwork;

    /// @dev Emitted when tokens are teleported from one chain to another.
    event InboundTokensTransfer(bytes32 indexed id, address indexed user, uint256[] tokens);
    event OutboundTokensTransfer(bytes32 indexed id, address indexed from, address indexed to, uint256[] tokens);
    event OutboundOwnershipChange(bytes32 indexed id, address indexed from, address indexed to, uint256[] tokens);

    /// @dev Constructor
    constructor(
        string memory name,
        string memory symbol,
        string memory uri,
        address owner,
        IGateway gatewayAddress,
        address sourceContract,
        uint16 sourceNetwork
    ) ERC721A(name, symbol) Ownable(owner) {
        baseURI = uri;
        i_trustedGateway = gatewayAddress;
        i_sourceContract = sourceContract;
        i_sourceNetwork = sourceNetwork;
    }

    /// @notice Leads to Metadata, which is unique for each token
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /// @dev Prevents tokenURI from adding tokenId to URI as it should be the same for all tokens
    function tokenURI(uint256 tokenId) public view virtual override(ERC721A, IERC721A) returns (string memory) {
        if (!_exists(tokenId)) _revert(URIQueryForNonexistentToken.selector);

        return _baseURI();
    }

    /// @dev Check if it is used
    /// @notice Returns total minted tokens amount ignoring performed burns
    /// @dev Call 'totalSupply()' function for amount corrected by burned tokens amount
    function totalMinted() external view returns (uint256) {
        return _totalMinted();
    }

    /// @dev CROSS-CHAIN FUNCTIONS

    /// @dev Temporary function to until we solve double relay call underflow/overflow error
    function mint(uint id) external {
        _safeMintSpot(msg.sender, id);
    }

    function crossChainTokensTransferFrom(uint256[] memory tokenIds) external payable returns (bytes32 messageID) {
        /// @dev Below will not work, we need to use single burn under loop
        _batchBurn(address(0), tokenIds);

        bytes memory message = abi.encode(TeleportData({from: msg.sender, to: i_sourceContract, tokens: tokenIds, transfer: true}));

        /// @dev Function 'submitMessage()' sends message from chain A to chain B
        /// @param sourceAddress the target address on the source chain
        /// @param sourceNetwork the target chain where the contract call will be made
        /// @param executionGasLimit the gas limit available for the contract call
        /// @param data message data with no specified format
        messageID = i_trustedGateway.submitMessage{value: i_trustedGateway.estimateMessageCost(i_sourceNetwork, message.length, MSG_GAS_LIMIT)}(
            i_sourceContract,
            i_sourceNetwork,
            MSG_GAS_LIMIT,
            message
        );

        emit OutboundTokensTransfer(messageID, msg.sender, i_sourceContract, tokenIds);
    }

    /// @dev To be refactored
    function safeTransferFrom(address from, address to, uint256 tokenId) public payable override(ERC721A, IERC721A) {
        super.safeTransferFrom(from, to, tokenId);

        uint[] memory tokenIds = new uint[](1);
        tokenIds[0] = tokenId;

        bytes memory message = abi.encode(TeleportData({from: msg.sender, to: to, tokens: tokenIds, transfer: false}));

        /// @dev Function 'submitMessage()' sends message from chain A to chain B
        /// @param sourceAddress the target address on the source chain
        /// @param sourceNetwork the target chain where the contract call will be made
        /// @param executionGasLimit the gas limit available for the contract call
        /// @param data message data with no specified format
        bytes32 messageID = i_trustedGateway.submitMessage{value: msg.value}(i_sourceContract, i_sourceNetwork, MSG_GAS_LIMIT, message);

        emit OutboundOwnershipChange(messageID, msg.sender, to, tokenIds);
    }

    /// @dev Consider change to internal
    function safeBtachTransfer(address to, uint256[] memory tokenIds) public payable returns (bytes32 messageID) {
        for (uint i; i < tokenIds.length; i++) {
            super.safeTransferFrom(msg.sender, to, tokenIds[i]);
        }

        bytes memory message = abi.encode(TeleportData({from: msg.sender, to: to, tokens: tokenIds, transfer: false}));

        /// @dev Function 'submitMessage()' sends message from chain A to chain B
        /// @param sourceAddress the target address on the source chain
        /// @param sourceNetwork the target chain where the contract call will be made
        /// @param executionGasLimit the gas limit available for the contract call
        /// @param data message data with no specified format
        messageID = i_trustedGateway.submitMessage{value: msg.value}(i_sourceContract, i_sourceNetwork, MSG_GAS_LIMIT, message);

        emit OutboundOwnershipChange(messageID, msg.sender, to, tokenIds);
    }

    /// @dev Include function signature check to make below conditional check
    function transferCost(address to, uint[] memory tokenIds, bool transfer) external view returns (uint256 cost) {
        bytes memory message = abi.encode(TeleportData({from: msg.sender, to: to, tokens: tokenIds, transfer: transfer}));

        return i_trustedGateway.estimateMessageCost(i_sourceNetwork, message.length, MSG_GAS_LIMIT);
    }

    function onGmpReceived(bytes32 id, uint128 network, bytes32 sender, bytes calldata data) external payable returns (bytes32) {
        address source = address(uint160(uint256(sender)));

        if (msg.sender != address(i_trustedGateway)) revert ForbiddenCaller();
        if (network != i_sourceNetwork) revert ForbiddenNetwork();
        if (source != i_sourceContract) revert ForbiddenContract();

        TeleportData memory command = abi.decode(data, (TeleportData));

        /// @dev Minting all tokens exactly as they exist on source NFT we avoid need of additional mapping, but we bear additional cost of not using batchMint
        for (uint i; i < command.tokens.length; i++) {
            _safeMintSpot(command.from, command.tokens[i]);
        }

        emit InboundTokensTransfer(id, command.from, command.tokens);

        return id;
    }

    /// @dev REQUIRED FUNCTIONS OVERRIDES

    /// @dev Enables use of `_safeMintSpot()` function
    function _sequentialUpTo() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Override ERC721A and ERC721AVotes Function
    /// @dev Additionally delegates vote to new token owner
    function _afterTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity) internal virtual override(ERC721A) {
        super._afterTokenTransfers(from, to, startTokenId, quantity);
    }
}

/// @dev We either mint all nfts as they are in source
/// @dev We cannot use batchTransfer, batchBurn with spotMint

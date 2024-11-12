// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC721A} from "@ERC721A/contracts/ERC721A.sol";
import {ERC721AQueryable} from "@ERC721A/contracts/extensions/ERC721AQueryable.sol";
import "../extensions/ERC721AVotes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";

contract SourceNFT is ERC721A, ERC721AQueryable, EIP712, ERC721AVotes, Ownable {
    error TokensActiveOnOtherChain();
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
    /// @dev Check if putting more limit here
    uint256 private constant MSG_GAS_LIMIT = 600_000;
    IGateway private immutable i_trustedGateway;
    address private immutable i_destinationContract;
    uint16 private immutable i_destinationNetwork;

    mapping(uint256 token => bool locked) tokenLockStatus;

    /// @dev Emitted when tokens are teleported from one chain to another.
    event OutboundTokensTransfer(bytes32 indexed id, address indexed from, address indexed to, uint256[] tokens);
    event InboundTokensTransfer(bytes32 indexed id, address indexed user, uint256[] tokens);
    event InboundOwnershipChange(bytes32 indexed id, address from, address to, uint256[] tokens);

    event TokensLocked(uint[] tokens);
    event TokensUnlocked(uint[] tokens);

    /// @dev Constructor
    constructor(
        string memory name,
        string memory symbol,
        string memory uri,
        address owner,
        IGateway gatewayAddress,
        address destinationAddress,
        uint16 destinationNetwork
    ) ERC721A(name, symbol) EIP712(name, "version 1") Ownable(owner) {
        baseURI = uri;
        i_trustedGateway = gatewayAddress;
        i_destinationContract = destinationAddress;
        i_destinationNetwork = destinationNetwork;
    }

    /// @dev It is needed to avoid coinage restrictions on DestinationNFT
    function _startTokenId() internal pure override returns (uint256) {
        return 2;
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

    /// @notice Returns total minted tokens amount ignoring performed burns
    /// @dev Call 'totalSupply()' function for amount corrected by burned tokens amount
    function totalMinted() external view returns (uint256) {
        return _totalMinted();
    }

    /// @notice Mints multiple tokens at once to a single user and instantly delegates votes to receiver
    /// @param to Address of receiver of minted tokens
    /// @param quantity Amount of tokens to be minted
    function safeBatchMint(address to, uint256 quantity) external onlyOwner {
        _safeMint(to, quantity);
    }

    /// @notice Burns all tokens owned by user
    /// @param owner Address of tokens owner
    function batchBurn(address owner) external onlyOwner {
        uint256[] memory tokenIds = this.tokensOfOwner(owner);

        _batchBurn(address(0), tokenIds);
    }

    /// @notice Safely transfers `tokenIds` in batch from `from` to `to`
    function safeBatchTransferFrom(address from, address to, uint256[] memory tokenIds) external {
        if (!areTokensUnlocked(tokenIds)) revert TokensActiveOnOtherChain();

        _safeBatchTransferFrom(msg.sender, from, to, tokenIds, "");
    }

    /// @dev CROSS-CHAIN FUNCTIONS

    function crossChainTokensTransfer(uint256[] memory tokenIds) external payable returns (bytes32 messageID) {
        /// @dev Check if msg.sender is tokens owner
        lockTokens(tokenIds);

        bytes memory message = abi.encode(TeleportData({from: msg.sender, to: address(this), tokens: tokenIds, transfer: true}));

        //uint256 cost = i_trustedGateway.estimateMessageCost(i_destinationNetwork, message.length, MSG_GAS_LIMIT);

        /// @dev Function 'submitMessage()' sends message from chain A to chain B
        /// @param destinationAddress the target address on the destination chain
        /// @param destinationNetwork the target chain where the contract call will be made
        /// @param executionGasLimit the gas limit available for the contract call
        /// @param data message data with no specified format
        messageID = i_trustedGateway.submitMessage{value: msg.value}(i_destinationContract, i_destinationNetwork, MSG_GAS_LIMIT, message);

        emit OutboundTokensTransfer(messageID, msg.sender, i_destinationContract, tokenIds);
    }

    function transferCost(uint[] memory tokenIds) external view returns (uint256 cost) {
        bytes memory message = abi.encode(TeleportData({from: msg.sender, to: i_destinationContract, tokens: tokenIds, transfer: true}));

        return i_trustedGateway.estimateMessageCost(i_destinationNetwork, message.length, MSG_GAS_LIMIT);
    }

    function onGmpReceived(bytes32 id, uint128 network, bytes32 sender, bytes calldata data) external payable returns (bytes32) {
        address senderAddress = address(uint160(uint256(sender)));

        if (msg.sender != address(i_trustedGateway)) revert ForbiddenCaller();
        if (network != i_destinationNetwork) revert ForbiddenNetwork();
        if (senderAddress != i_destinationContract) revert ForbiddenContract();

        /// @dev Check if below approach works
        // uint8 commandType = uint8(data[0]);

        TeleportData memory command = abi.decode(data, (TeleportData));

        if (command.transfer) {
            unlockTokens(command.tokens);

            emit InboundTokensTransfer(id, command.from, command.tokens);
        } else if (!command.transfer) {
            /// @dev Below skips approve from user
            _safeBatchTransferFrom(address(0), command.from, command.to, command.tokens, "");

            emit InboundOwnershipChange(id, command.from, command.to, command.tokens);
        }

        return id;
    }

    // Make it internal
    function lockTokens(uint256[] memory tokenIds) public {
        for (uint i; i < tokenIds.length; i++) {
            tokenLockStatus[tokenIds[i]] = true;
        }

        emit TokensLocked(tokenIds);
    }

    // Make it internal
    function unlockTokens(uint256[] memory tokenIds) public {
        for (uint i; i < tokenIds.length; i++) {
            tokenLockStatus[tokenIds[i]] = false;
        }

        emit TokensUnlocked(tokenIds);
    }

    // Make it internal
    function areTokensUnlocked(uint256[] memory tokenIds) public view returns (bool) {
        for (uint256 i; i < tokenIds.length; i++) {
            if (tokenLockStatus[tokenIds[i]]) return false;
        }

        return true;
    }

    /// @dev ERC721A FUNCTIONS OVERRIDES ADJUSTING TOKEN LOCK RESTRICTION

    // approve()
    // delegate()
    // delegateBySig()
    // safeTransferFrom()
    // safeTransferFrom()
    // setApprovalForAll()
    // transferFrom()

    /// @dev REQUIRED FUNCTIONS OVERRIDES

    /// @notice Override ERC721A and ERC721AVotes Function
    /// @dev Additionally delegates vote to new token owner
    function _afterTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity) internal virtual override(ERC721A, ERC721AVotes) {
        super._afterTokenTransfers(from, to, startTokenId, quantity);
        if (to != address(0)) _delegate(to, to);
    }

    /// @dev Check if we indeed need this -> if ERC721AQueryable included override(ERC721A, IERC721A)
    ///
    /// @dev ERC721a Governance Token Interface Support
    /// @dev Implements the interface support check for ERC721a Governance Token
    /// @notice Checks if the contract implements an interface you query for, including ERC721A and Votes interfaces
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @return True if the contract implements `interfaceId` or if `interfaceId` is the ERC-165 interface
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, IERC721A) returns (bool) {
        return interfaceId == type(IVotes).interfaceId || super.supportsInterface(interfaceId);
    }

    ////////////////////////////////////
    /// @dev VOTING MODULE OVERRIDE'S //
    ////////////////////////////////////

    /// @dev Override Vote Function
    /// @notice Changes block.number into block.timestamp for snapshot
    function clock() public view override returns (uint48) {
        return Time.timestamp();
    }

    /// @dev Override Vote Function
    /// @notice Changes block.number into block.timestamp for snapshot
    function CLOCK_MODE() public pure override returns (string memory) {
        // Check that the clock was not modified
        /// @dev Is this check even possible to fail?
        // if (clock() != Time.timestamp()) revert ERC6372InconsistentClock();

        return "mode=timestamp";
    }
}

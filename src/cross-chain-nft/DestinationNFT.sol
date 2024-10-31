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
        address user;
        uint256[] tokens;
    }

    struct TeleportOwnership {
        address from;
        address to;
        uint256[] tokens;
    }

    /// @dev Consider changing it into 'bytes32 private immutable'
    string private baseURI;
    IGateway private immutable i_trustedGateway;
    address private immutable i_sourceContract;
    uint16 private immutable i_sourceNetwork;

    /// @dev Emitted when tokens are teleported from one chain to another.
    event InboundTransfer(bytes32 indexed id, address indexed user, uint256[] tokens);

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

    /// @notice Returns total minted tokens amount ignoring performed burns
    /// @dev Call 'totalSupply()' function for amount corrected by burned tokens amount
    function totalMinted() external view returns (uint256) {
        return _totalMinted();
    }

    /// @notice Mints multiple tokens at once to a single user and instantly delegates votes to receiver
    /// @param to Address of receiver of minted tokens
    /// @param quantity Amount of tokens to be minted
    // function safeBatchMint(address to, uint256 quantity) external onlyOwner {
    //     _safeMint(to, quantity);
    // }

    /// @notice Burns all tokens owned by user
    /// @param owner Address of tokens owner
    function batchBurn(address owner) external onlyOwner {
        uint256[] memory tokenIds = this.tokensOfOwner(owner);

        _batchBurn(address(0), tokenIds);
    }

    /// @notice Safely transfers `tokenIds` in batch from `from` to `to`
    function safeBatchTransferFrom(address from, address to, uint256[] memory tokenIds) external {
        _safeBatchTransferFrom(msg.sender, from, to, tokenIds, "");
    }

    /// @dev CROSS-CHAIN FUNCTIONS

    function crossChainTokensTransferFrom() external {}

    function crossChainTokensOwnershipChange() external {}

    function onGmpReceived(bytes32 id, uint128 network, bytes32 sender, bytes calldata data) external payable returns (bytes32) {
        address source = address(uint160(uint256(sender)));

        if (msg.sender != address(i_trustedGateway)) revert ForbiddenCaller();
        if (network != i_sourceNetwork) revert ForbiddenNetwork();
        if (source != i_sourceContract) revert ForbiddenContract();

        TeleportData memory command = abi.decode(data, (TeleportData));

        _safeMint(command.user, command.tokens.length);

        emit InboundTransfer(id, command.user, command.tokens);

        return id;
    }

    /// @dev REQUIRED FUNCTIONS OVERRIDES

    /// @notice Override ERC721A and ERC721AVotes Function
    /// @dev Additionally delegates vote to new token owner
    function _afterTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity) internal virtual override(ERC721A) {
        super._afterTokenTransfers(from, to, startTokenId, quantity);
    }
}

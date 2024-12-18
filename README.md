## Analog Cross-Chain

1. DEX Swap Before Payment
    - Users would need to swap and then execute desired function anyway
2. Token Bridge from Aleph Zero: https://canbridge.alephzero.org/bridge/aleph-zero-evm
    - Users still need AZERO to cover gas fees...
3. Deploy a Wrapper Contract
    - Users deposit USDT into the bridge contract on Ethereum and those funds needs to be frozen on contract.
    - The bridge contract needs to mint wrapped USDT (wUSDT) on Aleph Zero's EVM chain.
    - Our contract can accept wUSDT as a form of payment on the EVM chain.
    - Users still need AZERO to cover gas fees...

# Call

https://chain.link/education-hub/cross-chain-nft

-   <u>**Burn-and-mint:**</u> An NFT owner puts their NFT into a smart contract on the source chain and burns it, in effect removing it from that blockchain. Once this is done, an equivalent NFT is created on the destination blockchain from its corresponding smart contract. This process can occur in both directions.

-   <u>**Lock-and-mint:**</u> An NFT owner locks their NFT into a smart contract on the source chain, and an equivalent NFT is created on the destination blockchain. When the owner wants to move their NFT back, they burn the NFT and it unlocks the NFT on the original blockchain.

-   <u>**Lock-and-unlock:**</u> The same NFT collection is minted on multiple blockchains. An NFT owner can lock their NFT on a source blockchain to unlock the equivalent NFT on a destination blockchain. This means only a single NFT can actively be used at any point in time, even if there are multiple instances of that NFT across blockchains.

# Fee coin pick example

https://github.com/smartcontractkit/ccip-starter-kit-foundry/blob/main/src/cross-chain-nft-minter/DestinationMinter.sol

https://github.com/smartcontractkit/ccip-cross-chain-nft/blob/main/src/XNFT.sol

# Cross Chain NFT

https://cll-devrel.gitbook.io/ccip-bootcamp/day-1/welcome-to-ccip-bootcamp

-   Give user possibility to transfer his NFT to other chain

@dev Mint from buy only available on 'SOURCE' contract

-   If someone buys from another chain -> (mint) and (lock) on 'SOURCE' then transfer to 'DESTINATION' (mint)

-   If tokens comes from 'DESTINATION' to 'SOURCE' then (burn) on 'DESTINATION' and (unlock) on 'SOURCE'

-   Votes counted from 'SOURCE' ignoring (lock)

### Source:

-   crossChainTransferFrom() -> lock tokens send cross chain msg to destination contract
-   onGmpReceived() -> unlock nft or update tokens ownership

### Destination:

-   transferFrom() -> update source chain tokens ownership
-   onGmpReceived() -> mint nft's

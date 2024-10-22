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

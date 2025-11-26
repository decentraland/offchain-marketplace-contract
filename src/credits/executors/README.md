# RegisterNameCrossChainExecutor

## Overview

The `RegisterNameCrossChainExecutor` is a specialized contract that facilitates cross-chain name registrations in the Decentraland ecosystem. It acts as a secure executor that validates and processes name registration transactions through the Coral bridge contract, ensuring proper fee management and security controls. 

## Purpose

This contract enables users to register Decentraland names on Ethereum mainnet while paying with MANA credits on Polygon. It handles:

- **Cross-chain execution**: Bridges the registration request from Polygon to Ethereum via Coral
- **Fee validation**: Ensures that transaction fees don't exceed a configurable USD limit
- **Security**: Implements pausability, reentrancy protection, and access controls
- **MANA management**: Handles MANA token approvals and transfers for both name price and bridge fees

## How It Works

### Architecture

```
User → CreditsManager → RegisterNameCrossChainExecutor → Coral Bridge → Ethereum Name Registry
```

### Execution Flow

1. **User initiates**: User calls the Credits Manager with their name registration request
2. **Credits Manager delegates**: The Credits Manager calls the `execute()` function on this contract
3. **Validation phase**:
   - Verifies the caller is the authorized Credits Manager
   - Validates the target contract is Coral
   - Validates the function selector is `fundAndRunMulticall` (0x58181a80)
   - Checks the call hasn't expired
   - Validates the MANA fee doesn't exceed the USD limit (using Chainlink price feed)
4. **Execution phase**:
   - Approves MANA to Coral for: `NAME_PRICE (100 MANA) + bridge fee`
   - Transfers 100 MANA from Credits Manager to this contract
   - Executes the call to Coral's `fundAndRunMulticall`
   - Resets MANA approval to zero
5. **Cross-chain**: Coral bridges the transaction to Ethereum to register the name

### Fee Structure

- **Name Price**: Fixed at 100 MANA (hardcoded as `NAME_PRICE` constant)
- **Bridge Fee**: Variable MANA amount needed to cover Ethereum gas costs
- **Fee Protection**: Bridge fee is capped at a configurable USD amount (e.g., maximum $5 worth of MANA)

#### Why the Bridge Fee?

Using Coral for cross-chain execution allows users to pay Ethereum transaction fees in MANA tokens instead of native ETH. When the transaction is executed on Ethereum, Coral converts the provided MANA into ETH to cover gas costs (either in WETH or any other tokens depending on the liquidity). This provides a seamless user experience where users only need MANA tokens to register names, without needing to hold ETH on mainnet.

The bridge fee (`manaFee` in the `ExternalCall` struct) represents the amount of MANA that will be used to pay for:
- Ethereum gas costs for the name registration transaction
- Coral's cross-chain execution service

This fee is dynamic and depends on:
- Current Ethereum gas prices
- ETH/MANA exchange rate at execution time
- Complexity of the transaction being executed (gas used)

### Price Oracle

The contract uses a Chainlink MANA/USD price aggregator to:
- Convert the USD fee limit to MANA amounts in real-time
- Ensure users don't pay excessive fees due to price volatility
- Validate that the bridge fee is within acceptable limits

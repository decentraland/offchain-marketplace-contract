# CreditsManagerPolygon

## Overview
The CreditsManagerPolygon contract is a sophisticated credit management system designed for the Decentraland ecosystem. It serves as a bridge that allows users to pay for marketplace transactions using pre-signed credits instead of directly spending MANA from their wallets. This creates a more seamless user experience by enabling off-chain credit issuance that can be consumed on-chain, reducing the need for direct MANA transfers from user wallets.

## Table of Contents
- [Key Features](#key-features)
- [Roles and Permissions](#roles-and-permissions)
- [Core Data Structures](#core-data-structures)
- [Main Functionality](#main-functionality)
  - [Credit Management](#credit-management)
  - [External Call Handling](#external-call-handling)
- [Security Features](#security-features)
- [Usage Examples](#usage-examples)

## Key Features
- **Credit System**: Allows users to use signed credits to pay for transactions
- **Marketplace Integration**: Supports both primary and secondary sales in Decentraland's marketplace
- **Access Control**: Comprehensive role-based access control for different operations
- **Meta-transactions**: Supports meta-transactions for improved UX
- **Rate Limiting**: Implements hourly credit consumption limits
- **Custom External Calls**: Enables authorized external contract calls beyond standard marketplace operations

## Roles and Permissions
The contract implements a role-based access control system with the following roles:
- **DEFAULT_ADMIN_ROLE**: Can grant/revoke roles and perform administrative functions
- **SIGNER_ROLE**: Can sign credits that users can later redeem
- **PAUSER_ROLE**: Can pause/unpause the contract functionality
- **DENIER_ROLE**: Can deny specific users from using credits
- **REVOKER_ROLE**: Can revoke previously issued credits
- **EXTERNAL_CALL_SIGNER_ROLE**: Can sign custom external calls
- **EXTERNAL_CALL_REVOKER_ROLE**: Can revoke custom external call signatures

## Core Data Structures
The contract uses several key data structures:

### Credit

Contains the data of a credit, which is to be signed by the address with the SIGNER_ROLE.

```solidity
struct Credit {
    uint256 value;         // How much MANA the credit is worth
    uint256 expiresAt;     // The timestamp when the credit expires
    bytes32 salt;          // Value used to generate unique credits
}
```

### ExternalCall

Contains the data of the external call being made. This contract revolves on determining how much MANA is transferred out of the contract when called and calculate the credits to be used.

```solidity
struct ExternalCall {
    address target;        // The contract address of the external call
    bytes4 selector;       // The selector of the external call
    bytes data;            // The data of the external call
    uint256 expiresAt;     // The timestamp when the external call expires *
    bytes32 salt;          // The salt of the external call *
}

// * Only required for custom external calls. 
//   These are any calls which do not target decentraland marketplace contracts.
```

### UseCreditsArgs

Used for the `useCredits` function which is the main function of the contract.

```solidity
struct UseCreditsArgs {
    Credit[] credits;                   // The credits to use
    bytes[] creditsSignatures;          // The signatures of the credits
    ExternalCall externalCall;          // The external call to make
    bytes customExternalCallSignature;  // The signature of the external call
    uint256 maxUncreditedValue;         // Maximum MANA paid from wallet
    uint256 maxCreditedValue;           // Maximum MANA credited from provided credits
}
```

## Main Functionality

### Credit Management
- **Credit Validation**: Verifies credit signatures, expiration, and consumption status
- **Credit Consumption**: Tracks how much of each credit has been consumed
- **Credit Revocation**: Allows authorized roles to revoke credits
- **Rate Limiting**: Enforces maximum MANA credited per hour

### External Call Handling
The contract supports four types of external calls:
1. **Legacy Marketplace**: For executing orders on the legacy Marketplace contract.
2. **Marketplace**: For accepting trades on the current offchain-marketplace *.
3. **Collection Store**: For minting collection items using the legacy CollectionStore contract.
4. **Custom External Calls**: For other authorized contract interactions

\* Only "Listing" Trades are allowed to consume credits. Listings are Trades which have 1 MANA asset being received by the signer, and 1 or more Decentraland Items/NFTs being sent by the signer.

## Security Features
- **Reentrancy Protection**: Uses ReentrancyGuard to prevent reentrancy attacks
- **Pausable**: Contract can be paused in case of emergencies
- **Access Control**: Strict role-based permissions for sensitive operations
- **Signature Verification**: Validates all signatures before processing
- **Rate Limiting**: Prevents excessive credit usage in short time periods
- **Denial Capability**: Ability to deny malicious users from using the system

## Usage Examples

The following examples demonstrate how to use the `useCredits` function with different types of external calls. Each example follows the same basic pattern:

1. Create and sign one or more credits
2. Prepare the external call data
3. Call the `useCredits` function

### 1. Collection Store External Call

```javascript
// 1. Create and sign a credit
const credit = {
  value: ethers.utils.parseEther("100"),  // 100 MANA
  expiresAt: Math.floor(Date.now() / 1000) + 86400, // Expires in 24 hours
  salt: ethers.utils.randomBytes(32)  // Random salt for uniqueness
};

const message = ethers.utils.solidityKeccak256(
  [
    { name: "user", type: "address" },
    { name: "chainId", type: "uint256" },
    { name: "creditsManager", type: "address" },
    { name: "value", type: "uint256" },
    { name: "expiresAt", type: "uint256" },
    { name: "salt", type: "bytes32" }
  ],
  [userAddress, chainId, creditsManagerAddress, credit.value, credit.expiresAt, credit.salt]
);
const signature = await signer.signMessage(ethers.utils.arrayify(message));

// 2. Prepare Collection Store external call
const itemsToBuy = [{
  collection: collectionAddress,  // Must be a Decentraland collection
  ids: [itemId],
  prices: [ethers.utils.parseEther("50")],  // 50 MANA
  beneficiaries: [userAddress]
}];

const externalCall = {
  target: collectionStoreAddress,
  selector: "0xa4fdc78a", // buy function selector
  data: ethers.utils.defaultAbiCoder.encode(
    [{
      type: "tuple[]",
      components: [
        { name: "collection", type: "address" },
        { name: "ids", type: "uint256[]" },
        { name: "prices", type: "uint256[]" },
        { name: "beneficiaries", type: "address[]" }
      ]
    }],
    [itemsToBuy]
  ),
  expiresAt: 0,  // Not needed for collection store calls
  salt: ethers.utils.hexZeroPad("0x", 32)  // Not needed for collection store calls
};

// 3. Call useCredits
const useCreditsArgs = {
  credits: [credit],
  creditsSignatures: [signature],
  externalCall: externalCall,
  customExternalCallSignature: "0x",  // Not needed for collection store calls
  maxUncreditedValue: 0,  // User won't pay anything from their wallet
  maxCreditedValue: ethers.utils.parseEther("50")  // Maximum amount to use from credits
};

await creditsManager.useCredits(useCreditsArgs);
```

### 2. Marketplace External Call

```javascript
// 1. Create and sign a credit
const credit = {
  value: ethers.utils.parseEther("100"),
  expiresAt: Math.floor(Date.now() / 1000) + 86400,
  salt: ethers.utils.randomBytes(32)
};

const message = ethers.utils.solidityKeccak256(
  [
    { name: "user", type: "address" },
    { name: "chainId", type: "uint256" },
    { name: "creditsManager", type: "address" },
    { name: "value", type: "uint256" },
    { name: "expiresAt", type: "uint256" },
    { name: "salt", type: "bytes32" }
  ],
  [userAddress, chainId, creditsManagerAddress, credit.value, credit.expiresAt, credit.salt]
);
const signature = await signer.signMessage(ethers.utils.arrayify(message));

// 2. Prepare Marketplace external call
// Create a trade object following the IMarketplace.Trade structure
// Note: In a real implementation, you would need to properly sign this trade
// This example focuses only on the structure and encoding
const trade = {
  signer: sellerAddress,
  signature: "0x...", // In a real implementation, this would be a valid signature
  checks: {
    uses: 1,
    expiration: ethers.constants.MaxUint256,
    effective: 0,
    salt: ethers.utils.hexZeroPad("0x", 32),
    contractSignatureIndex: 0,
    signerSignatureIndex: 0,
    allowedRoot: ethers.utils.hexZeroPad("0x", 32),
    allowedProof: [],
    externalChecks: []
  },
  sent: [
    {
      assetType: 3, // ASSET_TYPE_ERC721
      contractAddress: nftCollectionAddress, // Must be a Decentraland collection
      value: nftTokenId,
      beneficiary: userAddress,
      extra: "0x"
    }
  ],
  received: [
    {
      assetType: 1, // ASSET_TYPE_ERC20
      contractAddress: manaAddress,
      value: ethers.utils.parseEther("100"),
      beneficiary: ethers.constants.AddressZero, // Will be filled by marketplace
      extra: "0x"
    }
  ]
};

// Create the trades array
const trades = [trade];

// Create the external call with properly encoded data
const externalCall = {
  target: marketplaceAddress,
  selector: "0x961a547e", // accept function selector
  data: ethers.utils.defaultAbiCoder.encode(
    [{
      type: "tuple[]",
      components: [
        { name: "signer", type: "address" },
        { name: "signature", type: "bytes" },
        { 
          name: "checks", 
          type: "tuple",
          components: [
            { name: "uses", type: "uint256" },
            { name: "expiration", type: "uint256" },
            { name: "effective", type: "uint256" },
            { name: "salt", type: "bytes32" },
            { name: "contractSignatureIndex", type: "uint256" },
            { name: "signerSignatureIndex", type: "uint256" },
            { name: "allowedRoot", type: "bytes32" },
            { name: "allowedProof", type: "bytes32[]" },
            { 
              name: "externalChecks", 
              type: "tuple[]",
              components: [
                { name: "contractAddress", type: "address" },
                { name: "selector", type: "bytes4" },
                { name: "value", type: "bytes" },
                { name: "required", type: "bool" }
              ]
            }
          ]
        },
        { 
          name: "sent", 
          type: "tuple[]",
          components: [
            { name: "assetType", type: "uint256" },
            { name: "contractAddress", type: "address" },
            { name: "value", type: "uint256" },
            { name: "beneficiary", type: "address" },
            { name: "extra", type: "bytes" }
          ]
        },
        { 
          name: "received", 
          type: "tuple[]",
          components: [
            { name: "assetType", type: "uint256" },
            { name: "contractAddress", type: "address" },
            { name: "value", type: "uint256" },
            { name: "beneficiary", type: "address" },
            { name: "extra", type: "bytes" }
          ]
        }
      ]
    }],
    [trades]
  ),
  expiresAt: 0, // Not needed for marketplace calls
  salt: ethers.utils.hexZeroPad("0x", 32) // Not needed for marketplace calls
};

// 3. Call useCredits
const useCreditsArgs = {
  credits: [credit],
  creditsSignatures: [signature],
  externalCall: externalCall,
  customExternalCallSignature: "0x", // Not needed for marketplace calls
  maxUncreditedValue: 0,
  maxCreditedValue: ethers.utils.parseEther("100")
};

await creditsManager.useCredits(useCreditsArgs);
```

### 3. Legacy Marketplace External Call

```javascript
// 1. Create and sign a credit
const credit = {
  value: ethers.utils.parseEther("100"),
  expiresAt: Math.floor(Date.now() / 1000) + 86400,
  salt: ethers.utils.randomBytes(32)
};

const message = ethers.utils.solidityKeccak256(
  [
    { name: "user", type: "address" },
    { name: "chainId", type: "uint256" },
    { name: "creditsManager", type: "address" },
    { name: "value", type: "uint256" },
    { name: "expiresAt", type: "uint256" },
    { name: "salt", type: "bytes32" }
  ],
  [userAddress, chainId, creditsManagerAddress, credit.value, credit.expiresAt, credit.salt]
);
const signature = await signer.signMessage(ethers.utils.arrayify(message));

// 2. Prepare Legacy Marketplace external call
const legacyTrade = {
  nftAddress: nftCollectionAddress, // Must be a Decentraland collection
  tokenId: nftTokenId,
  price: ethers.utils.parseEther("100"),
  seller: sellerAddress
};

const externalCall = {
  target: legacyMarketplaceAddress,
  selector: "0xae7b0333", // executeOrder function selector
  data: ethers.utils.defaultAbiCoder.encode(
    [{
      type: "tuple",
      components: [
        { name: "seller", type: "address" },
        { name: "tokenId", type: "uint256" },
        { name: "price", type: "uint256" },
        { name: "buyer", type: "address" }
      ]
    }], 
    [legacyTrade]
  ),
  expiresAt: 0, // Not needed for legacy marketplace calls
  salt: ethers.utils.hexZeroPad("0x", 32) // Not needed for legacy marketplace calls
};

// 3. Call useCredits
const useCreditsArgs = {
  credits: [credit],
  creditsSignatures: [signature],
  externalCall: externalCall,
  customExternalCallSignature: "0x", // Not needed for legacy marketplace calls
  maxUncreditedValue: 0,
  maxCreditedValue: ethers.utils.parseEther("100")
};

await creditsManager.useCredits(useCreditsArgs);
```

### 4. Custom External Call

```javascript
// 1. Create and sign a credit
const credit = {
  value: ethers.utils.parseEther("100"),
  expiresAt: Math.floor(Date.now() / 1000) + 86400,
  salt: ethers.utils.randomBytes(32)
};

const creditMessage = ethers.utils.solidityKeccak256(
  [
    { name: "user", type: "address" },
    { name: "chainId", type: "uint256" },
    { name: "creditsManager", type: "address" },
    { name: "value", type: "uint256" },
    { name: "expiresAt", type: "uint256" },
    { name: "salt", type: "bytes32" }
  ],
  [userAddress, chainId, creditsManagerAddress, credit.value, credit.expiresAt, credit.salt]
);
const creditSignature = await signer.signMessage(ethers.utils.arrayify(creditMessage));

// 2. Prepare Custom external call (must be pre-approved by admin)
const externalCall = {
  target: customContractAddress,
  selector: "0x12345678", // Function selector of the custom contract
  data: ethers.utils.defaultAbiCoder.encode(
    [
      { name: "amount", type: "uint256" },
      { name: "recipient", type: "address" }
    ],
    [100, userAddress]
  ),
  expiresAt: Math.floor(Date.now() / 1000) + 3600, // Expires in 1 hour
  salt: ethers.utils.randomBytes(32)
};

// 3. Get the external call signed by an authorized external call signer
const externalCallMessage = ethers.utils.solidityKeccak256(
  [
    { name: "user", type: "address" },
    { name: "chainId", type: "uint256" },
    { name: "creditsManager", type: "address" },
    { name: "target", type: "address" },
    { name: "selector", type: "bytes4" },
    { name: "data", type: "bytes" },
    { name: "expiresAt", type: "uint256" },
    { name: "salt", type: "bytes32" }
  ],
  [userAddress, chainId, creditsManagerAddress, externalCall.target, externalCall.selector, 
   externalCall.data, externalCall.expiresAt, externalCall.salt]
);
const externalCallSignature = await externalCallSigner.signMessage(ethers.utils.arrayify(externalCallMessage));

// 4. Call useCredits
const useCreditsArgs = {
  credits: [credit],
  creditsSignatures: [creditSignature],
  externalCall: externalCall,
  customExternalCallSignature: externalCallSignature, // Required for custom external calls
  maxUncreditedValue: 0,
  maxCreditedValue: ethers.utils.parseEther("100")
};

await creditsManager.useCredits(useCreditsArgs);
```

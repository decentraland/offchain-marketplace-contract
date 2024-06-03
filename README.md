# Off-Chain Marketplace Contract

This repository contains a Marketplace Smart Contract that allows users to perform trades using EIP712 signatures. Users can sign trades indicating the terms of what will be traded, and other interested parties can accept and settle those trades on the blockchain.

## Trades

Trades are the main entity the Marketplace contract works with.

They consist of the assets that will be sent by the signer of the trade, the assets that the signer expects to receive, and various checks that provide extra validations (expiration, uses, signature indexes, etc.).

## Assets

Assets represent the items that will be swapped in a trade.

Assets in the "sent" property of the trade are those that the signer is willing to exchange, while assets in the "received" property are those that the signer wants to obtain after the trade.

They are composed of an asset type, which indicates the kind of asset it is (ERC20, ERC721, Decentraland Collection Items, etc.). This asset type allows implementations to handle the transfer of those assets as needed.

Assets contain the contract address of the asset, a value indicating amounts or token IDs, some arbitrary extra data used by implementations to handle custom information such as Decentraland Estate fingerprints, and the beneficiary, which is the address that will ultimately receive the asset.

## Checks

These are a series of validations that the trade must pass to be considered acceptable.

These checks include various criteria, such as the number of times a trade can be executed, the start and expiration times of the trade, and the addresses permitted to execute the trade. Additionally, there are external checks, such as requiring ownership of an NFT from a specific collection to accept the trade. The contract owner or individual signers can also use several indexes to cancel existing trades.

## Implementations

For Decentraland, the Marketplace Contract is implemented to support our assets, as well as our current fee and royalty system. There are two different implementations: one for the Ethereum network, which focuses on LANDs, Estates, and Names, and another for the Polygon network, which focuses on Collection items for primary (minting) and secondary (trading) sales.

The Ethereum Decentraland Marketplace allows for the trade of ERC721 tokens such as LANDs and Names, as well as composable ERC721 tokens like Estates. All ERC20 trades will incur a fee, which is sent to the fee collector, the Decentraland DAO.

The Polygon Decentraland Marketplace allows for the trade of ERC721 tokens such as Decentraland Collection NFTs and collection items, which are minted and sent to the interested user. It also includes logic to compute the fees to be paid as royalties and the fees owed to the DAO. Unlike the Ethereum Marketplace, it supports Meta Transactions.

## Coupons

This repository also contains contracts relevant to the concept of Coupons. Coupons are an extension of the Marketplace that allow users to create elements that can be applied to trades to modify them. A great example of this would be discount coupons.

Both the Decentraland Ethereum and Polygon Marketplaces support applying coupons to trades.

Currently, the only available coupon is the CollectionDiscountCoupon, which allows collection creators to offer discounts on their collection items being sold.

The Coupon entity comprises the same checks found in the trade, allowing it to be created with the same set of validations. It includes the contract address of the Coupon implementation, which must be authorized in the Coupon Manager contract to be usable in the Marketplace implementation. Additionally, it contains some arbitrary data, which is interpreted by the Coupon implementation contract, and extra data sent by the caller that is not validated in the signature. For example, in the case of the CollectionDiscountCoupon, this extra data can include the Merkle proof that verifies the collection item being bought qualifies for the discount.

## Signatures

This section contains examples on how to create and sign trades off-chain to be used later in a transaction.

**Signing Trades**

TODO:

**Signing Coupons**

TODO:

## Examples

The examples found on this section will describe some of the many Trade types that the different Marketplace smart contracts found on this repository can enable.

For simplicity, the base Trade all examples will use will look like:

```js
{
    checks: {
        uses: 1, // The trade can only be executed once
        expiration: 1719971471, // 30 days from today (2nd of July 2024)
        effective: 0, // The Trade can be executed from now onwards
        salt: 0x61647662736664627364666273646662736466627364666264626664736e7479, // Some random salt, used to make the signature as unique as possible to avoid collisions with other Trades with the same data.
        contractSignatureIndex: 0, // The current contract signature index
        signerSignatureIndex: 0, // The current signer signature index of the creator of this Trade
        allowedRoot: 0x0000000000000000000000000000000000000000000000000000000000000000, // Anyone can accept this Trade
        externalChecks: [], // No external checks are validated
    },
    sent: [], // Sent assets will be defined in the examples
    received: [] // Received assets will be defined in the examples
}
```

Things to keep in mind:

- Before executing a Trade, users must have allowed the marketplace contract used to transfer those assets.

**Creating a Public Order** (List a LAND for sale)

In this example, the owner of a the LAND found in coords 100,100 wants to list it for sale at a price of 100 MANA.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND contract address
            value: 34028236692093846346337460743176821145700, // Token id of parcel 100,100
            extra: 0x// No extra data is needed
        }
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA contract address
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        }
    ]
}
```

**Creating a Bid** (Offer 100 MANA for an Estate)

In this example, some user wants to place a bid for the Estate with id 100, offering 100 MANA.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA contract address
            value: 100000000000000000000, // 100 MANA
            extra: 0x // No extra data is needed
        }
    ],
    received: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0x959e104e1a4db6317fa58f8295f586e1a978c297, // Estate contract address
            value: 100, // Estate id
            extra: abi.encode(0xa12a0c5cb9a6747da8a8b212604c12f2533b476461f62720c21760c7fb05cd0c), // The encoded fingerprint of the Estate
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        }
    ]
}
```

**Create a Private Order** (List a Wearable for sale, for only a few addresses)

In this example, the owner of a Wearable with ID `0` from Collection `0x024ca955066ce48464ce1eae6106e6fa454ec42a` wants to sell it for 50 MANA. However, this trade is executable only by the addresses `0x2e234DAe75C793f67A35089C9d99245E1C58470b`, `0x24e5F44999c151f08609F8e27b2238c773C4D020`, `0x2f89eC84e0413950d9ADF8e56dd56c2B2f5066cb`.

```js
{
    checks: {
        allowedRoot: 0xb22d9e7d0895dfb81a418295969a1a2f03c46ba31cfcf5ba1e8c83332fe554d0 // The merkle root created from the allowed addresses
    },
    sent: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0x024ca955066ce48464ce1eae6106e6fa454ec42a, // Collection contract address
            value: 0, // Wearable ID
            extra: 0x // No extra data is needed
        }
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA contract address
            value: 50000000000000000000, // 50 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the trade will receive the asset
        }
    ]
}
```

One of the allowed callers must call the `accept` function with the signed trade, providing the extra merkle proof for their address.

```js
{
  checks: {
    allowedProof: [0xf5f79f4414e087ded9df3f796c801706cc3e3061b0f607a13ac6a2a64a07663b]; // The proof for address 0x2e234DAe75C793f67A35089C9d99245E1C58470b
  }
}
```

**Auction** (Auction a Decentraland NAME)

Auctions are an abstract concept that are handled mostly off-chain. The Marketplace contract provides, through the Trade ID, a way for all signatures for a particular auction to be revoked at once when an auction bid is accepted.

The idea for auctions is for the owner of an item to request a backend server to start an auction for a given asset. A salt for this particular auction will be created.

When a user wants to bid in the auction, they will create and sign a trade, determining in the sent assets what they are willing to pay.

This is an example of users bidding for a Decentraland NAME in an auction.

Auction Bid #1

```js
{
    checks: {
        effective: 1719971471, // 30 days from today (2nd of July 2024), time in which the owner of the NAME can accept the trade
        expiration: 1722660671, // 60 days from today (2nd of July 2024), an extra month after the effective date to allow the owner of the NAME to accept it
        allowedRoot: 0x6c9e33165e145e2ae0303097f79b5a91721d83c34291a94e769c65d7cb8bc1a7, // Merkle root allowing only the owner of the asset to accept the trade
        salt: 0x61647662736664627364666273646662736466627364666264626664736e7479 // The salt created for the auction
    },
    sent: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA contract address
            value: 100000000000000000000, // 100 MANA
            extra: 0x // No extra data is needed
        }
    ],
    received: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0x7518456ae93eb98f3e64571b689c626616bb7f30, // DCL Registrar contract address
            value: 20297805150211737582237783260270391886773425187705606004622572049666906448004, // NAME token ID
            extra: 0x, // No extra data required
            beneficiary: 0x0000000000000000000000000000000000000000 // The creator of the trade will receive the asset
        }
    ]
}
```

Auction Bid #2

```js
{
    checks: {
        effective: 1719971471, // 30 days from today (2nd of July 2024), time in which the owner of the NAME can accept the trade
        expiration: 1722660671, // 60 days from today (2nd of July 2024), an extra month after the effective date to allow the owner of the NAME to accept it
        allowedRoot: 0x6c9e33165e145e2ae0303097f79b5a91721d83c34291a94e769c65d7cb8bc1a7, // Merkle root allowing only the owner of the asset to accept the trade
        salt: 0x61647662736664627364666273646662736466627364666264626664736e7479 // The salt created for the auction
    },
    sent: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA contract address
            value: 200000000000000000000, // 200 MANA
            extra: 0x // No extra data is needed
        }
    ],
    received: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0x7518456ae93eb98f3e64571b689c626616bb7f30, // DCL Registrar contract address
            value: 20297805150211737582237783260270391886773425187705606004622572049666906448004, // NAME token ID
            extra: 0x, // No extra data required
            beneficiary: 0x0000000000000000000000000000000000000000 // The creator of the trade will receive the asset
        }
    ]
}
```

Bid #2 has a better offer for the owner of the NAME, meaning that when the trade becomes effective, it is the one with the highest chance of being accepted.

The marketplace contract introduces the concept of a Trade ID, which is formed by hashing the `salt`, the caller of the `accept` function (which in this case would be the owner of the asset), and the received assets. With this Trade ID, when an offer is accepted, all other auction signatures will be revoked to prevent future usage (and preventing the need for users to manually cancel them). In this case, if Bid #2 is accepted, Bid #1 becomes revoked automatically.

**Creating a Public Order for Multiple Items** (Put 3 different items from the same collection on sale for 100 MANA)

In this example, the owner of collection `0xf8a87150ca602dbeb2e748ad7c9c790d55d10528` wants to sell (as primary sale) for 100 MANA the 3 items found in the collection (with item ids 0,1,2)

This can be achieved with the following Trade.

```js
{
    checks: {
        uses: 0 // The creator might want this Trade to be used multiple times. Useful for these kind of assets given that they are minted and the creator does not need to sign a new Trade each time.
    },
    sent: [
        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 0, // Item id
            extra: 0x// No extra data is needed

        },
        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 1, // Item id
            extra: 0x// No extra data is needed

        },
        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 2, // Item id
            extra: 0x// No extra data is needed

        },
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA contract address
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        }
    ]
}
```

This is not limited to just collection items, Orders for multiple items can be done with any kind of assets.

**Bidding for Multiple Items** (Bid 100 MANA to buy 3 different collection items)

In this example, a user wants to offer 100 MANA to buy the items 0,1,2 from the collection `0xf8a87150ca602dbeb2e748ad7c9c790d55d10528`

This can be achieved with the following Trade.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA contract address
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // No extra data is needed
        }
    ],
    received: [

        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 0, // Item id
            extra: 0x// No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        },
        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 1, // Item id
            extra: 0x// No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset

        },
        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 2, // Item id
            extra: 0x// No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        },
    ]
}
```

This is not limited to just collection items, Bids for multiple items can be done with any kind of assets.

**Bundles** (Selling a bundle consisting of a LAND and a Decentraland NAME for 100 MANA)

In this example, a user wants to sell a LAND with id `34028236692093846346337460743176821145700` and a NAME with id `20297805150211737582237783260270391886773425187705606004622572049666906448004` for 100 MANA as a bundle.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND contract address
            value: 34028236692093846346337460743176821145700, // LAND Token id
            extra: 0x// No extra data is needed
        },
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0x7518456ae93eb98f3e64571b689c626616bb7f30, // DCL Registrar contract address
            value: 20297805150211737582237783260270391886773425187705606004622572049666906448004, // NAME token id
            extra: 0x// No extra data is needed
        },
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA contract address
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        }
    ]
}
```

**Asset Swaps** (Swapping a Decentraland NAME for a LAND)

In this example, a user wants to swap a LAND with id `34028236692093846346337460743176821145700` for a NAME with id `20297805150211737582237783260270391886773425187705606004622572049666906448004`.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND contract address
            value: 34028236692093846346337460743176821145700, // LAND Token id
            extra: 0x // No extra data is needed
        },
    ],
    received: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0x7518456ae93eb98f3e64571b689c626616bb7f30, // DCL Registrar contract address
            value: 20297805150211737582237783260270391886773425187705606004622572049666906448004, // NAME token id
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        },
    ]
}
```

**Hot Sale** (Listing a Wearable on sale for 100 MANA, with a Hot Sale at 50 MANA)

A user has a Wearable on sale for sale for 100 MANA, this user created a Trade to list is for sale with the following characteristics:

```js
{
    checks: {
        uses: 0, // This trade can be used an unlimited amount of times until cancelled
        expiration: 1719971471 // 30 days from today (2nd of July 2024)
    },
    sent: [
        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 0, // Item id
            extra: 0x// No extra data is needed

        },
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA contract address
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        }
    ]
}
```

If the user wants to create a hot sale for selling this item at a price of 50 MANA, that only lasts 12 hours. They just need to sign a new trade with a shorter expiration.

```js
{
    checks: {
        uses: 0, // This trade can be used an unlimited amount of times until cancelled
        expiration: 1720025471 // 12 hours from now (2nd of July 2024)
    },
    sent: [
        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 0, // Item id
            extra: 0x// No extra data is needed

        },
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA contract address
            value: 50000000000000000000, // 50 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        }
    ]
}
```

The item would be on a "Hot Sale" until the 12 hours pass.

Other properties can be used to play with it, like a "Hot Sale" for the first 10 buyers "uses: 10".

**Discounts**

Discounts for single items can be applied just like hot sales.

For more broad discounts, we present Coupons.

Imagine the user wants to create a Coupon were all Trades involving their collection items have a 10% discount.

First the user must create the Trade:

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 3, // ASSET_TYPE_COLLECTION_ITEM;
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection contract address
            value: 0, // Item id
            extra: 0x// No extra data is needed

        },
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA contract address
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        }
    ]
}
```

Then create the Coupon:

```js
{
    checks: {
        ... // Coupons have the same checks as Trades
    },
    couponAddress: 0xd35147be6401dcb20811f2104c33de8e97ed6818 // The address of the CollectionDiscountCoupon, TODO: when deployed, update it with the real one for this example
    data: abi.encode({
        discountType: 1, // DISCOUNT_TYPE_RATE,
        discount: 500_000, // 50% discount
        root: 0x8b51132a209611e5b135381b6e9758608c0ae75f58713c085c07b1078000835d // Merkle root of all the collection addresses that are included in the discount
    })
}
```

Any user can then accept the Trade with the Coupon calling the `acceptWithCoupon` function. One thing to take into consideration, is that the coupon has to be sent with the extra `callerData` property, containing the proof for the collection of the item being bought.

```js
{
    checks: {
        ... // Coupons have the same checks as Trades
    },
    couponAddress: 0xd35147be6401dcb20811f2104c33de8e97ed6818 // The address of the CollectionDiscountCoupon, TODO: when deployed, update it with the real one for this example
    data: abi.encode({
        discountType: 1, // DISCOUNT_TYPE_RATE,
        discount: 500_000, // 50% discount
        root: 0x8b51132a209611e5b135381b6e9758608c0ae75f58713c085c07b1078000835d // Merkle root of all the collection addresses that are included in the discount
    }),
    callerData: abi.encode({
        proofs: [[
            "0xc167b0e3c82238f4f2d1a50a8b3a44f96311d77b148c30dc0ef863e1a060dcb6",
            "0xa79ebbac0bd88ae2719a62d5aaba036edfff99dd3a91dded8556a579ac7038ec",
            "0xe3079e8282d5b52189f80e2c4bd7fc444fde7bad64d9acbe9990ffb261561fbc"
        ]]
    })
}
```

Maybe the seller is selling 3 items in the same Trade, 2 from the same collection and 1 from a different.

For the coupon to work in this case, all collections should be supported in the coupon, as well as defined in the correct order.

```
Trade {
    sent [collection1Item1, collection1Item2, collection2Item1]
}

Coupon {
    callerData {
        proofs [collection1Proof, collection1Proof, collection2Proof]
    }
}
```

CollectionDiscountCoupon discounts can also be flat. Meaning that the discount can be a given amount instead of a rate. This can be done with `discountType: 2`. The provided `discount` value will be deducted from the ERC20 asset price.

**Revenue Share**

For this example, an user wants to sell a LAND for 100 MANA, but can decide that 70 MANA goes to himself, and 30 to another address.

They can do so by creating a Trade with 2 different MANA Assets being received:

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 2, // ASSET_TYPE_ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND contract address
            value: 34028236692093846346337460743176821145700, // Token id of parcel 100,100
            extra: 0x// No extra data is needed
        }
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA contract address
            value: 70000000000000000000, // 70 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000, // The creator of the Trade will receive the asset
        },
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA contract address
            value: 30000000000000000000, // 30 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x24e5F44999c151f08609F8e27b2238c773C4D020, // This address will receive the MANA, instead of the creator of the Trade
        }
    ]
}
```

## Development

Run tests with `forge test` and build contracts with `forge build`

## Notes For Auditors

The contracts that will be deployed are:

- src/marketplace/DecentralandMarketplacePolygon.sol
- src/marketplace/DecentralandMarketplaceEthereum.sol
- src/coupons/CouponManager.sol
- src/coupons/CollectionDiscountCoupon.sol

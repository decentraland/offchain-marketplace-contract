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

For how signatures compatible with these smart contracts can be created, please refer to the UI example found in ui/src/pages/index.tsx.

## Trade Id

The Trade ID is a value primarily used to reference trades involved in the same operation. The Trade ID is composed of:

- A salt, provided in the checks, mainly used to differentiate trades that have the same parameters from each other.

- The user executing the trade.

- The assets being received by the trade signer.

One of the main uses of the Trade ID is for auctions.

An auction is a sale process where assets are sold to the highest bidder. Although the marketplace does not handle auctions directly, dApps can create an auction system by leveraging the Trade ID.

On the frontend, the owner of an asset will indicate they want to auction it for a certain starting price and specify the auction duration. This data is stored on the backend, which users can later access to start bidding. Along with the auction data, a random salt will be created and stored.

When the auction is created on the backend, users will be able to see that an auction is taking place. Bidders can now start bidding. To do so, they will create and sign trades using the salt and auction data stored in the backend. These trades, also stored in the backend, will be viewable by the auctioneer.

The auctioneer can accept the highest bidder's offer when ready and execute the swap on the blockchain using the marketplace contract.

Once the bid is accepted, the signature for that trade will no longer be usable. All other trades bidding on the auction will be rendered unusable as well, thanks to the Trade ID.

This mechanism prevents users from having active trades that are no longer necessary, eliminating the need to manually revoke them.

As mentioned before, this works because all bids will have the same Trade ID, composed by:

- The same salt that was created along with the auction.

- The caller, which is the owner of the asset, accepting the bid.

- The received assets of the bid, which is in this case the asset owned by the caller.

## Examples

The examples found on this section will describe some of the many Trade types that the Marketplace smart contracts in this repository can enable.

For simplicity, the checks on all Trades and Coupons will default to the following values:

```js
{
    uses: 1, // The trade can only be used once
    expiration: 1719971471, // 30 days from today (2nd of July 2024)
    effective: 0, // The trade can be used from the time it has been signed onwards
    salt: 0x61647662736664627364666273646662736466627364666264626664736e7479, // Some random salt, used to make the signature as unique as possible to avoid collisions with other Trades with the same data.
    contractSignatureIndex: 0, // The current contract signature index
    signerSignatureIndex: 0, // The current signer signature index of the signer of this Trade
    allowedRoot: 0x0000000000000000000000000000000000000000000000000000000000000000, // The merkle root of the allowed addresses that can accept the Trade. In this case, it is open for everyone to accept
    externalChecks: [], // The external checks that will be validated on external contracts. No external checks will be performed in this case
}
```

**1. Creating a Public Order**

In this example, the owner of a LAND on coords 100,100, wants to list it for sale at a price of 100 MANA.

The owner of the LAND will have to sign a Trade containing the following properties.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 3, // ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND
            value: 34028236692093846346337460743176821145700, // Token id of LAND at coords 100,100
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 1, // ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000, // The signer of the Trade (the seller) will receive the MANA.
        }
    ]
}
```

**2. Creating a Bid**

Bids are similar to Orders with the difference that it is the buyer the one signing the Trade instead of the seller.

For this example, the buyer wants to offer 100 MANA for an Estate.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 1, // ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA
            value: 100000000000000000000, // 100 MANA
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 3, // ERC721
            contractAddress: 0x959e104e1a4db6317fa58f8295f586e1a978c297, // Estate
            value: 100, // Estate token id
            extra: abi.encode(0xa12a0c5cb9a6747da8a8b212604c12f2533b476461f62720c21760c7fb05cd0c), // Encoded estate fingerprint
            beneficiary: 0x0000000000000000000000000000000000000000, // The signer of the Trade (the buyer) will receive the Estate.
        }
    ]
}
```

As you can see from the Trade, the only real difference with an Order is that the sent and received assets are swapped. This simple abstraction is what differentiates a Bid from an Order.

**3. Create a Private Order**

There might be some cases in which the owner of an asset wants to put it on sale, but only for a handful of users to be able to buy it. Maybe because of an event, or maybe as a special discount for some winners.

For this example, the owner a Decentraland wearable wants to sell it for 50 MANA. But only the addresses `0x2e234DAe75C793f67A35089C9d99245E1C58470b`, `0x24e5F44999c151f08609F8e27b2238c773C4D020` and `0x2f89eC84e0413950d9ADF8e56dd56c2B2f5066cb` are allowed to buy it.

This can be achieved with the `allowedRoot` check. Which contains a merkle root for the allowed addresses that are allowed to accept it.

```js
{
    checks: {
        allowedRoot: 0xb22d9e7d0895dfb81a418295969a1a2f03c46ba31cfcf5ba1e8c83332fe554d0 // Merkle root for the allowed addresses
    },
    sent: [
        {
            assetType: 3, // ERC721
            contractAddress: 0x024ca955066ce48464ce1eae6106e6fa454ec42a, // Wearable Collection
            value: 0, // Token Id
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA
            value: 50000000000000000000, // 50 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

One of the allowed callers must then execute the Trade by providing a merkle proof used to validate that they are allowed to do so.

```js
{
  checks: {
    allowedProof: [0xf5f79f4414e087ded9df3f796c801706cc3e3061b0f607a13ac6a2a64a07663b]; // The proof for address 0x2e234DAe75C793f67A35089C9d99245E1C58470b
  }
}
```

In this case, `0x2e234DAe75C793f67A35089C9d99245E1C58470b` provides a valid proof, succefuly executing the Trade.

**4. Auction**

Auctions using this marketplace are basically multiple bids for a certain asset (or assets).

The marketplace provides 2 different tools to make the UX on Auctions better.

These are:

- The `effective` timestamp. Which determines at which point in time an auction trade can be executed.

- The `trade id`. An id composed by hashing the trade salt, caller (the one who accepts the Trade, which for auctions, would be the owner of the auctioned assets) and the received assets. Used to revoke all signatures on the auction once finished.

Let's say that a user wants to auction a Decentraland NAME they own. Starting price at 20 MANA, with an auction duration of 1 week.

This data will be stored on a server off-chain, accessible by users on the marketplace UI.

Users that want to participate in the auction can sign bid trades, using the auction data as reference.

For example:

Bid #1

```js
{
    checks: {
        effective: 1720587071, // 7 days from today (2nd of July 2024)
        salt: 0x61647662736664627364666273646662736466627364666264626664736e7479 // The salt created for the auction
    },
    sent: [
        {
            assetType: 1, // ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA
            value: 30000000000000000000, // 30 MANA
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 3, // ERC721
            contractAddress: 0x7518456ae93eb98f3e64571b689c626616bb7f30, // DCL Registrar
            value: 20297805150211737582237783260270391886773425187705606004622572049666906448004, // Token id
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

Bid #2

```js
{
    checks: {
        effective: 1720587071, // 7 days from today (2nd of July 2024)
        salt: 0x61647662736664627364666273646662736466627364666264626664736e7479 // Needs to use the same salt so both bids can have the same trade id
    },
    sent: [
        {
            assetType: 1, // ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA
            value: 50000000000000000000, // 50 MANA
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 3, // ERC721
            contractAddress: 0x7518456ae93eb98f3e64571b689c626616bb7f30, // DCL Registrar
            value: 20297805150211737582237783260270391886773425187705606004622572049666906448004, // Token id
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

The effective date is a way in which bidders can be certain that the auctioner will not end the auction sooner than expected. It is not required, this just provides a way to create "strict" auctions that cannot be finished early.

Given that bid #2 has a better offer, the owner of the asset will probably accept that one when the time comes. And because both bids have the same trade id, once bid #2 is accepted, the bid #1 becomes invalidated, preventing any future use in case the asset comes back to the original owner.

The `allowedRoot` check, explained in the **Private Order** example, should be used as well so only the auctioner can accept the bids. This combined with the trade id, gives the best auctioning experience with this contract.

**5. Creating a Public Order for Multiple Items**

Any user might want to be able to sell items in batch. For example, as a promotion, a Decentraland wearable creator might want to sell 3 items in batch for 100 MANA.

Any amount of assets can be defined on the sent and received properties of the Trade. In this case, the creator would define the 3 items as being sent, and the 100 MANA as the received asset.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale);
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Wearable Collection
            value: 0, // Item id
            extra: 0x // Empty extra data
        },
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale);
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Wearable Collection
            value: 1, // Item id
            extra: 0x // Empty extra data
        },
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale);
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Wearable Collection
            value: 2, // Item id
            extra: 0x // Empty extra data

        },
    ],
    received: [
        {
            assetType: 1, // ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // No extra data is needed
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

For this particular case, when the Trade is accepted, the items will be bough for 100 MANA total.

**6. Bidding for Multiple Items** (Bid 100 MANA to buy 3 different collection items)

Similar to mutiple item orders, but with the sent and received assets swapped.

This time the bidder will sign a Trade determining that they want to purchase 3 items for 100 MANA.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 1, // ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA
            value: 100000000000000000000, // 100 MANA
            extra: 0x // No extra data is needed
        }
    ],
    received: [
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale)
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Wearable Collection
            value: 0, // Item id
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        },
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale)
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Wearable Collection
            value: 1, // Item id
            extra: 0x // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        },
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale)
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Wearable Collection
            value: 2, // Item id
            extra: 0x // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        },
    ]
}
```

**6. Asset Swaps**

Trades could be made between any kind of assets, not necessarily between an ERC721 and ERC20. 

For this example, a user is willing to trade their LAND for a Decentraland NAME

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 3, // ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND
            value: 34028236692093846346337460743176821145700
            extra: 0x // Empty extra data
        },
    ],
    received: [
        {
            assetType: 3, // ERC721
            contractAddress: 0x7518456ae93eb98f3e64571b689c626616bb7f30, // DCL Registrar
            value: 20297805150211737582237783260270391886773425187705606004622572049666906448004,
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        },
    ]
}
```

As long as the assets are supported by the marketplace implementations of the network being used, the combinations are plenty.

**7. Hot Sale**

Imagine that you already have a Decentraland wearable on sale for 100 MANA. You now want, as some sort of promotion, sell the item for 50 MANA instead but for the next 12 hours only. After the 12 hours, the sell price returns to 100.

The original Trade, asking for 100 MANA would look like:

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale)
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection
            value: 0, // Item id
            extra: 0x // Empty extra data

        },
    ],
    received: [
        {
            assetType: 1, // ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

The same user can then sign a new Trade with an expiration of 12 hours and a lowered price, which users can enjoy for a limited time only.

```js
{
    checks: {
        expiration: 1720025471 // 12 hours from now (2nd of July 2024)
    },
    sent: [
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale)
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection
            value: 0, // Item id
            extra: 0x // Empty extra data

        },
    ],
    received: [
        {
            assetType: 1, // ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA
            value: 50000000000000000000, // 50 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

Whatever is shown to the user is to be handled off chain. In this case, as long as the discounted Trade is valid, the frontend could show that one instead of the original.

**8. Discounts**

For single elements, discounts can be applied similarly to Hot Sales.

For more broad discounts, the marketplace smart contract provides Coupons.

For this example, a Decentraland creator wants to generate a discount of 50% for all the collection items they have on sale.

This particular case is already supported by the CollectionDiscountCoupon, a smart contract containing this coupon logic.

First the user must create the Trade:

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 4, // Decentraland Collection Item (Primary Sale)
            contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection
            value: 0, // Item id
            extra: 0x // Empty extra data

        },
    ],
    received: [
        {
            assetType: 1, // ERC20
            contractAddress: 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4, // Polygon MANA
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

Then create the Coupon:

```js
{
    checks: {
        ...
    },
    couponAddress: 0xd35147be6401dcb20811f2104c33de8e97ed6818 // The address of the CollectionDiscountCoupon, TODO: when deployed, update it with the real one for this example
    data: abi.encode({
        discountType: 1, // Percentage, 2 would be for a flat rate
        discount: 500_000, // 50% discount
        root: 0x8b51132a209611e5b135381b6e9758608c0ae75f58713c085c07b1078000835d // Merkle root of all the collection addresses that are included in the discount
    })
}
```

Any user that has access to the Coupon signature can then apply it to a Trade and execute it.

Sending the proof that the collection is part of the root has to be done by the caller by providing it in the `callerData` of the Coupon argument.

```js
{
    checks: {
        ...
    },
    couponAddress: ...
    data: ...
    callerData: abi.encode({
        proofs: [[
            "0xc167b0e3c82238f4f2d1a50a8b3a44f96311d77b148c30dc0ef863e1a060dcb6",
            "0xa79ebbac0bd88ae2719a62d5aaba036edfff99dd3a91dded8556a579ac7038ec",
            "0xe3079e8282d5b52189f80e2c4bd7fc444fde7bad64d9acbe9990ffb261561fbc"
        ]]
    })
}
```

This coupon implementation allows for multiple item Orders as well.

The only requirement is that the proof of each collection item being traded is in the same order.

For example

```js
// Trade
{
    sent: [collection1Item1, collection1Item2, collection2Item1]
}

// Coupon
{
    callerData: {
        proofs: [collection1Proof, collection1Proof, collection2Proof]
    }
}
```

This coupon only works for Decentraland Collection Items, trying to apply it on different assets will fail.

**9. Revenue Share**

When trading, maybe the seller want to share the tokens earned between different addresses.

This can easily be done by defining extra ERC20 assets in the trade.

For example, some user wants to sell a LAND for 100 MANA, but chooses that the MANA should go 20% to themselves and 80% to charity.

The Trade for this would be:

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 3, // ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND
            value: 34028236692093846346337460743176821145700,
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 1, // ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA
            value: 20000000000000000000, // 20 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        },
        {
            assetType: 1, // ASSET_TYPE_ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA contract address
            value: 80000000000000000000, // 80 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x24e5F44999c151f08609F8e27b2238c773C4D020, // The address of the charity wallet
        }
    ]
}
```

**10. Shopping Cart**

The marketplace accepts multiple trades to be executed. This allows dapps to implement a shopping cart by providing the user with all the trades and signatures of the assets they want to purchase and execute them with a single transaction.

The only drawback is that the shopping cart should support same network assets. In the case of Decentraland, the shopping cart would NOT be able to hold LAND/Estates and Wearables at the same time.

For example, there are 2 different Trades,

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 3, // ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND
            value: 34028236692093846346337460743176821145700, // Token id of LAND at coords 100,100
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 1, // ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA
            value: 100000000000000000000, // 100 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

&

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 3, // ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND
            value: 17014118346046923173168730371588410572850, // Token id of LAND at coords 50,50
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 1, // ERC20
            contractAddress: 0x0f5d2fb29fb7d3cfee444a200298f468908cc942, // MANA
            value: 200000000000000000000, // 200 MANA
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000
        }
    ]
}
```

Any user can add those LANDs to the shopping cart, and when ready, execute both trades in a single transaction by calling the `accept(Trade[] _trades)` function with both LAND trades.

**11. External Checks**

Users are able to indicate who can accept a trade not only using the `allowedRoot` (explained in the "Create a Private Order" example). Users can limit who is allowed by defining external checks.

External checks are validations performed on external smart contracts. 

Some examples are; Having x amount of tokens from an NFT collection or fungible asset; Owning a particular NFT.

For example, Some user wants to create a collection discount coupon that can only be applied by users that have at least one wearable from a particular collection they created.

To do so, they must add an external check to the coupon:

```js
{
    checks: {
        externalChecks: [
            {
                contractAddress: 0xf8a87150ca602dbeb2e748ad7c9c790d55d10528, // Collection
                selector: 0x70a08231, // balanceOf(address,uint256) selector, will check the balance the caller has for that collection
                value: 1, // Will check that the balance is 1 or more
                required: true // This check has to pass. For cases in which there is only 1 check, true or false is the same
            }
        ]
    },
    couponAddress: ...
    data: ...
    callerData: ...
}
```

This coupon can only be used if the caller has at least 1 wearable from the `0xf8a87150ca602dbeb2e748ad7c9c790d55d10528` collection.

Maybe the user wants to be more flexible and allow users to apply the coupon if they own a wearable of one collection or another.

They can do so by adding more external checks like:

```js
{
    checks: {
        externalChecks: [
            {
                contractAddress: collectionA, // First collection to check
                selector: 0x70a08231,
                value: 1
                required: false // This means optional
            },
            {
                contractAddress: collectionB, // Second collection to check
                selector: 0x70a08231,
                value: 1,
                required: false // At least one optional check has to pass in order to be valid
            },
        ]
    },
    couponAddress: ...
    data: ...
    callerData: ...
}
```

The contract supports checking `balanceOf` and `ownerOf` natively. But if the selector provided does not match any of those, it will fallback to using the provided selector with the caller and provided value, and expect that the function returns `true`. The user could provide a selector that is `myCustomCheck(address,uint256)`, and it should return true.

**12. USD Pegged MANA Trades**

Users are able to create Trades that will involve trading an Asset for MANA, but at a determined USD price.

For example, the owner of LAND 100,100 wants to list it for sale at a price of 100 USD, to be paid in MANA.

The owner of the LAND will have to sign a Trade containing the following properties.

```js
{
    checks: {
        ...
    },
    sent: [
        {
            assetType: 3, // ERC721
            contractAddress: 0xf87e31492faf9a91b02ee0deaad50d51d56d5d4d, // LAND
            value: 34028236692093846346337460743176821145700, // Token ID of LAND at coords 100,100
            extra: 0x // Empty extra data
        }
    ],
    received: [
        {
            assetType: 2, // ASSET_TYPE_USD_PEGGED_MANA
            contractAddress: 0x0000000000000000000000000000000000000000, // This is ignored by the contract as the MANA contract address will be used.
            value: 100000000000000000000, // 100 USD. Keep in mind that it has to be set in wei with 18 decimal places.
            extra: 0x, // Empty extra data
            beneficiary: 0x0000000000000000000000000000000000000000, // The signer of the Trade (the seller) will receive the MANA.
        }
    ]
}
```

When the Trade is executed, the signer will receive 100 USD in MANA according to the current rate provided by Chainlink price feeds.

If the price of MANA when the Trade is executed is 50 cents, ultimately, the amount received by the signer will be 200 MANA.

## Development

This repository was built using foundry.

To be able to do anything more than just look at it you will need to install foundry.

The instructions on how to do so can be found [here](https://book.getfoundry.sh/).

Once foundry has been installed,

- Build contracts with `forge build`
- Run tests with `forge test`

Make sure to read the framework docs to understand everything it offers.

## Deployment

Before deploying,

- Run `forge clean` to reset the workspace.
- Run `forge build` to prepare the contracts.
- Run `forge test` to make sure all tests pass.

Just running `forge test` should be enough, but I find it a good practice to run the other commands as well first to make sure.

It would be a good idea to check the foundry deployment [docs](https://book.getfoundry.sh/forge/deploying).

The contracts are to be deployed in the following order,

Ethereum: 

- DecentralandMarketplaceEthereum.sol
- CouponManager.sol (Optional as there are no Coupons for the Ethereum Marketplace right now)

Polygon:

- DecentralandMarketplacePolygon.sol
- CollectionDiscountCoupon.sol
- CouponManager.sol

The step by step of how to deploy them using foundry is,

Ethereum:

**DecentralandMarketplaceEthereum.sol**

```bash
$ forge create --rpc-url {rpcUrl} --constructor-args 0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce 0x0000000000000000000000000000000000000000 0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce 25000 0x0f5d2fb29fb7d3cfee444a200298f468908cc942 0x82A44D92D6c329826dc557c5E1Be6ebeC5D5FeB9 86400 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 3600 --private-key {privateKey} --etherscan-api-key {etherscanApiKey} --verify src/marketplace/DecentralandMarketplaceEthereum.sol:DecentralandMarketplaceEthereum
```

Constructor Args:

- `0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce` DAO as Owner
- `0x0000000000000000000000000000000000000000` No Coupon Manager
- `0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce` DAO as Fee Collector
- `25000` Fee rate (2.5%)
- `0x0f5d2fb29fb7d3cfee444a200298f468908cc942` MANA
- `0x82A44D92D6c329826dc557c5E1Be6ebeC5D5FeB9` MANA / ETH Chainlink Aggregator
- `86400` MANA / ETH Aggregator Heartbeat (Used as tolerance)
- `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419` ETH / USD Chainlink Aggregator
- `3600` ETH / USD Aggregator Heartbeat (Used as tolerance)

**CouponManager.sol**

```bash
$ forge create --rpc-url {rpcUrl} --constructor-args {decentralandMarketplaceEthereum} 0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce \[\] --private-key {privateKey} --etherscan-api-key {etherscanApiKey} --verify src/coupons/CouponManager.sol:CouponManager
```

Constructor Args:

- `decentralandMarketplaceEthereum` The address of the already deployed Ethereum marketplace
- `0x9A6ebE7E2a7722F8200d0ffB63a1F6406A0d7dce` DAO as Owner
- `\[\]` There are no coupon implementations currently on Ethereum so this goes as an empty array

> After the CouponManager is deployed on Ethereum. Call the `updateCouponManager` on the DecentralandEthereumMarketplace contract as the owner to set the CouponManager.

Polygon:

**DecentralandMarketplacePolygon.sol**

```bash
$ forge create --rpc-url {rpcUrl} --constructor-args 0x0E659A116e161d8e502F9036bAbDA51334F2667E 0x0000000000000000000000000000000000000000 0xB08E3e7cc815213304d884C88cA476ebC50EaAB2 25000 0x90958D4531258ca11D18396d4174a007edBc2b42 25000 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4 0xA1CbF3Fe43BC3501e3Fc4b573e822c70e76A7512 27 --private-key {privateKey} --etherscan-api-key {polygonscanApiKey} --verify src/marketplace/DecentralandMarketplacePolygon.sol:DecentralandMarketplacePolygon
```

Constructor Args:

- `0x0E659A116e161d8e502F9036bAbDA51334F2667E` SAB as owner
- `0x0000000000000000000000000000000000000000` No Coupon Manager
- `0xB08E3e7cc815213304d884C88cA476ebC50EaAB2` DAO as Fee Collector
- `25000` Fee rate (2.5%)
- `0x90958D4531258ca11D18396d4174a007edBc2b42` Royalty Manager
- `25000` Royalty rate (2.5%)
- `0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4` MANA
- `0xA1CbF3Fe43BC3501e3Fc4b573e822c70e76A7512` MANA / USD Chainlink Aggregator
- `27` MANA / USD Aggregator Heartbeat (Used as tolerance)

**CollectionDiscountCoupon.sol**

```bash
$ forge create --rpc-url {rpcUrl} --private-key {privateKey} --etherscan-api-key {polygonscanApiKey} --verify src/coupons/CollectionDiscountCoupon.sol:CollectionDiscountCoupon      
```

**CouponManager.sol**

```bash
$ forge create --rpc-url {rpcUrl} --constructor-args {decentralandMarketplacePolygon} 0x0E659A116e161d8e502F9036bAbDA51334F2667E \[{collectionDiscountCoupon}\] --private-key {privateKey} --etherscan-api-key {polygonscanApiKey} --verify src/coupons/CouponManager.sol:CouponManager
```

Constructor Args:

- `decentralandMarketplacePolygon` The address of the already deployed Polygon marketplace
- `0x0E659A116e161d8e502F9036bAbDA51334F2667E` SAB as owner
- `\[{collectionDiscountCoupon}\]` The deployed CollectionDiscountCoupon as the only allowed discount

> After the CouponManager is deployed on Polygon. Call the `updateCouponManager` on the DecentralandPolygonMarketplace contract as the owner to set the CouponManager.

## Notes For Auditors

The contracts that will be deployed are:

- src/marketplace/DecentralandMarketplacePolygon.sol
- src/marketplace/DecentralandMarketplaceEthereum.sol
- src/coupons/CouponManager.sol
- src/coupons/CollectionDiscountCoupon.sol

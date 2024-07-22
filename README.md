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

## Development

Run tests with `forge test` and build contracts with `forge build`

## Notes For Auditors

The contracts that will be deployed are:

- src/marketplace/DecentralandMarketplacePolygon.sol
- src/marketplace/DecentralandMarketplaceEthereum.sol
- src/coupons/CouponManager.sol
- src/coupons/CollectionDiscountCoupon.sol

## SmallPP

## Smart Contract(s) with the following functionalities,tests:

- [x] Liquidity Providers can deposit and withdraw liquidity.
  - [x] deposit()
  - [x] withdraw()
- [x] A way to get the realtime price of the asset being traded.
  - [x] oracle() Chainlink
- [x] Traders can open a perpetual position for BTC, with a given size and collateral.
  - BTC speculation
- [x] Traders can increase the size of a perpetual position.
  - [x] updatePositionsize()
- [x] Traders can increase the collateral of a perpetual position.
  - [x] updatePositioncollateral()
- [x] Traders cannot utilize more than a configured percentage of the deposited liquidity.
- [x] Liquidity providers cannot withdraw liquidity that is reserved for positions.

## misc

- [-] Recheck and fix decimals

## README

- How does the system work? How would a user interact with it?
- What actors are involved? Is there a keeper? What is the admin tasked with?
- What are the known risks/issues?
- Any pertinent formulas used.

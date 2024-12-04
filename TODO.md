## A protocol name

## Smart Contract(s) with the following functionalities,tests:

- Liquidity Providers can deposit and withdraw liquidity.
  - deposit()
  - withdraw()
- A way to get the realtime price of the asset being traded.
  - oracle()
- Traders can open a perpetual position for BTC, with a given size and collateral.
  - BTC speculation
- Traders can increase the size of a perpetual position.
  - updatePosition()
- Traders can increase the collateral of a perpetual position.
  - updatePosition()
- Traders cannot utilize more than a configured percentage of the deposited liquidity.
- Liquidity providers cannot withdraw liquidity that is reserved for positions.

## README

- How does the system work? How would a user interact with it?
- What actors are involved? Is there a keeper? What is the admin tasked with?
- What are the known risks/issues?
- Any pertinent formulas used.

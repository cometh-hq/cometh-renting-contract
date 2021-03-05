# cometh-renting-contract

## Factory

Factory allows spaceship owners to make rental proposal. They can choose the NFTs that they want to rent, the duration of the contract, the percentage that they want of the gains and a fixed fee which will be paid by tenant when they accept the proposal.

Details:
 - NFT must be exited from the game
 - the ownership of the NFTs will be transferred to the factory while the proposal exist
 - the lender can close the proposal while nobody have accepted it

## RentingContract

When a proposal is accepted, a new RentingContract is deployed. This contract will receive the ownership of NFTs and the lender will become an operator for the RentingContract on the game. The contract can be close by the tenant or the lender after the end timestamp is reached, but the contract will stand while no one close it. Retrieving gains require one call for each ERC20 that was rewarded to the RentingContract.

Details:
 - lenders cannot loose their NFTs
 - gains can be claimed at any time by both parties
 - MUST used to interact with the game need ti be provided by lenders
 - lenders will receive all the gains in MUST (jump rewards)

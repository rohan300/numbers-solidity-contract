# Solidity Game

This is a Solidity smart contract for an "Odd or Even" guessing game on the Ethereum blockchain.

## Overview

The contract allows two players to:

- Register by sending 200 wei  
- Commit a secret number between 1-100 plus a random salt
- Reveal their number
- Contract checks if sum of numbers is odd or even 
- Winner gets initial deposit plus the sum
- Loser gets initial deposit minus the sum

Key features:

- Secure commit/reveal scheme
- Custom events for game status  
- Timeout mechanism
- Withdrawal capability
- Game reset

## Usage 

This contract is intended to be deployed on the Ethereum blockchain. Players can interact with it through a Web3 provider like Metamask.

Pick a number, commit the salted hash, then reveal your numbers to see who wins!

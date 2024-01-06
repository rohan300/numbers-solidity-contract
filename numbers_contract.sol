// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract OddorEven {
    uint private lastActionTime;
    uint16 private constant DEPOSIT = 200;
    mapping(address=>uint16) private balances;
    uint8 private flag;

    // Player Struct
    struct Player {
        address addr;
        uint8 num;
        bytes32 commitment;
    }

    Player private playerA;
    Player private playerB;

    // Events
    event Register(string player); 
    event NumberCommitted(address player, bytes32 commitment);
    event NumberRevealed(address player, uint8 number);
    event WinnerDeclared(address winner);
    event TimeOut();
    event Withdrawal(address player, uint amount);
    event GameReset();

    // Checks if a player is accessing the function
    modifier onlyPlayers() {
        require(playerA.addr == msg.sender || playerB.addr == msg.sender, "Only players can participate.");
        _;
    }

    /*
    * Allow players to register for the game
    * PlayerA gets registered first
    * Contract must receive exactly 200 wei from the player for them to get registered
    */
    function joinGame() external payable {
        require(msg.value == DEPOSIT, "You must send 200 Wei exactly to be able to play the game.");
        require(playerA.addr == address(0) || playerB.addr == address(0), "A game is currently running.");
        if (playerA.addr == address(0)) {
            playerA = Player(msg.sender, 0, bytes32(0));
            balances[msg.sender] = DEPOSIT;
            lastActionTime = block.timestamp;
            emit Register("Player A has successfully registered.");
        }

        else {
            require(msg.sender != playerA.addr, "You cannot play against yourself.");
            playerB = Player(msg.sender, 0, bytes32(0));
            balances[msg.sender] = DEPOSIT;
            lastActionTime = block.timestamp;
            emit Register("Player B has successfully registered.");
        }
    }

    /*
    * @param _commit secret hash of the player's number and random salt that they pick
    * Stores the commit of the player in the respective struct
    * Makes sure they have not committed already
    * @dev Example to create the hidden move using ethers:
    * ethers.utils.solidityKeccak256(["uint8", "uint64"], [<<number>>, <<salt>>]);
    */
    function commitMove(bytes32 _commit) external onlyPlayers{
        require(playerA.addr != address(0), "Player A still needs to join the game");
        require(playerB.addr != address(0), "Player B still needs to join the game");
        Player storage player = getPlayer(msg.sender);
        require(player.commitment == bytes32(0), "You have already committed a number and cannot change it.");
        player.commitment = _commit;
        emit NumberCommitted(player.addr, player.commitment);
        lastActionTime = block.timestamp;
    }

    /*
    * @param _num is the number that the player picked
    * @param _salt is the random salt that the player picked
    * Check if the hash of the salt and number are the same as the already stored commitment 
    * If both players have revealed, determine the winner
    */
    function revealCommitment(uint8 _num, uint64 _salt) external onlyPlayers {
        require(_num >= 1, "Number must be in the range [1, 100].");
        require(_num <=100 , "Number must be in the range [1, 100]");
        require(playerA.commitment != 0, "Player A needs to commit first");
        require(playerB.commitment != 0, "Player B needs to commit first");

        Player storage player = getPlayer(msg.sender);
        require(player.num == 0, "You have already revealed your number.");

        bytes32 commitment = keccak256(abi.encodePacked(_num, _salt));
        require(commitment == player.commitment, "Invalid commitment");

        player.num = _num;
        emit NumberRevealed(player.addr, player.num);
        lastActionTime = block.timestamp;

        if (playerA.num != 0 && playerB.num != 0) {
            resolveGame();
        }
    }


    /*
    * @param _addr is the address of the player that we want
    * Returns the player struct if the addresses match
    */
    function getPlayer(address _addr) private view returns (Player storage) {
        if (playerA.addr == _addr) {
            return playerA;
        }
        else {
            return playerB;
        }
    }

    /*
    * Determines the outcome of the game
    * Sums the players' numbers
    * Checks if the sum is even or odd
    * Adjusts the balances of each player in the mapping according to the result
    */
    function resolveGame() private {
        uint16 sum_num = playerA.num + playerB.num;
        if (sum_num & 1 == 0) {
            balances[playerA.addr] = DEPOSIT + sum_num;
            balances[playerB.addr] = DEPOSIT - sum_num;
            emit WinnerDeclared(playerA.addr);
        } else {
            balances[playerB.addr] = DEPOSIT + sum_num;
            balances[playerA.addr] = DEPOSIT - sum_num;
            emit WinnerDeclared(playerB.addr);
        }  
    }


    /*
    * Allows each player to withdraw their money individually
    * Make changes in the mapping to reflect the changes in withdrawl
    * Send money to the user
    */
    function withdrawFundsIndividually() external onlyPlayers{
        if (flag & uint8(1) != 1) {
            require(playerA.num != 0, "Player A needs to reveal number");
            require(playerB.num != 0, "Player B needs to reveal number");
        }

        require(balances[msg.sender] > 0, "No funds available to withdraw");
        uint16 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

         if (balances[playerA.addr] == 0 && balances[playerB.addr] == 0) {
            flag += 2;
            resetGame();
            }
        emit Withdrawal(msg.sender, amount);
    }


    // Checks if it has been 5 minutes since the last action timestamp
    function timedOut() private view returns (bool) {
        return (block.timestamp > lastActionTime + 300 seconds);
    }

    /*
    * Adjusts the balances in the mapping if there is a timeout
    * Checks if only Player A has registered so far
    * Check if one of them has not committed yet and transfer their money to the one who committed
    * Check if one of them has not revealed yet and transfer their money to the one who committed
    * If both have not revealed or committed then leave the balances the same
    * Players have to individually call withdraw after this function to withdraw their money
    */
    function processTimeout() external onlyPlayers{
        require(timedOut(), "Time left before a timeout.");
        require(flag & uint8(1) == 0, "Timeout processed, withdraw funds.");
        if (playerB.addr == address(0)) {

        }
        else if (playerA.commitment == 0 || playerB.commitment == 0) {
            if (playerA.commitment == 0) {
                uint16 amount = balances[playerA.addr];
                balances[playerA.addr] = 0;
                balances[playerB.addr] += amount;
            } else {
                uint16 amount = balances[playerB.addr];
                balances[playerB.addr] = 0;
                balances[playerA.addr] += amount;
            }
        }
        else if (playerB.num == 0 || playerA.num == 0) {
            if (playerA.num == 0) {
                uint16 amount = balances[playerA.addr];
                balances[playerA.addr] = 0;
                balances[playerB.addr] += amount;
            } else {
                uint16 amount = balances[playerA.addr];
                balances[playerA.addr] = 0;
                balances[playerB.addr] += amount;
            }
        }
        flag = 1;
        lastActionTime = block.timestamp;
        emit TimeOut();
    }

    // Reset the game by initializing the variables to their start state
    function resetGame() private  {
        require(flag & uint8(2) == 2, "The game is not complete yet");
        playerA = Player(address(0), 0, bytes32(0));
        playerB = Player(address(0), 0, bytes32(0));
        flag = 0;
        emit GameReset();
    }

    // Revert if function called
    receive() external payable {
        revert("This contract does not accept wei right now.");
    }
}

# 🎰 Decentralized Smart Contract Lottery

### Built with Foundry • Solidity • Chainlink VRF • Chainlink Automation

This project implements a **fully decentralized lottery system** where players enter by paying an ETH fee, and a **provably random winner** is selected automatically using **Chainlink VRF** and **Automation**.
The contract is written in Solidity, tested using Foundry, and deployable to both local and testnet environments.

This README walks you step-by-step through **how everything works**, **why certain decisions were made**, and **how you can deploy, test, and extend the system**.

---

# 📚 Table of Contents

1. [Overview](#-overview)
2. [Architecture](#-architecture)
3. [How the Lottery Works](#-how-the-lottery-works)
4. [Technology Stack](#-technology-stack)
5. [Project Structure](#-project-structure)
6. [Setup Instructions](#-setup-instructions)
7. [Running Tests](#-running-tests)
8. [Deploying the Contract](#-deploying-the-contract)
9. [Chainlink VRF & Automation Setup](#-vrf--automation-setup)
10. [Understanding the Code](#-understanding-the-code)
11. [Common Issues & Fixes](#-common-issues--fixes)
12. [Future Enhancements](#-future-enhancements)
13. [Author](#-author)

---

# 🧠 Overview

This Lottery Contract allows:

✔ **Anyone to enter by paying ETH**
✔ **A random winner to be selected using Chainlink VRF**
✔ **Winner selection to happen automatically using Chainlink Automation**
✔ **Funds to be transferred securely and trustlessly**
✔ **The lottery to restart after each round**

This design eliminates human influence or manipulation, making it a perfect example of **decentralized randomness**, **automation**, and **smart contract logic**.

---

# 🏗 Architecture

The system consists of:

### 1️⃣ **Raffle.sol**

* Core lottery logic
* Handles entries, randomness requests, winner selection, payouts

### 2️⃣ **HelperConfig.s.sol**

* Loads correct configuration for:

  * Local Anvil
  * Sepolia testnet
* Handles VRF subscription data

### 3️⃣ **DeployRaffle.s.sol**

* Deploys the contract on any chain using Foundry scripts

### 4️⃣ **Interactions.s.sol**

* Registers:

  * VRF subscription
  * Chainlink Automation Upkeep

### 5️⃣ **Mocks**

* Used when testing locally
* Includes a mock VRF Coordinator (Chainlink simulation)

---

# 🎮 How the Lottery Works

Here’s the entire flow :

---

## ✳️ 1. Players Enter

Players join by sending ETH ≥ entrance fee:

```solidity
raffle.enterRaffle{ value: entranceFee }();
```

They get added to the list:

```
players = [0xA1..., 0xB2..., 0xC3...]
```

---

## ✳️ 2. Automation Checks If It’s Time to Pick a Winner

Chainlink Automation calls `checkUpkeep()` on a schedule.
The contract checks:

✔ Enough time passed
✔ Lottery is OPEN
✔ At least one player exists
✔ Contract has ETH balance

If everything is valid → returns `upkeepNeeded = true`.

---

## ✳️ 3. Automation Requests Randomness

`performUpkeep()` fires → requests randomness from Chainlink VRF:

```
requestId = VRF.requestRandomWords(...)
```

Lottery state becomes `CALCULATING`.

---

## ✳️ 4. VRF Responds With a Random Number

Chainlink VRF calls back:

```solidity
fulfillRandomWords()
```

The winner =

```
winner = players[random % players.length]
```

---

## ✳️ 5. Winner Gets Paid & Lottery Resets

* ETH sent to winner
* Players list reset
* Lottery reopened

🎉 The cycle starts again.

---

# 🛠 Technology Stack

| Tool                     | Purpose                        |
| ------------------------ | ------------------------------ |
| **Solidity**             | Smart contract logic           |
| **Foundry**              | Testing, debugging, deployment |
| **Chainlink VRF v2.5**   | Random number generation       |
| **Chainlink Automation** | Automated winner selection     |
| **Anvil**                | Local blockchain               |
| **Makefile**             | One-click commands             |

---

# 📁 Project Structure

```
/smart-contract-lottery
│
├── src/
│   ├── Raffle.sol
│   ├── interfaces/
│   ├── libraries/
│
├── script/
│   ├── DeployRaffle.s.sol
│   ├── HelperConfig.s.sol
│   ├── Interactions.s.sol
│
├── test/
│   ├── RaffleTest.t.sol
│   ├── mocks/
│
├── foundry.toml
├── Makefile
└── README.md
```

---

# 🧩 Setup Instructions

### 1️⃣ Clone the repository

```bash
git clone <repo-url>
cd Thanks-Giving-25
```

### 2️⃣ Install dependencies

```bash
forge install
```

### 3️⃣ Build the project

```bash
forge build
```

### 4️⃣ Set your environment variables

Create a `.env`:

```
SEPOLIA_RPC_URL=
PRIVATE_KEY=
ETHERSCAN_API_KEY=
```

Load it:

```bash
source .env
```

---

# 🧪 Running Tests

Standard tests:

```bash
forge test
```

With logs:

```bash
forge test -vvvv
```

Gas report:

```bash
forge test --gas-report
```

---

# 📤 Deploying the Contract

### Local Deployment

```bash
make deploy
```

### Sepolia Deployment

```bash
make deploy-sepolia
```

---

# 🔗 VRF & Automation Setup

When deployed to testnet, run:

```bash
make setup-sepolia
```

This handles:

✔ Create VRF subscription
✔ Fund subscription
✔ Add consumer
✔ Register automation upkeep

All automated via scripts.

---

# 🔍 Understanding the Code

This section explains the contract line-by-line (but simplified).

---

## 📌 State Variables

```solidity
uint256 private immutable i_entranceFee;
uint256 private immutable i_interval;
address payable[] private s_players;
enum RaffleState { OPEN, CALCULATING }
```

* `i_entranceFee`: minimum ETH to enter
* `i_interval`: time between draws
* `s_players`: list of players
* `RaffleState`: OPEN or CALCULATING

---

## 📌 Entering the Lottery

```solidity
function enterRaffle() external payable {
    if (msg.value < i_entranceFee) revert Raffle__NotEnoughEthSent();
    s_players.push(payable(msg.sender));
}
```

---

## 📌 Automation Check

```solidity
function checkUpkeep() 
```

Conditions checked:

```solidity
(bool upkeepNeeded,) = (isOpen && timePassed && hasPlayers && hasBalance);
```

---

## 📌 Requesting Randomness

```solidity
function performUpkeep(...) {
    s_raffleState = RaffleState.CALCULATING;
    uint256 requestId = i_vrfCoordinator.requestRandomWords(...);
}
```

---

## 📌 Selecting Winner

```solidity
fulfillRandomWords(uint256 random) {
    uint256 winnerIndex = random % players.length;
    address payable winner = players[winnerIndex];
    winner.transfer(address(this).balance);
}
```

Lottery resets afterward.

---

# 🧯 Common Issues & Fixes

### ⚠️ **Issue: “upkeepNeeded = false” on Sepolia**

Make sure:

* You have at least 1 player
* Enough time has passed
* Lottery is OPEN
* Contract has ETH

---

### ⚠️ “Missing VRF subscription” error

Run:

```bash
make setup-sepolia
```

---

### ⚠️ "InvalidConsumer()" error

Your contract wasn't added to VRF subscription.
The scripts fix this automatically.

---

# 🔮 Future Enhancements

* 🎟 NFT-based lottery tickets
* 🏦 Treasury + protocol fee
* 🔐 Admin dashboard
* 🔄 Multiple rounds running in parallel
* 📱 Frontend with Next.js + Wagmi + RainbowKit
* 🪂 Airdrop incentives

---

# 👨‍💻 Author

**Sivaji — Smart Contract Engineer**
🔗 LinkedIn: [https://www.linkedin.com/in/sivajialla/](https://www.linkedin.com/in/sivajialla/)
🐦 X Profile: [https://x.com/_sivaji__](https://x.com/_sivaji__)
💻 GitHub: [https://github.com/DecentralizedGlasses/Thanks-Giving-2025](https://github.com/DecentralizedGlasses/Thanks-Giving-2025)

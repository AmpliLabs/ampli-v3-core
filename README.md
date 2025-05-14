# Ampli

**Permissionless system for on-demand leverage**  
_Ampli is the most expressive, composable, and frictionless margin platform. Built on Uniswap v4 for DeFi power users._

---

## 🧩 What is Ampli?

Ampli is a modular, permissionless protocol for margin trading, staking, and DeFi composability without relying on traditional lending pools. Instead of matching lenders with borrowers, Ampli securitizes debt into interest-bearing tokens that can be freely traded via Uniswap v4.

Each Ampli market is defined by a base token (e.g., ETH, USDC) and a set of customizable risk configurations. Users open self-custodial margin positions and interact with DeFi protocols while maintaining leveraged holdings.

---

## 🔁 Protocol Evolution

### v1 – Standalone Margin Protocol

- Independent contract with its own ERC20 debt token (PED)
- Margin positions track deposited assets and borrowed PED
- Interest rate derived from peg deviation in a Uniswap v2 pool

### v2 – Hook-Powered Integration

- Migrated to a Uniswap v4 hook model
- Real-time interest updates and LP rewards via hooks
- ETH used directly instead of WETH

### v3 – System for Margin Markets

- Anyone can launch a custom margin market with specified base token
- New debt token + Uniswap v4 pool deployed per market
- Customizable interest rate functions, price oracles, and risk parameters tailored for users of every risk profile

---

## 🏗️ Key Features

Ampli is implemented as a singleton contract that contains all margin markets and position, and with the following key features.

| Component            | Description                                                                                             |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| `Singleton Design`   | Initialize new margin markets with user-defined parameters, and track margin positions in each market   |
| `Uniswap v4 Hooks`   | Real-time interest rate update, proactively and continuously reward active LPs                          |
| `Debt Token`         | Endogenous ERC20 token per market served as on-demand leverage and unit of accounting; interest-bearing |
| `Price Oracles`      | Quote the value of other tokens in debt token                                                           |
| `Liquidation Engine` | Allows anyone to liquidate unhealthy positions                                                          |
| `Bad Debt Reserve`   | Collected from interests to counter bad debt, if any                                                    |

---

## ⚙️ How It Works

1. **Create Market** – Deploy a new margin market by specifying base token, oracle, and risk parameters.
2. **Open Position** – Deposit collateral (ERC20/ERC721) and mint debt tokens.
3. **Use Leverage** – Trade, LP, or stake assets via integrations or callbacks.
4. **Earn Yield** – Liquidity providers earn interest from peg deviation.
5. **Get Liquidated** – If margin falls below threshold, anyone can liquidate.

---

## 📈 Interest Rate Model

Ampli supports configurable interest rate curves:

- Static or dynamic
- Fixed or DAO-governed

Interests are paid proactively and continuously to active LPs in the Uniswap v4 pool.

---

## 💥 Liquidation Mechanism

- Open liquidation: anyone can liquidate unhealthy positions
- Liquidator repays debt to claim ownership of position
- If position is underwater, Ampli taps into reserve or borrow debt tokens (from future reserve collection) to ensure minimum incentive

---

## 🔐 Self-Custody Model

User assets are held by the protocol but tracked per position. Users retain full control and utility over assets within a position (e.g., LP tokens, staked assets). NFT wrappers are available peripherally, but not required.

---

## 🔧 Developer Setup

```bash
forge install ampliprotocol/ampli
forge build
forge test
```

# Decentralized Bond Marketplace MVP

This repository contains an end-to-end MVP DApp for a decentralized bond marketplace using:

- Solidity smart contract (`contracts/BondMarketplace.sol`)
- Remix IDE (compile/deploy)
- Ganache (local blockchain)
- MetaMask (wallet + transaction signing)
- Frontend with HTML/CSS/JavaScript + Ethers.js (`frontend/`)

---

## 1) Smart Contract (Solidity)

Contract: `contracts/BondMarketplace.sol`

### Key data models
- `Bond` struct
  - id
  - organization address
  - name
  - interestRate (%)
  - durationDays
  - totalFundingRequired
  - amountRaised
  - fundUsageLogs (`string[]`)
  - trustScore (`uint256`)
- `Investor` struct
  - investorAddress
  - investments mapping (`bondId => amount`)
  - investedBondIds array (used for readable portfolio retrieval)

### Core functions
- Organization actions
  - `createBond(...)`
  - `updateFundUsage(bondId, description)`
  - `updateTrustScore(bondId)`
- Investor actions
  - `investInBond(bondId)` payable
  - `getInvestorPortfolio(address)`
- Public view functions
  - `getAllBonds()`
  - `getBondDetails(bondId)`
  - `getTrustScore(bondId)`

### Constraints implemented
- Only bond creator can call `updateFundUsage`.
- Investment cannot exceed required amount.
- Validation with `require(...)` in critical paths.

### Events
- `BondCreated`
- `Invested`
- `FundUsageUpdated`
- `TrustScoreUpdated`

### Trust score formula (MVP)
`updateTrustScore` applies a simple transparency/activity score:
- Base: `min(50, fundUsageLogsCount * 10)`
- Early transparency bonus: `+10` if first update happens within 7 days of creation
- Funding progress bonus: `+2` for each 10% funded, capped at `+20`
- Hard cap at `100`

---

## 2) Deploy with Remix + Ganache

### A. Start Ganache
1. Open Ganache.
2. Start a local chain (typically `HTTP://127.0.0.1:7545`, chain ID often `1337`).
3. Keep one account private key ready for MetaMask import.

### B. Compile in Remix
1. Open [https://remix.ethereum.org](https://remix.ethereum.org).
2. Create file `BondMarketplace.sol` and paste content from `contracts/BondMarketplace.sol`.
3. Go to **Solidity Compiler**.
4. Set compiler version to `0.8.20` (or compatible `0.8.x`).
5. Click **Compile BondMarketplace.sol**.

### C. Deploy in Remix
1. Go to **Deploy & Run Transactions**.
2. Environment options:
   - Option 1 (easiest for this MVP): **Injected Provider - MetaMask**.
   - Option 2: **Web3 Provider** and enter Ganache RPC URL.
3. Select contract `BondMarketplace`.
4. Click **Deploy** and confirm transaction in MetaMask.
5. Copy deployed contract address.

---

## 3) MetaMask + Ganache setup (step-by-step)

1. Open MetaMask.
2. Add a custom network:
   - Network Name: `Ganache Local`
   - RPC URL: `http://127.0.0.1:7545`
   - Chain ID: `1337` (or what Ganache shows)
   - Currency Symbol: `ETH`
3. Import Ganache account:
   - In Ganache, copy one account private key.
   - In MetaMask: **Import Account** → paste private key.
4. Verify account has test ETH from Ganache.
5. Ensure MetaMask is connected to `Ganache Local` network before using Remix/frontend.

---

## 4) Frontend code

Files:
- `frontend/index.html`
- `frontend/style.css`
- `frontend/app.js`

### IMPORTANT configuration
In `frontend/app.js`, set:

```js
const CONTRACT_ADDRESS = "PASTE_DEPLOYED_CONTRACT_ADDRESS_HERE";
```

Replace it with the address copied after deployment in Remix.

---

## 5) Run DApp locally

### Option A: quick static server (recommended)
From repository root:

```bash
python3 -m http.server 8080
```

Then open:
- `http://127.0.0.1:8080/frontend/`

### Option B: open HTML directly
You can open `frontend/index.html` directly in browser, but wallet interactions are more reliable through an HTTP server.

### Runtime checklist
- Ganache running
- MetaMask on Ganache network
- Contract deployed
- `CONTRACT_ADDRESS` updated in `app.js`
- Browser uses account with Ganache ETH

---

## 6) Example test flow (end-to-end)

1. **Connect Wallet** in frontend.
2. **Create bond** in Organization Panel:
   - Name: `SolarBond-A`
   - Interest: `8`
   - Duration: `180`
   - Total Funding: `10` ETH
3. Click **Refresh Bonds** and verify the bond appears.
4. Click **Invest** on the bond and enter `1` ETH.
5. Verify:
   - raised amount updates (`1 / 10 ETH`)
   - trust score may update due to funding progress
6. In Organization Panel, add usage update:
   - Bond ID: `0`
   - Description: `Allocated first tranche to equipment purchase`
7. Refresh bonds and verify usage log appears and trust score increases.
8. Click **Load My Portfolio** to verify investor holdings.
9. Use **Bond Details** section for full per-bond view.

---
let provider;
let signer;
let contract;
let currentAccount;

// Replace with deployed contract address from Remix.
const CONTRACT_ADDRESS = "0x2491da1D9146A3FB9c3270d20Bf153a292c100E2";

// ABI copied from the BondMarketplace contract interface.
const CONTRACT_ABI = [
  "function createBond(string name,uint256 interestRate,uint256 durationDays,uint256 totalFundingRequired)",
  "function updateFundUsage(uint256 bondId,string description)",
  "function updateTrustScore(uint256 bondId) returns (uint256)",
  "function investInBond(uint256 bondId) payable",
  "function getAllBonds() view returns (uint256[] ids,address[] organizations,string[] names,uint256[] interestRates,uint256[] durations,uint256[] totals,uint256[] raised,uint256[] trustScores)",
  "function getBondDetails(uint256 bondId) view returns (uint256 id,address organization,string name,uint256 interestRate,uint256 durationDays,uint256 totalFundingRequired,uint256 amountRaised,uint256 trustScore,string[] fundUsageLogs)",
  "function getTrustScore(uint256 bondId) view returns (uint256)",
  "function getInvestorPortfolio(address investorAddress) view returns (uint256[] investedIds,uint256[] investedAmounts)",
  "event BondCreated(uint256 indexed bondId,address indexed organization,string name,uint256 interestRate,uint256 durationDays,uint256 totalFundingRequired)",
  "event Invested(uint256 indexed bondId,address indexed investor,uint256 amount,uint256 newAmountRaised)",
  "event FundUsageUpdated(uint256 indexed bondId,address indexed organization,string description,uint256 logCount)",
  "event TrustScoreUpdated(uint256 indexed bondId,uint256 newTrustScore)"
];

const walletStatus = document.getElementById("walletStatus");
const bondsContainer = document.getElementById("bondsContainer");
const portfolioList = document.getElementById("portfolioList");
const bondDetailsOutput = document.getElementById("bondDetailsOutput");

async function connectWallet() {
  if (!window.ethereum) {
    alert("MetaMask is not installed.");
    return;
  }

  provider = new ethers.providers.Web3Provider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  signer = provider.getSigner();
  currentAccount = await signer.getAddress();

  if (CONTRACT_ADDRESS.includes("PASTE_DEPLOYED")) {
    alert("Please set CONTRACT_ADDRESS in app.js first.");
    return;
  }

  contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
  walletStatus.textContent = `Wallet: ${currentAccount}`;

  await loadAllBonds();
}

async function createBond(event) {
  event.preventDefault();
  try {
    const name = document.getElementById("bondName").value;
    const interestRate = document.getElementById("interestRate").value;
    const durationDays = document.getElementById("durationDays").value;
    const totalFundingEth = document.getElementById("totalFundingEth").value;

    const totalFundingWei = ethers.utils.parseEther(totalFundingEth);
    const tx = await contract.createBond(name, interestRate, durationDays, totalFundingWei);
    await tx.wait();

    alert("Bond created successfully.");
    event.target.reset();
    await loadAllBonds();
  } catch (error) {
    console.error(error);
    alert(error?.data?.message || error.message);
  }
}

async function updateFundUsage(event) {
  event.preventDefault();
  try {
    const bondId = document.getElementById("usageBondId").value;
    const description = document.getElementById("usageDescription").value;

    const tx = await contract.updateFundUsage(bondId, description);
    await tx.wait();

    alert("Fund usage updated.");
    event.target.reset();
    await loadAllBonds();
  } catch (error) {
    console.error(error);
    alert(error?.data?.message || error.message);
  }
}

async function investInBond(bondId) {
  try {
    const ethAmount = prompt("Enter ETH amount to invest:");
    if (!ethAmount) return;

    const tx = await contract.investInBond(bondId, {
      value: ethers.utils.parseEther(ethAmount)
    });
    await tx.wait();

    alert("Investment successful.");
    await loadAllBonds();
    await loadPortfolio();
  } catch (error) {
    console.error(error);
    alert(error?.data?.message || error.message);
  }
}

async function loadAllBonds() {
  if (!contract) return;

  const [ids, organizations, names, interestRates, durations, totals, raised, trustScores] = await contract.getAllBonds();
  bondsContainer.innerHTML = "";

  if (ids.length === 0) {
    bondsContainer.innerHTML = "<p>No bonds listed yet.</p>";
    return;
  }

  for (let i = 0; i < ids.length; i++) {
    const id = ids[i].toString();
    const fundUsage = await contract.getBondDetails(id);

    const div = document.createElement("div");
    div.className = "bond-card";

    div.innerHTML = `
      <h4>#${id} - ${names[i]}</h4>
      <p><strong>Organization:</strong> ${organizations[i]}</p>
      <p><strong>Interest:</strong> ${interestRates[i].toString()}%</p>
      <p><strong>Duration:</strong> ${durations[i].toString()} days</p>
      <p><strong>Raised:</strong> ${ethers.utils.formatEther(raised[i])} / ${ethers.utils.formatEther(totals[i])} ETH</p>
      <p><strong>Trust Score:</strong> ${trustScores[i].toString()}</p>
      <strong>Fund Usage Logs:</strong>
      <ul>${fundUsage.fundUsageLogs.map((log) => `<li>${log}</li>`).join("") || "<li>No updates yet.</li>"}</ul>
      <button data-bond-id="${id}">Invest</button>
    `;

    div.querySelector("button").addEventListener("click", () => investInBond(id));
    bondsContainer.appendChild(div);
  }
}

async function loadPortfolio() {
  if (!contract || !currentAccount) return;

  const [bondIds, amounts] = await contract.getInvestorPortfolio(currentAccount);
  portfolioList.innerHTML = "";

  if (bondIds.length === 0) {
    portfolioList.innerHTML = "<li>No investments yet.</li>";
    return;
  }

  for (let i = 0; i < bondIds.length; i++) {
    const li = document.createElement("li");
    li.textContent = `Bond #${bondIds[i].toString()} : ${ethers.utils.formatEther(amounts[i])} ETH`;
    portfolioList.appendChild(li);
  }
}

async function getBondDetails(event) {
  event.preventDefault();
  try {
    const bondId = document.getElementById("detailsBondId").value;
    const d = await contract.getBondDetails(bondId);

    bondDetailsOutput.textContent = JSON.stringify(
      {
        id: d.id.toString(),
        organization: d.organization,
        name: d.name,
        interestRate: d.interestRate.toString(),
        durationDays: d.durationDays.toString(),
        totalFundingRequiredEth: ethers.utils.formatEther(d.totalFundingRequired),
        amountRaisedEth: ethers.utils.formatEther(d.amountRaised),
        trustScore: d.trustScore.toString(),
        fundUsageLogs: d.fundUsageLogs
      },
      null,
      2
    );
  } catch (error) {
    console.error(error);
    alert(error?.data?.message || error.message);
  }
}

document.getElementById("connectWalletBtn").addEventListener("click", connectWallet);
document.getElementById("createBondForm").addEventListener("submit", createBond);
document.getElementById("fundUsageForm").addEventListener("submit", updateFundUsage);
document.getElementById("refreshBondsBtn").addEventListener("click", loadAllBonds);
document.getElementById("loadPortfolioBtn").addEventListener("click", loadPortfolio);
document.getElementById("bondDetailsForm").addEventListener("submit", getBondDetails);
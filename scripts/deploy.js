import hre from "hardhat";

async function main() {

    

    const accounts = await hre.ethers.provider.listAccounts();
    accounts.pop()

    const [deployer] = await hre.ethers.getSigners(); //get the account to deploy the contract

    console.log("Deploying contracts with the account:", deployer.address); 
    
    // We get the token contract to deploy
    const ZZKT = await hre.ethers.getContractFactory("ZZKT");
    const zzkt = await ZZKT.deploy(10 ** 6);

    await zzkt.deployed();

    console.log("ZZKT deployed to:", zzkt.address);

    if(hre.network.name !== "hardhat") {

        await hre.run("verify:verify", {
            contract: "contracts/Token.sol:ZZKT",
            address: zzkt.address,
            constructorArguments: [10 ** 6],
        });

    }

  // We get the multisigwallet contract to deploy
  const MultiSigWallet = await hre.ethers.getContractFactory("MultiSigWallet");
  const multiSigWallet = await MultiSigWallet.deploy(
    zzkt.address, accounts, 3,
 );

  await multiSigWallet.deployed();

  console.log("MultiSigWallet deployed to:", multiSigWallet.address);

    if(hre.network.name !== "hardhat") {

        await hre.run("verify:verify", {
            contract: "contracts/MultiSigWallet.sol:MultiSigWallet",
            address: multiSigWallet.address,
            constructorArguments: [
                zzkt.address, accounts, 3,
            ],
        });

    }

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); // Calling the function to deploy the contract 

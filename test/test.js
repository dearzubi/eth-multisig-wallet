import chai from 'chai';
import { expect } from "chai";
import hre from "hardhat";

let zzkt;
let multisig;
let minConfirmations = 3;
let admin;
let signer1;
let signer2;
let signer3;
let user;

describe("ZZKT Token", function () {

  it("Token deployment is success", async function () {

    const ZZKT = await ethers.getContractFactory("ZZKT");
    zzkt = await ZZKT.deploy(10 ** 6);
    await zzkt.deployed();

    expect(await zzkt.name()).to.equal("ZZKT");
    expect(await zzkt.symbol()).to.equal("ZZKT");
    expect(await zzkt.decimals()).to.equal(18);
  });
  

});

describe("MultiSigWallet", function () {

  before(async function() {
      
    admin = (await hre.ethers.getSigners()).at(0);
    signer1 = (await hre.ethers.getSigners()).at(1);
    signer2 = (await hre.ethers.getSigners()).at(2);
    signer3 = (await hre.ethers.getSigners()).at(3);
    user = (await hre.ethers.getSigners()).at(-1);

  });

  it("MultiSigWallet deployment is success", async function () {

      const signers = await hre.ethers.provider.listAccounts();
      signers.pop()

      const tokenAddress = zzkt.address;

      const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
      multisig = await MultiSigWallet.deploy(tokenAddress, signers, minConfirmations);
      await multisig.deployed();

      const tx = await zzkt.connect(admin).transfer(multisig.address, hre.ethers.utils.parseUnits("1000000", 18));
      await tx.wait();

      expect(await multisig.minConfirmationsToExecTx()).to.equal(minConfirmations);
      expect((await zzkt.balanceOf(multisig.address)).toString()).to.equal(hre.ethers.utils.parseUnits("1000000", 18).toString());

  });


  it("A Tx must require min confirmations to be executed", async function () {  

    expect((await multisig.getTransactionCount()).toString()).to.equal("0");

    let tx = await multisig.connect(admin).submitTransaction(user.address, hre.ethers.utils.parseUnits("2000", 18));
    await tx.wait();

    expect(hre.ethers.utils.formatUnits((await zzkt.balanceOf(user.address)).toString(), 18)).to.equal("0.0");

    expect((await multisig.getTransactionCount()).toString()).to.equal("1");

    tx = await multisig.connect(signer1).confirmTransaction(0);
    await tx.wait();

    tx = await multisig.connect(signer2).confirmTransaction(0);
    await tx.wait();

    tx = await multisig.connect(signer3).confirmTransaction(0);
    await tx.wait();

    tx = await multisig.connect(admin).executeTransaction(0);
    await tx.wait();

    expect((await multisig.getTransaction(0)).numConfirmations.toString()).to.equal(minConfirmations.toString());
    expect(hre.ethers.utils.formatUnits((await zzkt.balanceOf(user.address)).toString(), 18)).to.equal("2000.0");

  });
});
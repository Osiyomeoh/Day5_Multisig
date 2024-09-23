import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("Multisig", function () {
  // We define a fixture to reuse the same setup in every test.
  async function deployMultisigFixture() {
    const [owner, otherAccount, thirdAccount] = await hre.ethers.getSigners();
    const quorum = 2;
    const owners = [owner.address, otherAccount.address, thirdAccount.address];

    const Multisig = await hre.ethers.getContractFactory("Multisig");
    const multisig = await Multisig.deploy(quorum, owners);

    return { multisig, quorum, owners, owner, otherAccount, thirdAccount };
  }

  describe("Deployment", function () {
    it("Should set the right quorum", async function () {
      const { multisig, quorum } = await loadFixture(deployMultisigFixture);

      expect(await multisig.quorum()).to.equal(quorum);
    });

    it("Should set the right owners", async function () {
      const { multisig, owners } = await loadFixture(deployMultisigFixture);

      for (let i = 0; i < owners.length; i++) {
        expect(await multisig.owners(i)).to.equal(owners[i]);
        expect(await multisig.isOwner(owners[i])).to.be.true;
      }
    });
  });

  describe("Transactions", function () {
    it("Should create a transaction", async function () {
      const { multisig, owner, otherAccount } = await loadFixture(deployMultisigFixture);
      const value = hre.ethers.parseEther("1");
      const data = "0x";

      await expect(multisig.createTransaction(otherAccount.address, value, data))
        .to.emit(multisig, "TransactionCreated")
        .withArgs(1, owner.address, otherAccount.address, value, data);

      const transaction = await multisig.transactions(1);
      expect(transaction.to).to.equal(otherAccount.address);
      expect(transaction.value).to.equal(value);
      expect(transaction.data).to.equal(data);
      expect(transaction.executed).to.be.false;
      expect(transaction.confirmationCount).to.equal(0);
    });

    it("Should confirm a transaction", async function () {
      const { multisig, owner, otherAccount } = await loadFixture(deployMultisigFixture);
      await multisig.createTransaction(otherAccount.address, 0, "0x");

      await expect(multisig.confirmTransaction(1))
        .to.emit(multisig, "TransactionConfirmed")
        .withArgs(1, owner.address);

      const transaction = await multisig.transactions(1);
      expect(transaction.confirmationCount).to.equal(1);
    });

    it("Should execute a transaction when quorum is reached", async function () {
      const { multisig, owner, otherAccount, thirdAccount } = await loadFixture(deployMultisigFixture);
      const value = hre.ethers.parseEther("1");
      await multisig.addFunds({ value });

      await multisig.createTransaction(thirdAccount.address, value, "0x");
      await multisig.confirmTransaction(1);
      await multisig.connect(otherAccount).confirmTransaction(1);

      await expect(multisig.executeTransaction(1))
        .to.emit(multisig, "TransactionExecuted")
        .withArgs(1);

      const transaction = await multisig.transactions(1);
      expect(transaction.executed).to.be.true;
      expect(await hre.ethers.provider.getBalance(thirdAccount.address)).to.equal(hre.ethers.parseEther("10001"));
    });
  });


});

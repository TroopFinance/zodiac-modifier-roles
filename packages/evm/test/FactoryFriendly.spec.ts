import assert from "assert";
import { AddressOne } from "@gnosis.pm/safe-contracts";
import { expect } from "chai";
import { AbiCoder, defaultAbiCoder } from "ethers/lib/utils";

import hre, { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const FirstAddress = "0x0000000000000000000000000000000000000001";
const saltNonce = "0xfa";

describe("Module works with factory", () => {
  const paramsTypes = ["address", "address", "address"];

  async function setup() {
    const Factory = await hre.ethers.getContractFactory("ModuleProxyFactory");
    const factory = await Factory.deploy();
    const Packer = await hre.ethers.getContractFactory("Packer");
    const packer = await Packer.deploy();

    const Integrity = await hre.ethers.getContractFactory("Integrity");
    const integrity = await Integrity.deploy();

    const Module = await hre.ethers.getContractFactory("RolesHarness", {
      libraries: {
        Integrity: integrity.address,
        Packer: packer.address,
      },
    });
    const masterCopy = await Module.deploy(FirstAddress);

    return { factory, masterCopy, Modifier: Module };
  }

  it("should throw because master copy is already initialized", async () => {
    const { masterCopy } = await loadFixture(setup);
    const encodedParams = new AbiCoder().encode(paramsTypes, [
      AddressOne,
      AddressOne,
      AddressOne,
    ]);

    await expect(masterCopy.setUp(encodedParams)).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
  });

  it("should deploy new roles module proxy", async () => {
    const { factory, masterCopy, Modifier } = await loadFixture(setup);
    const [avatar] = await ethers.getSigners();

    const initializer = await masterCopy.populateTransaction.setUp(
      defaultAbiCoder.encode(["address"], [avatar.address])
    );
    const receipt = await (
      await factory.deployModule(
        masterCopy.address,
        initializer.data as string,
        saltNonce
      )
    ).wait();

    assert(receipt.events);

    // retrieve new address from event
    const result = receipt.events.find(
      (evt) => evt.event === "ModuleProxyCreation"
    );
    assert(result);
    assert(result.args);

    const [newProxyAddress] = result.args;

    const proxy = Modifier.attach(newProxyAddress);
    // const newProxy = await hre.ethers.getContractAt("Roles", newProxyAddress);
    expect(await proxy.getAvatar()).to.be.eq(avatar.address);
  });
});

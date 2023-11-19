/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Proxy call example", function () {
  const adminAddress = 0xF60A99830eE5b15Eac36242823F4a37814CE98e1;
  let swap;
  let proxy;
    
  it("should deploy", async function () {
    console.log('adminAddress: ', adminAddress);

    const SwapViaPool = await ethers.getContractFactory("TestingToken");
    swap = await SwapViaPool.deploy(1000000000000000000000000);
    await swap.deployed();
    
    console.log("SwapViaPool deployed to:", swap.address);

    const SwapProxy = await ethers.getContractFactory("TestingTokenProxy");
    proxy = await SwapProxy.deploy(
        swap.address, 
        adminAddress, 
        []
    );
    await proxy.deployed();

    console.log("SwapProxy deployed to:", proxy.address);
  });

  it("should call", async function () {
    console.log('version: ', await proxy.version());
  });
});

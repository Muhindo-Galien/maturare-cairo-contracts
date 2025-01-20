import { Account, CallData, Contract, RpcProvider, stark } from "starknet";
import { getCompiledCode } from "./utils";

import fs from "fs";
import dotenv from "dotenv";

dotenv.config({ path: __dirname + "/../.env" });

const provider = new RpcProvider({
  nodeUrl: process.env.RPC_ENDPOINT,
});

// initialize existing predeployed account 0
console.log("ACCOUNT_ADDRESS=", process.env.DEPLOYER_ADDRESS);
console.log("ACCOUNT_PRIVATE_KEY=", process.env.DEPLOYER_PRIVATE_KEY);
const privateKey0 = process.env.DEPLOYER_PRIVATE_KEY ?? "";
const accountAddress0: string = process.env.DEPLOYER_ADDRESS ?? "";
const owner = new Account(provider, accountAddress0, privateKey0);
console.log("Account connected.\n");

async function upgrade() {
  const new_class_hash = process.env.TRY_CLASS_HASH as string;
  const contract_address = process.env.TRY_ADDRESS as string;

  // Declare & deploy contract
  let sierraCode, casmCode;

  try {
    ({ sierraCode, casmCode } = await getCompiledCode("velix_vault_try_v0"));
  } catch (error: any) {
    console.log("Failed to read contract files");
    process.exit(1);
  }

  const contract = new Contract(sierraCode.abi, contract_address, owner);
  let result = await contract.upgrade(new_class_hash);
  console.log("✅ contract upgraded approved, amount:", new_class_hash);
  console.log(result, result);
}

async function main() {
  await upgrade();
}

main();

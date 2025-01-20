import { Account, CallData, Contract, RpcProvider, stark } from "starknet";
import * as dotenv from "dotenv";
import fs from "fs";
import path from "path";
import { getCompiledCode } from "./utils";
dotenv.config({ path: __dirname + "/../.env" });

async function main() {
  const provider = new RpcProvider({
    nodeUrl: process.env.RPC_ENDPOINT,
  });

  // initialize existing predeployed account 0
  console.log("ACCOUNT_ADDRESS=", process.env.DEPLOYER_ADDRESS);
  console.log("ACCOUNT_PRIVATE_KEY=", process.env.DEPLOYER_PRIVATE_KEY);
  const privateKey0 = process.env.DEPLOYER_PRIVATE_KEY ?? "";
  const accountAddress0: string = process.env.DEPLOYER_ADDRESS ?? "";
  const account0 = new Account(provider, accountAddress0, privateKey0);
  console.log("Account connected.\n");

  let name = "V1_mature_vault";
  // Define the path to the .env file
  const envFilePath = path.resolve(__dirname, "../.env");

  // Declare & deploy contract
  let sierraCode, casmCode;

  try {
    ({ sierraCode, casmCode } = await getCompiledCode(
      "mature_vault_mature_vault"
    ));
  } catch (error: any) {
    console.log("Failed to read contract files");
    process.exit(1);
  }

  // const declareResponse = await account0.declare({
  //   contract: sierraCode,
  //   casm: casmCode,
  // });

  // console.log("Contract classHash: ", declareResponse.class_hash);

  // fs.appendFileSync(
  //   envFilePath,
  //   `\n${name.toUpperCase()}_CLASS_HASH=${declareResponse.class_hash}`
  // );

  // =============================================================================
  // Deployment
  const myCallData = new CallData(sierraCode.abi);
  const constructor = myCallData.compile("constructor", {
    pool: "0x57a269ab16098757d40e80b687696b8844c0355cdaca6501e98a2e19f9bacb6",
    asset: "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    owner: "0x05f967120b6c540e586596399816a939c040cade393a1626d4aaf32dcd42959d",
    vault_withdrawal_manager:
      "0x5d02d93e3193cd4358ab0a2bf37ceb627c3f54c525d6ce21e128f90797acbe7",
  });

  const { transaction_hash, contract_address } = await account0.deploy({
    classHash: process.env.V1_MATURE_VAULT_CLASS_HASH as string,
    constructorCalldata: constructor,
    salt: stark.randomAddress(),
  });

  const contractAddress: any = contract_address[0];
  await provider.waitForTransaction(transaction_hash);

  // Connect the new contract instance :
  const vault_manager_contract = new Contract(sierraCode.abi, contractAddress, provider);

  console.log(`✅ Contract has been connected at: ${vault_manager_contract.address}`);

  fs.appendFileSync(
    envFilePath,
    `\n${name.toUpperCase()}_ADDRESS=${contractAddress}`
  );
  // return vault_manager_contract;
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

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

  let name = "ma_strk_token";

  // Define the path to the .env file
  const envFilePath = path.resolve(__dirname, "../.env");

  // Declare & deploy contract
  let sierraCode, casmCode;

  try {
    ({ sierraCode, casmCode } = await getCompiledCode("mature_vault_Token"));
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
    owner: "0x05f967120b6c540e586596399816a939c040cade393a1626d4aaf32dcd42959d",
    mature_vault:
      "0x382fa3be556536f6bd62ef4d9b7d5a123ee2b4908114ccb0e03754ba028f28",
    name: "maSTRK",
    symbol: "maSTRK",
    decimals: 18,
  });

  const { transaction_hash, contract_address } = await account0.deploy({
    classHash: process.env.MA_STRK_TOKEN_CLASS_HASH as string,
    constructorCalldata: constructor,
    salt: stark.randomAddress(),
  });

  const contractAddress: any = contract_address[0];
  await provider.waitForTransaction(transaction_hash);

  // Connect the new contract instance :
  const try_contract = new Contract(sierraCode.abi, contractAddress, provider);

  console.log(`✅ Contract has been connected at: ${try_contract.address}`);

  fs.appendFileSync(
    envFilePath,
    `\n${name.toUpperCase()}_ADDRESS=${contractAddress}`
  );
  // return try_contract;
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

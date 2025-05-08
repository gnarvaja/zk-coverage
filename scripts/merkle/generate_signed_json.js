import * as fs from "fs";
import { ethers } from "ethers";
import { LeanIMT } from "@zk-kit/lean-imt";
import { poseidon2 } from "poseidon-lite";

function floatToWad(lossProb) {
  return BigInt(Math.round(lossProb * 10000)) * BigInt(10n ** 14n);
}

function makePriceListMessage({ merkleRoot, validFrom, validTo }) {
  return ethers.solidityPacked(
    ["uint256", "uint40", "uint40"],
    [merkleRoot, validFrom, validTo],
  );
}

if (!process.env.SIGNER_PK) throw new Error("$SIGNER_PK not defined");

const signer = new ethers.Wallet(process.env.SIGNER_PK);
const priceList = JSON.parse(fs.readFileSync(process.argv[2]));
const validFrom = parseInt(process.argv[3]);
const validTo = parseInt(process.argv[4]);
const outputFile = process.argv[5];

const leafs = priceList.areas.map((areaLossProb) =>
  poseidon2(["0x" + areaLossProb[0], floatToWad(areaLossProb[1])]),
);

const hash = (a, b) => poseidon2([a, b]);
const tree = new LeanIMT(hash);

tree.insertMany(leafs);
const proof = tree.generateProof(0);

console.log("Signer Address:", signer.address);
console.log("Merkle Root:", proof);
const message = makePriceListMessage({
  merkleRoot: proof.root,
  validFrom,
  validTo,
});
console.log("Message:", message);
const signature = ethers.Signature.from(
  await signer.signMessage(ethers.getBytes(message)),
);
console.log("Signature:", signature);

const output = {
  signature,
  merkleRoot: proof.root.toString(),
  validFrom,
  validTo,
  signer: signer.address,
};

fs.writeFileSync(outputFile, JSON.stringify(output, null, 2), "utf8");
console.log(`Price list signature succesfully generated: ${outputFile}`);

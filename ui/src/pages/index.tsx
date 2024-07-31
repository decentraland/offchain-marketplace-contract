import { useMemo, useState } from "react";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { useWeb3ModalProvider } from "@web3modal/ethers/react";
import { ethers, AbiCoder } from "ethers";

export default function Home() {
  return (
    <main>
      <Signature />
      <br />
      <MerkleTree />
    </main>
  );
}

const Signature = () => {
  const { walletProvider } = useWeb3ModalProvider();
  const [signature, setSignature] = useState("");

  const onSign = async () => {
    if (!walletProvider) {
      throw new Error("Wallet provider is not available");
    }

    const browserProvider = new ethers.BrowserProvider(walletProvider);

    const signer = await browserProvider.getSigner();

    const signature = await signer.signTypedData(
      {
        name: "DecentralandMarketplaceEthereum",
        version: "1.0.0",
        verifyingContract: "0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f",
        salt: "0x0000000000000000000000000000000000000000000000000000000000007a69",
      },
      {
        Trade: [
          { name: "checks", type: "Checks" },
          { name: "sent", type: "AssetWithoutBeneficiary[]" },
          { name: "received", type: "Asset[]" },
        ],
        Asset: [
          { name: "assetType", type: "uint256" },
          { name: "contractAddress", type: "address" },
          { name: "value", type: "uint256" },
          { name: "extra", type: "bytes" },
          { name: "beneficiary", type: "address" },
        ],
        AssetWithoutBeneficiary: [
          { name: "assetType", type: "uint256" },
          { name: "contractAddress", type: "address" },
          { name: "value", type: "uint256" },
          { name: "extra", type: "bytes" },
        ],
        Checks: [
          { name: "uses", type: "uint256" },
          { name: "expiration", type: "uint256" },
          { name: "effective", type: "uint256" },
          { name: "salt", type: "bytes32" },
          { name: "contractSignatureIndex", type: "uint256" },
          { name: "signerSignatureIndex", type: "uint256" },
          { name: "allowedRoot", type: "bytes32" },
          { name: "externalChecks", type: "ExternalCheck[]" },
        ],
        ExternalCheck: [
          { name: "contractAddress", type: "address" },
          { name: "selector", type: "bytes4" },
          { name: "value", type: "bytes" },
          { name: "required", type: "bool" },
        ],
      },
      {
        checks: {
          uses: "0",
          expiration: "4878105366",
          effective: "0",
          salt: "0x0000000000000000000000000000000000000000000000000000000000000000",
          contractSignatureIndex: "0",
          signerSignatureIndex: "0",
          allowedRoot: "0x0000000000000000000000000000000000000000000000000000000000000000",
          externalChecks: [
            {
              contractAddress: "0xF87E31492Faf9A91B02Ee0dEAAd50d51d56D5d4d",
              selector: "0x6352211e",
              value: AbiCoder.defaultAbiCoder().encode(["uint256"], ["42535295865117307932921825928971026431990"]),
              required: true,
            }
          ],
        },
        sent: [
          {
            assetType: "3",
            contractAddress: "0x959e104E1a4dB6317fA58F8295F586e1A978c297",
            value: "1",
            extra: AbiCoder.defaultAbiCoder().encode(["bytes32"], ["0x6d8995334f806f5cc44610d81b29bd7fe1c50d6a80b0b65080cc8c48cb82d8c9"]),
          },
        ],
        received: [
          {
            assetType: "3",
            contractAddress: "0xF87E31492Faf9A91B02Ee0dEAAd50d51d56D5d4d",
            value: "42535295865117307932921825928971026431990",
            extra: new Uint8Array(0),
            beneficiary: "0x0000000000000000000000000000000000000000",
          },
          {
            assetType: "3",
            contractAddress: "0x2A187453064356c898cAe034EAed119E1663ACb8",
            value: "100000524771658066136810291574007504540382436851477100100347508325030054457380",
            extra: new Uint8Array(0),
            beneficiary: "0x0000000000000000000000000000000000000000",
          }
        ],
      }
    );

    setSignature(signature);
  };

  return (
    <div>
      <h1>Signature</h1>
      <w3m-button />
      <button onClick={onSign}>Sign</button>
      <pre>{signature}</pre>
    </div>
  );
};

const MerkleTree = () => {
  const values = [
    ["0x0000000000000000000000000000000000000001"],
    ["0x0000000000000000000000000000000000000002"],
    ["0x0000000000000000000000000000000000000003"],
    ["0x0000000000000000000000000000000000000004"],
    ["0x0000000000000000000000000000000000000005"],
    ["0x0000000000000000000000000000000000000006"],
    ["0x0000000000000000000000000000000000000007"],
    ["0x0000000000000000000000000000000000000008"],
    ["0x0000000000000000000000000000000000000009"],
    ["0x2e234DAe75C793f67A35089C9d99245E1C58470b"],
  ];

  const tree = StandardMerkleTree.of(values, ["address"]);

  const [value, setValue] = useState(values[0][0]);

  const proof = useMemo(() => {
    for (const [i, v] of tree.entries()) {
      if (v[0] === value) {
        return tree.getProof(i);
      }
    }
  }, [value]);

  return (
    <div>
      <h1>Merkle Tree</h1>
      <h2>Address</h2>
      <select value={value} onChange={(e) => setValue(e.target.value)}>
        {values.map((value) => {
          return (
            <option key={value[0]} value={value[0]}>
              {value[0]}
            </option>
          );
        })}
      </select>
      <h2>Proof</h2>
      <pre>{JSON.stringify(proof, null, 2)}</pre>
      <h2>Root</h2>
      <pre>{tree.root}</pre>
      <h2>Tree</h2>
      <pre>{JSON.stringify(tree, null, 2)}</pre>
    </div>
  );
};

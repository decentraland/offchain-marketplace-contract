import Head from "next/head";
import Image from "next/image";
import styles from "@/styles/Home.module.css";
import { useMemo, useState } from "react";
import { useWeb3ModalAccount, useWeb3ModalProvider } from "@web3modal/ethers/react";
import { ethers } from "ethers";

const expiration = Math.floor(Date.now() / 1000) + 31556952;
const salt = ethers.zeroPadValue(ethers.toBeArray("1"), 32);
const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

export default function Home() {
  const { walletProvider } = useWeb3ModalProvider();
  const { address } = useWeb3ModalAccount();

  const [isNetworkSwitchHighlighted, setIsNetworkSwitchHighlighted] = useState(false);
  const [isConnectHighlighted, setIsConnectHighlighted] = useState(false);
  const [signature, setSignature] = useState("");

  const closeAll = () => {
    setIsNetworkSwitchHighlighted(false);
    setIsConnectHighlighted(false);
  };

  const handleOnSign = async () => {
    const provider = new ethers.BrowserProvider(walletProvider!);

    const signer = await provider.getSigner();

    const signature = await signer.signTypedData(
      {
        name: "Marketplace",
        version: "0.0.1",
        verifyingContract: contractAddress,
        salt,
      },
      {
        Trade: [
          {
            name: "uses",
            type: "uint256",
          },
          {
            name: "expiration",
            type: "uint256",
          },
          {
            name: "effective",
            type: "uint256",
          },
          {
            name: "salt",
            type: "bytes32",
          },
          {
            name: "contractSignatureIndex",
            type: "uint256",
          },
          {
            name: "signerSignatureIndex",
            type: "uint256",
          },
          {
            name: "allowed",
            type: "address[]",
          },
          {
            name: "sent",
            type: "Asset[]",
          },
          {
            name: "received",
            type: "Asset[]",
          },
        ],
        Asset: [
          {
            name: "assetType",
            type: "uint256",
          },
          {
            name: "contractAddress",
            type: "address",
          },
          {
            name: "value",
            type: "uint256",
          },
          {
            name: "extra",
            type: "bytes",
          },
          {
            name: "beneficiary",
            type: "address",
          },
        ],
      },
      {
        uses: 1,
        expiration,
        effective: 0,
        salt,
        contractSignatureIndex: 0,
        signerSignatureIndex: 0,
        allowed: [],
        sent: [],
        received: [],
      }
    );

    setSignature(signature);
  };

  const handleAccept = async () => {
    const provider = new ethers.BrowserProvider(walletProvider!);

    const signer = await provider.getSigner();

    const contract = new ethers.Contract(
      contractAddress,
      [
        {
          type: "function",
          name: "accept",
          inputs: [
            {
              name: "_trades",
              type: "tuple[]",
              internalType: "struct Marketplace.Trade[]",
              components: [
                { name: "signer", type: "address", internalType: "address" },
                { name: "signature", type: "bytes", internalType: "bytes" },
                { name: "uses", type: "uint256", internalType: "uint256" },
                { name: "expiration", type: "uint256", internalType: "uint256" },
                { name: "effective", type: "uint256", internalType: "uint256" },
                { name: "salt", type: "bytes32", internalType: "bytes32" },
                { name: "contractSignatureIndex", type: "uint256", internalType: "uint256" },
                { name: "signerSignatureIndex", type: "uint256", internalType: "uint256" },
                { name: "allowed", type: "address[]", internalType: "address[]" },
                {
                  name: "sent",
                  type: "tuple[]",
                  internalType: "struct Marketplace.Asset[]",
                  components: [
                    { name: "assetType", type: "uint256", internalType: "uint256" },
                    { name: "contractAddress", type: "address", internalType: "address" },
                    { name: "value", type: "uint256", internalType: "uint256" },
                    { name: "extra", type: "bytes", internalType: "bytes" },
                    { name: "beneficiary", type: "address", internalType: "address" },
                  ],
                },
                {
                  name: "received",
                  type: "tuple[]",
                  internalType: "struct Marketplace.Asset[]",
                  components: [
                    { name: "assetType", type: "uint256", internalType: "uint256" },
                    { name: "contractAddress", type: "address", internalType: "address" },
                    { name: "value", type: "uint256", internalType: "uint256" },
                    { name: "extra", type: "bytes", internalType: "bytes" },
                    { name: "beneficiary", type: "address", internalType: "address" },
                  ],
                },
              ],
            },
          ],
          outputs: [],
          stateMutability: "nonpayable",
        },
      ],
      signer
    );

    const populated = await contract.accept.populateTransaction([
      {
        signer: address,
        signature: signature,
        uses: 1,
        expiration,
        effective: 0,
        salt,
        contractSignatureIndex: 0,
        signerSignatureIndex: 0,
        allowed: [],
        sent: [],
        received: [],
      },
    ]);

		console.log(populated)

		signer.sendTransaction(populated)
  };

  return (
    <>
      <Head>
        <title>WalletConnect | Next Starter Template</title>
        <meta name="description" content="Generated by create-wc-dapp" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      <header>
        <div
          className={styles.backdrop}
          style={{
            opacity: isConnectHighlighted || isNetworkSwitchHighlighted ? 1 : 0,
          }}
        />
        <div className={styles.header}>
          <div className={styles.logo}>
            <Image src="/logo.svg" alt="WalletConnect Logo" height="32" width="203" />
          </div>
          <div className={styles.buttons}>
            <div
              onClick={closeAll}
              className={`${styles.highlight} ${isNetworkSwitchHighlighted ? styles.highlightSelected : ``}`}
            >
              <w3m-network-button />
            </div>
            <div
              onClick={closeAll}
              className={`${styles.highlight} ${isConnectHighlighted ? styles.highlightSelected : ``}`}
            >
              <w3m-button />
            </div>
          </div>
        </div>
      </header>
      <main className={styles.main}>
        <div className={styles.wrapper}>
          <div className={styles.container}>
            <h1>Trade Signature Generator</h1>
            <div className={styles.content}>
              <button onClick={handleOnSign}>Sign</button>
              <div>{signature || "signature..."}</div>
              <button onClick={handleAccept}>Accept</button>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
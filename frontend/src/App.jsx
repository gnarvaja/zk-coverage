import { useState, useEffect } from 'react'
import './App.css'
import { WalletButton } from './components/WalletButton'
import Sidebar from './components/Sidebar'
import PolicyForm from './components/PolicyForm'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { useSendTransaction } from 'wagmi'
import { parseEther } from 'viem'
import { loadStormAreas, loadPriceAreas } from './utils'
import { ZKCOVERAGE_ADDRESS } from './config/config'

import { LeanIMT } from "@zk-kit/lean-imt"
import { poseidon2 } from "poseidon-lite"
import { cellToParent } from "h3-js"
import { UltraHonkBackend } from "@aztec/bb.js";
import { Noir } from "@noir-lang/noir_js";
import claimCircuit from "../../circuits/claim/target/claim.json";
import acquisitionCircuit from "../../circuits/acquisition/target/acquisition.json";
import initNoirC from "@noir-lang/noirc_abi";
import initACVM from "@noir-lang/acvm_js";
import acvm from "@noir-lang/acvm_js/web/acvm_js_bg.wasm?url";
import noirc from "@noir-lang/noirc_abi/web/noirc_abi_wasm_bg.wasm?url";
await Promise.all([initACVM(fetch(acvm)), initNoirC(fetch(noirc))]);

function generateLocationHash(h3Index, salt) {
  return poseidon2([h3Index, salt])
}

function generateMerkleProof(index, h3Array, SeverityArray, nLeaves) {
  var leafs = []
  const length = h3Array.length
  for (var i=0; i < length; i++) {
    var h3Index = h3Array[i]
    var severity = SeverityArray[i]
    leafs.push(poseidon2([h3Index, severity]))
  }
  for (; i < nLeaves; i++) {
    leafs.push(poseidon2([0, 0]))
  }
  const hash = (a, b) => poseidon2([a, b])
  const tree = new LeanIMT(hash)
  tree.insertMany(leafs)
  const proof = tree.generateProof(0)
  return proof
}

function getTreeIndices(n, maxDepth) {
  const indices = []
  for (var i=0; i < maxDepth; i++) {
    var idx = i % 2
    n = Math.floor(n / 2)
    indices.push(n)
  }
  return indices
}

function h3ArraytoHexArray(array) {
  var tmp = []
  array.forEach(h3 => {
    tmp.push("0x" + h3);
  })
  return tmp
}

const bigIntArraytoStringArray = (array) => {
  return array.map(bigInt => bigInt.toString())
}

const validatePolicyData = (data, stormAreas, priceAreas) => {
  try {
    // Check if all required fields exist
    if (!data.name || typeof data.name !== 'string') {
      throw new Error('Invalid or missing policy name')
    }

    if (!data.location || 
        typeof data.location.latitude !== 'number' || 
        typeof data.location.longitude !== 'number') {
      throw new Error('Invalid or missing location data')
    }

    if (!data.h3Index || 
        typeof data.h3Index.h3Index !== 'string' || 
        typeof data.h3Index.resolution !== 'number') {
      throw new Error('Invalid or missing H3 index data')
    }

    if (typeof data.salt !== 'number') {
      throw new Error('Invalid or missing salt value')
    }

    const locationHash = generateLocationHash(data.h3Index.h3Index, data.salt)
    data.locationHash = locationHash

    if (data.acquired == false) {
      const priceArea = h3ArraytoHexArray(priceAreas.price)
      const parent_l6 = cellToParent(data.h3Index.h3Index.substring(2), 3)
      const parent_l2 = cellToParent(data.h3Index.h3Index.substring(2), 2)
      const index = priceAreas.price.indexOf(parent_l6)
      if (index != -1) {
        const proof = generateMerkleProof(index, priceArea, priceAreas.risk, 512)
        data.acquisitionProof = proof
        data.riskBucket = priceAreas.risk[index]
        data.riskLimitArea = "0x" + parent_l2
        data.merkleIndicesAcq = getTreeIndices(index, 9)
      }
    }

    const affectedAreas = h3ArraytoHexArray(stormAreas.affected)
    const parent_l6 = cellToParent(data.h3Index.h3Index.substring(2), 6)
    const index = stormAreas.affected.indexOf(parent_l6)
    
    // If area is affected, generate the claim proof
    if (index !== -1) {
      const proof = generateMerkleProof(index, affectedAreas, stormAreas.severity, 256)
      data.claimProof = proof
      data.severity = stormAreas.severity[index]
      data.merkleIndicesClaim = getTreeIndices(index, 8)
    }

    return { isValid: true, data }
  } catch (error) {
    return { isValid: false, error: error.message }
  }
}

function App() {
  const [policies, setPolicies] = useState([])
  const [selectedPolicy, setSelectedPolicy] = useState(null)
  const [error, setError] = useState(null)
  const [isGeneratingClaimProof, setIsGeneratingClaimProof] = useState(false)
  const [AcquisitionProof, setAquisitionProof] = useState("")
  const [claimTxConfirmed, setClaimTxConfirmed] = useState(false)
  const [isGeneratingAcquisitionProof, setIsGeneratingAcquisitionProof] = useState(false)
  const [ClaimProof, setClaimProof] = useState("")
  const [isCreatingPolicy, setIsCreatingPolicy] = useState(false)
  const [stormAreas, setStormAreas] = useState({ affected: [], severity: [] })
  const [priceAreas, setPriceAreas] = useState({ price: [], risk: [] })
  const [isSendingTx, setIsSendingTx] = useState(false)

  //const { writeContract, data: hash } = useWriteContract()
  const { data: hash, sendTransaction } = useSendTransaction()
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash,
  })

  const handleSendAcquisitionTransaction = async () => {
    try {
      setIsSendingTx(true)
      /*await writeContract({
        address: ZKCOVERAGE_ADDRESS,
        abi: [{ TODO: Fix this
          name: 'claim',
          type: 'function',
          stateMutability: 'nonpayable',
          inputs: [{ name: 'proof', type: 'bytes' }],
          outputs: []
        }],
        functionName: 'claim',
        args: [TODO: Fill this],
      })*/
      await sendTransaction({to:ZKCOVERAGE_ADDRESS, value:parseEther("0.0000000000003")}) // Only for testing
      //setClaimTxConfirmed(true) Comment for testing
    } catch (err) {
      setError('Failed to send transaction: ' + err.message)
    } finally {
      setIsSendingTx(false)
    }
  }

  const handleSendClaimTransaction = async () => {
    try {
      setIsSendingTx(true)
      /*await writeContract({
        address: ZKCOVERAGE_ADDRESS,
        abi: [{ TODO: Fix this
          name: 'claim',
          type: 'function',
          stateMutability: 'nonpayable',
          inputs: [{ name: 'proof', type: 'bytes' }],
          outputs: []
        }],
        functionName: 'claim',
        args: [TODO: Fill this],
      })*/
      await sendTransaction({to:"0x179aef8d2957e4cbe652dc0e94614a5ded6b8e21", value:parseEther("0.0000000000003")}) // Only for testing
      //setClaimTxConfirmed(true) Comment for testing
    } catch (err) {
      setError('Failed to send transaction: ' + err.message)
    } finally {
      setIsSendingTx(false)
    }
  }

  useEffect(() => {
    loadStormAreas().then(setStormAreas).catch(error => {
      setError('Failed to load storm areas: ' + error.message);
    });
  }, [])

  useEffect(() => {
    loadPriceAreas().then(setPriceAreas).catch(error => {
      setError('Failed to load storm areas: ' + error.message);
    });
  }, [])

  const handleCreatePolicy = () => {
    setSelectedPolicy(null)
    setIsCreatingPolicy(true)
  }

  const handleCancelCreate = () => {
    setIsCreatingPolicy(false)
    if (policies.length > 0) {
      setSelectedPolicy(policies[0])
    }
  }

  const handleSubmitPolicy = (newPolicy) => {
    const validation = validatePolicyData(newPolicy, stormAreas, priceAreas)
    if (validation.isValid) {
      const updatedPolicies = [...policies, validation.data]
      setPolicies(updatedPolicies)
      setSelectedPolicy(validation.data)
      setIsCreatingPolicy(false)
      setError(null)
    } else {
      setError(validation.error)
    }
  }

  const generateClaimProof = async (data) => {
    try {
      setIsGeneratingClaimProof(true)
      const user_location_l12 = data.h3Index.h3Index
      console.log(user_location_l12)
      const salt = data.salt
      console.log(salt)
      const locationHash = data.locationHash
      console.log(locationHash)
      const merkleRoot = data.claimProof.root
      console.log(merkleRoot)
      const merkleIndices = data.merkleIndicesClaim
      console.log(merkleIndices)
      const merkleSiblings = data.claimProof.siblings
      console.log(merkleSiblings)
      const severity = data.severity

		  const noir = new Noir(claimCircuit);
		  const backend = new UltraHonkBackend(claimCircuit.bytecode);
      const { witness } = await noir.execute({
         "user_location_l12": user_location_l12.toString(),
         "salt": salt,
         "commited_location_hash": locationHash.toString(),
         "affected_merkle_root": merkleRoot.toString(),
         "merkle_proof_depth": 8,
         "merkle_proof_indices": bigIntArraytoStringArray(merkleIndices),
         "merkle_proof_siblings": bigIntArraytoStringArray(merkleSiblings),
         "severity": severity.toString()
      });
      console.log('Generated claim witness:', witness);
      const proof = await backend.generateProof(witness);
      console.log('Generated claim proof:', proof);
      //TODO: Convert proof to right encoding and update below
      setClaimProof("Proof encoded here")
    } catch (err) {
      setError('Failed to generate claim proof: ' + err.message)
    } finally {
      setIsGeneratingClaimProof(false)
    }
  }

  const generateAcquisitionProof = async (data) => {
    try {
      setIsGeneratingAcquisitionProof(true)
      const user_location_l12 = data.h3Index.h3Index
      console.log("l12:", user_location_l12)
      const salt = data.salt
      console.log("salt:", salt)
      const locationHash = data.locationHash
      console.log("locationHash:", locationHash)
      const merkleRoot = data.acquisitionProof.root
      console.log("roor:", merkleRoot)
      const merkleIndices = data.merkleIndicesAcq
      console.log("indices:", merkleIndices)
      const merkleSiblings = data.acquisitionProof.siblings
      console.log("siblings:", merkleSiblings)
      const riskBucket = data.riskBucket
      const riskLimitArea = data.riskLimitArea

		  const noir = new Noir(acquisitionCircuit);
		  const backend = new UltraHonkBackend(acquisitionCircuit.bytecode);
      const { witness } = await noir.execute({
         "user_location_l12": user_location_l12.toString(),
         "salt": salt,
         "user_location_hash": locationHash.toString(),
         "price_merkle_root": merkleRoot.toString(),
         "merkle_proof_depth": 9,
         "merkle_proof_indices": bigIntArraytoStringArray(merkleIndices),
         "merkle_proof_siblings": bigIntArraytoStringArray(merkleSiblings),
         "risk_bucket": riskBucket.toString(),
         "risk_limit_area_l2": riskLimitArea
      });
      console.log('Generated acquisition witness:', witness);
      const proof = await backend.generateProof(witness);
      console.log('Generated acquisition proof:', proof);
      //TODO: Convert proof to right encoding and update below
      setAquisitionProof("Proof encoded here")
    } catch (err) {
      setError('Failed to generate acquisition proof: ' + err.message)
    } finally {
      setIsGeneratingAcquisitionProof(false)
    }
  }

  const handleDownload = () => {
    if (policies.length === 0) {
      setError('No policies to download')
      return
    }

    const dataToDownload = {
      policies: policies
    }

    console.log(dataToDownload)

    const blob = new Blob([JSON.stringify(dataToDownload, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = 'policies.json'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  const handleFileUpload = (event) => {
    const file = event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const jsonData = JSON.parse(e.target.result)
        
        // Check if the JSON has a policies array
        if (!jsonData.policies || !Array.isArray(jsonData.policies)) {
          throw new Error('Invalid JSON format: missing policies array')
        }

        // Validate each policy
        const validatedPolicies = jsonData.policies.map(policy => {
          const validation = validatePolicyData(policy, stormAreas, priceAreas)
          if (!validation.isValid) {
            throw new Error(`Invalid policy ${policy.name}: ${validation.error}`)
          }
          return validation.data
        })

        setPolicies(validatedPolicies)
        setSelectedPolicy(validatedPolicies[0])
        setError(null)
      } catch (err) {
        setError(err.message)
        setPolicies([])
        setSelectedPolicy(null)
      }
    }
    reader.readAsText(file)
  }

  return (
    <div className="container">
      <Sidebar 
        policies={policies}
        selectedPolicy={selectedPolicy}
        onSelectPolicy={setSelectedPolicy}
        onCreatePolicy={handleCreatePolicy}
        onFileUpload={handleFileUpload}
        onDownload={handleDownload}
      />
      <div className="main-content">
        <WalletButton />
        <h1>ZK Coverage</h1>

        {error && (
          <div className="error-message">
            {error}
          </div>
        )}

        {isCreatingPolicy ? (
          <PolicyForm 
            onSubmit={handleSubmitPolicy}
            onCancel={handleCancelCreate}
          />
        ) : selectedPolicy && (
          <div className="policy-data">
            <h2>{selectedPolicy.name}</h2>
            <div className="data-section">
              <h3>Location</h3>
              <p>Latitude: {selectedPolicy.location.latitude}</p>
              <p>Longitude: {selectedPolicy.location.longitude}</p>
            </div>
            <div className="data-section">
              <h3>H3 Index</h3>
              <p>Index: {selectedPolicy.h3Index.h3Index}</p>
              <p>Resolution: {selectedPolicy.h3Index.resolution}</p>
            </div>
            <div className="data-section">
              <p>Salt: {selectedPolicy.salt}</p>
            </div>
            
              <div className="proof-section">
                {!AcquisitionProof ? (
                  <button
                    className="generate-acquisition-proof-button"
                    onClick={() => generateAcquisitionProof(selectedPolicy)}
                    disabled={isGeneratingAcquisitionProof}
                  >
                    {isGeneratingAcquisitionProof ? 'Generating...' : 'Generate Acquisition Proof'}
                  </button>
                ) : (
                  <button
                    className="generate-acquisition-proof-button"
                    onClick={handleSendAcquisitionTransaction}
                    disabled={isSendingTx || isConfirming}
                  >
                    {isSendingTx ? 'Preparing...' : isConfirming ? 'Confirming...' : 'Send Transaction'}
                  </button>
                )}
                {!ClaimProof ? (                <button
                  className={`generate-claim-proof-button ${!AcquisitionProof ? "disabled" : ""}`}
                  onClick={() => generateClaimProof(selectedPolicy)}
                  disabled={isGeneratingClaimProof || !AcquisitionProof}
                >
                  {isGeneratingClaimProof ? 'Generating...' : 'Generate Claim Proof'}
                </button>) : (                <button
                  className={"generate-claim-proof-button"}
                  onClick={handleSendClaimTransaction}
                  disabled={isSendingTx || isConfirming}
                >
                  {isSendingTx ? 'Preparing...' : isConfirming ? 'Confirming...' : 'Send Transaction'}
                </button>)}

              </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default App

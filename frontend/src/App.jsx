import { useState } from 'react'
import './App.css'
import { WalletButton } from './components/WalletButton'
import Sidebar from './components/Sidebar'
import PolicyForm from './components/PolicyForm'

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

function generateMerkleProof(index, h3Array, SeverityArray) {
  var leafs = []
  const length = h3Array.length
  for (var i=0; i < length; i++) {
    var h3Index = h3Array[i]
    var severity = SeverityArray[i]
    leafs.push(poseidon2([h3Index, severity]))
  }
  for (; i < 256; i++) {
    leafs.push(0)
  }
  //if (length % 2 == 1) {
  //  leafs.push(poseidon2([0]))
  //}
  const hash = (a, b) => poseidon2([a, b])
  const tree = new LeanIMT(hash)
  tree.insertMany(leafs)
  const proof = tree.generateProof(0)
  //console.log(proof)
  return proof
}

const bigIntArraytoStringArray = (array) => {
  return array.map(bigInt => bigInt.toString())
}

const validatePolicyData = (data) => {
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

    // The merkleLeaf field is optional, but if present must be non-null
    //if ('merkleLeaf' in data && data.merkleLeaf === null) {
    //  throw new Error('merkleLeaf field cannot be null if present')
    //}

    const affected = ["0x862640007ffffff", "0x866a00007ffffff"];
    const severity = [1, 1];
    const parent = "0x" + cellToParent(data.h3Index.h3Index.substring(2), 6)
    console.log("PARENT:", parent)
    const index = affected.indexOf(parent)
    if (index != -1) {
      //console.log("Included")
      const proof = generateMerkleProof(index, affected, severity)
      //console.log(proof)
      data.proof = proof
      const locationHash = generateLocationHash(data.h3Index.h3Index, data.salt)
      data.locationHash = locationHash
    }
    //console.log(data)

    return { isValid: true, data }
  } catch (error) {
    return { isValid: false, error: error.message }
  }
}

function App() {
  const [policies, setPolicies] = useState([])
  const [selectedPolicy, setSelectedPolicy] = useState(null)
  const [error, setError] = useState(null)
  const [isGeneratingProof, setIsGeneratingProof] = useState(false)
  const [isCreatingPolicy, setIsCreatingPolicy] = useState(false)

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
    const validation = validatePolicyData(newPolicy)
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

  const generateProof = async (data) => {
    try {
      setIsGeneratingProof(true)
      const user_location_l12 = data.h3Index.h3Index
      console.log(user_location_l12)
      const salt = data.salt
      console.log(salt)
      const locationHash = data.locationHash
      console.log(locationHash)
      const merkleRoot = data.proof.root
      console.log(merkleRoot)
      const merkleIndices = [0, 0, 0, 0, 0, 0, 0, 0] //TODO generate this per input
      console.log(merkleIndices)
      const merkleSiblings = data.proof.siblings
      console.log(merkleSiblings)
      //console.log(bigIntArraytoStringArray(merkleSiblings))

		  const noir = new Noir(claimCircuit);
		  const backend = new UltraHonkBackend(claimCircuit.bytecode);
      //const { witness } = await noir.execute({ "x" : merkleRoot.toString()})
      const { witness } = await noir.execute({
         "user_location_l12": user_location_l12.toString(),
         "salt": salt,
         "commited_location_hash": locationHash.toString(),
         "affected_merkle_root": merkleRoot.toString(),
         "merkle_proof_depth": 1,
         "merkle_proof_indices": bigIntArraytoStringArray(merkleIndices),
         "merkle_proof_siblings": bigIntArraytoStringArray(merkleSiblings),
         "severity": 1
      });
      console.log('Generated witness:', witness);
      const proof = await backend.generateProof(witness);
      console.log('Generated proof:', proof);
    } catch (err) {
      setError('Failed to generate proof: ' + err.message)
    } finally {
      setIsGeneratingProof(false)
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
          const validation = validatePolicyData(policy)
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
            
            {selectedPolicy.proof && (
              <div className="proof-section">
                <button
                  className="generate-proof-button"
                  onClick={() => generateProof(selectedPolicy)}
                  disabled={isGeneratingProof}
                >
                  {isGeneratingProof ? 'Generating...' : 'Generate Proof'}
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default App

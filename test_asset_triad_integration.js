#!/usr/bin/env node

/**
 * Asset Canister Triad Integration Test
 * 
 * This script tests the full Triad workflow:
 * 1. Create test users with Identities, Users, and Wallets
 * 2. Register assets using Triad endpoints
 * 3. Transfer assets between Identities
 * 4. Test both Triad and Legacy endpoints
 * 5. Verify data consistency and performance
 */

const { Actor, HttpAgent } = require('@dfinity/agent');
const { Principal } = require('@dfinity/principal');
const fs = require('fs');

// Test configuration
const TEST_CONFIG = {
    canisterId: 'rdmx6-jaaaa-aaaaa-aaadq-cai', // Replace with actual Asset canister ID
    network: 'local', // Change to 'ic' for mainnet
    agent: null,
    assetCanister: null
};

// Mock LinkProof for testing (in production, this would be cryptographically generated)
function createMockLinkProof() {
    return {
        signature: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]), // Mock signature
        challenge: new Uint8Array([9, 10, 11, 12, 13, 14, 15, 16]), // Mock challenge
        device: [new Uint8Array([17, 18, 19, 20])] // Mock device key
    };
}

// Test user data
const TEST_USERS = {
    alice: {
        identity: Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // Mock Identity Principal
        user: Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),     // Mock User Principal  
        wallet: Principal.fromText("rno2w-sqaaa-aaaaa-aaacq-cai"),   // Mock Wallet Principal
        name: "Alice"
    },
    bob: {
        identity: Principal.fromText("renrk-eyaaa-aaaaa-aaada-cai"), // Mock Identity Principal
        user: Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),     // Mock User Principal
        wallet: Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),   // Mock Wallet Principal  
        name: "Bob"
    },
    charlie: {
        identity: Principal.fromText("rno2w-sqaaa-aaaaa-aaacq-cai"), // Mock Identity Principal
        user: null, // Charlie has no User context
        wallet: Principal.fromText("renrk-eyaaa-aaaaa-aaada-cai"),   // Mock Wallet Principal
        name: "Charlie"
    }
};

// Asset Canister IDL (simplified for testing)
const assetIdl = ({ IDL }) => {
    const LinkProof = IDL.Record({
        'signature': IDL.Vec(IDL.Nat8),
        'challenge': IDL.Vec(IDL.Nat8), 
        'device': IDL.Opt(IDL.Vec(IDL.Nat8))
    });

    const Asset = IDL.Record({
        'id': IDL.Nat,
        'metadata': IDL.Text,
        'ownerIdentity': IDL.Principal,
        'userId': IDL.Opt(IDL.Principal),
        'walletId': IDL.Opt(IDL.Principal),
        'active': IDL.Bool,
        'triadVerified': IDL.Bool,
        'createdAt': IDL.Nat64,
        'updatedAt': IDL.Nat64
    });

    const Result = (ok, err) => IDL.Variant({ 'ok': ok, 'err': err });

    return IDL.Service({
        // Triad endpoints
        'registerAssetTriad': IDL.Func(
            [IDL.Principal, IDL.Text, LinkProof, IDL.Opt(IDL.Principal), IDL.Opt(IDL.Principal)],
            [Result(IDL.Nat, IDL.Text)],
            []
        ),
        'transferAssetTriad': IDL.Func(
            [IDL.Principal, IDL.Nat, IDL.Principal, LinkProof, IDL.Opt(IDL.Principal)],
            [Result(IDL.Null, IDL.Text)],
            []
        ),
        'deactivateAssetTriad': IDL.Func(
            [IDL.Principal, IDL.Nat, LinkProof],
            [Result(IDL.Null, IDL.Text)],
            []
        ),
        
        // Legacy endpoints
        'registerAsset': IDL.Func(
            [IDL.Principal, IDL.Text],
            [Result(IDL.Nat, IDL.Text)],
            []
        ),
        'transferAsset': IDL.Func(
            [IDL.Nat, IDL.Principal],
            [Result(IDL.Null, IDL.Text)],
            []
        ),
        
        // Query endpoints
        'getAsset': IDL.Func([IDL.Nat], [Result(Asset, IDL.Text)], ['query']),
        'getAllAssets': IDL.Func([], [IDL.Vec(Asset)], ['query']),
        'getAssetsByOwner': IDL.Func([IDL.Principal], [IDL.Vec(Asset)], ['query']),
        'getActiveAssets': IDL.Func([], [IDL.Vec(Asset)], ['query']),
        'searchAssetsByMetadata': IDL.Func([IDL.Text], [IDL.Vec(Asset)], ['query']),
        'getSystemStats': IDL.Func([], [IDL.Record({
            'totalAssets': IDL.Nat,
            'activeAssets': IDL.Nat,
            'triadVerifiedAssets': IDL.Nat
        })], ['query'])
    });
};

// Test results tracking
let testResults = {
    total: 0,
    passed: 0,
    failed: 0,
    errors: []
};

function logTest(testName, passed, details = "") {
    testResults.total++;
    if (passed) {
        testResults.passed++;
        console.log(`✅ ${testName}`);
    } else {
        testResults.failed++;
        console.log(`❌ ${testName} - ${details}`);
        testResults.errors.push(`${testName}: ${details}`);
    }
}

// Initialize the test environment
async function initializeTest() {
    console.log("🚀 Initializing Asset Canister Triad Integration Test...\n");
    
    try {
        // Create agent
        TEST_CONFIG.agent = new HttpAgent({ 
            host: TEST_CONFIG.network === 'local' ? 'http://localhost:4943' : 'https://ic0.app'
        });
        
        // In local development, fetch root key
        if (TEST_CONFIG.network === 'local') {
            await TEST_CONFIG.agent.fetchRootKey();
        }
        
        // Create Asset canister actor
        TEST_CONFIG.assetCanister = Actor.createActor(assetIdl, {
            agent: TEST_CONFIG.agent,
            canisterId: TEST_CONFIG.canisterId
        });
        
        console.log(`📍 Connected to Asset Canister: ${TEST_CONFIG.canisterId}\n`);
        return true;
    } catch (error) {
        console.error("❌ Failed to initialize test environment:", error);
        return false;
    }
}

// Test 1: System Status and Initial State
async function testInitialSystemState() {
    console.log("📊 Testing Initial System State...");
    
    try {
        const stats = await TEST_CONFIG.assetCanister.getSystemStats();
        console.log(`   Total Assets: ${stats.totalAssets}`);
        console.log(`   Active Assets: ${stats.activeAssets}`);  
        console.log(`   Triad Verified: ${stats.triadVerifiedAssets}`);
        
        logTest("Initial System Stats", true);
        return stats;
    } catch (error) {
        logTest("Initial System Stats", false, error.message);
        return null;
    }
}

// Test 2: Register Assets using Triad Endpoints
async function testTriadAssetRegistration() {
    console.log("\n🔥 Testing Triad Asset Registration...");
    
    const registeredAssets = [];
    
    for (const [userName, user] of Object.entries(TEST_USERS)) {
        try {
            const proof = createMockLinkProof();
            const metadata = `${user.name}'s Premium Digital Asset - Created ${new Date().toISOString()}`;
            
            console.log(`   Registering asset for ${user.name}...`);
            const result = await TEST_CONFIG.assetCanister.registerAssetTriad(
                user.identity,
                metadata,
                proof,
                user.user ? [user.user] : [],
                user.wallet ? [user.wallet] : []
            );
            
            if ('ok' in result) {
                const assetId = result.ok;
                registeredAssets.push({ userName, assetId, user });
                console.log(`   ✅ Asset ${assetId} registered for ${user.name}`);
                logTest(`Triad Asset Registration - ${user.name}`, true);
            } else {
                console.log(`   ❌ Failed to register asset for ${user.name}: ${result.err}`);
                logTest(`Triad Asset Registration - ${user.name}`, false, result.err);
            }
        } catch (error) {
            console.log(`   ❌ Error registering asset for ${user.name}: ${error.message}`);
            logTest(`Triad Asset Registration - ${user.name}`, false, error.message);
        }
    }
    
    return registeredAssets;
}

// Test 3: Register Assets using Legacy Endpoints (for comparison)
async function testLegacyAssetRegistration() {
    console.log("\n🔄 Testing Legacy Asset Registration...");
    
    const legacyAssets = [];
    
    try {
        const metadata = "Legacy Asset - Backward Compatibility Test";
        const result = await TEST_CONFIG.assetCanister.registerAsset(
            TEST_USERS.alice.identity,
            metadata
        );
        
        if ('ok' in result) {
            const assetId = result.ok;
            legacyAssets.push({ assetId, owner: TEST_USERS.alice.identity });
            console.log(`   ✅ Legacy Asset ${assetId} registered`);
            logTest("Legacy Asset Registration", true);
        } else {
            logTest("Legacy Asset Registration", false, result.err);
        }
    } catch (error) {
        logTest("Legacy Asset Registration", false, error.message);
    }
    
    return legacyAssets;
}

// Test 4: Query Assets and Verify Data Structure
async function testAssetQueries(registeredAssets) {
    console.log("\n🔍 Testing Asset Queries...");
    
    if (registeredAssets.length === 0) {
        console.log("   ⚠️  No assets to query");
        return;
    }
    
    // Test individual asset retrieval
    for (const asset of registeredAssets) {
        try {
            const result = await TEST_CONFIG.assetCanister.getAsset(asset.assetId);
            
            if ('ok' in result) {
                const assetData = result.ok;
                console.log(`   📄 Asset ${asset.assetId}:`);
                console.log(`      Owner Identity: ${assetData.ownerIdentity.toString()}`);
                console.log(`      User ID: ${assetData.userId.length > 0 ? assetData.userId[0].toString() : 'None'}`);
                console.log(`      Wallet ID: ${assetData.walletId.length > 0 ? assetData.walletId[0].toString() : 'None'}`);
                console.log(`      Triad Verified: ${assetData.triadVerified}`);
                console.log(`      Active: ${assetData.active}`);
                console.log(`      Metadata: ${assetData.metadata.substring(0, 50)}...`);
                
                logTest(`Asset Query - ${asset.userName}`, true);
            } else {
                logTest(`Asset Query - ${asset.userName}`, false, result.err);
            }
        } catch (error) {
            logTest(`Asset Query - ${asset.userName}`, false, error.message);
        }
    }
    
    // Test owner-based queries
    for (const [userName, user] of Object.entries(TEST_USERS)) {
        try {
            const userAssets = await TEST_CONFIG.assetCanister.getAssetsByOwner(user.identity);
            console.log(`   👤 ${user.name} owns ${userAssets.length} assets`);
            logTest(`Owner Query - ${user.name}`, true);
        } catch (error) {
            logTest(`Owner Query - ${user.name}`, false, error.message);
        }
    }
    
    // Test metadata search
    try {
        const searchResults = await TEST_CONFIG.assetCanister.searchAssetsByMetadata("Premium");
        console.log(`   🔍 Found ${searchResults.length} assets with 'Premium' in metadata`);
        logTest("Metadata Search", true);
    } catch (error) {
        logTest("Metadata Search", false, error.message);
    }
}

// Test 5: Asset Transfer using Triad Endpoints
async function testTriadAssetTransfer(registeredAssets) {
    console.log("\n🔄 Testing Triad Asset Transfer...");
    
    if (registeredAssets.length < 2) {
        console.log("   ⚠️  Need at least 2 assets for transfer test");
        return;
    }
    
    const aliceAsset = registeredAssets.find(a => a.userName === 'alice');
    const bobUser = TEST_USERS.bob;
    
    if (!aliceAsset) {
        console.log("   ⚠️  Alice's asset not found for transfer test");
        return;
    }
    
    try {
        const proof = createMockLinkProof();
        console.log(`   Transferring asset ${aliceAsset.assetId} from Alice to Bob...`);
        
        const result = await TEST_CONFIG.assetCanister.transferAssetTriad(
            aliceAsset.user.identity,  // Current owner (Alice's Identity)
            aliceAsset.assetId,        // Asset to transfer
            bobUser.identity,          // New owner (Bob's Identity)
            proof,                     // LinkProof
            bobUser.user ? [bobUser.user] : [] // Optional User context
        );
        
        if ('ok' in result) {
            console.log(`   ✅ Asset ${aliceAsset.assetId} successfully transferred to Bob`);
            logTest("Triad Asset Transfer", true);
            
            // Verify the transfer
            const assetResult = await TEST_CONFIG.assetCanister.getAsset(aliceAsset.assetId);
            if ('ok' in assetResult) {
                const asset = assetResult.ok;
                const transferSuccessful = asset.ownerIdentity.toString() === bobUser.identity.toString();
                logTest("Transfer Verification", transferSuccessful, 
                    transferSuccessful ? "" : `Expected ${bobUser.identity}, got ${asset.ownerIdentity}`);
            }
        } else {
            logTest("Triad Asset Transfer", false, result.err);
        }
    } catch (error) {
        logTest("Triad Asset Transfer", false, error.message);
    }
}

// Test 6: Asset Deactivation/Reactivation
async function testAssetLifecycle(registeredAssets) {
    console.log("\n🔄 Testing Asset Lifecycle (Deactivate/Reactivate)...");
    
    if (registeredAssets.length === 0) {
        console.log("   ⚠️  No assets available for lifecycle test");
        return;
    }
    
    const testAsset = registeredAssets[0];
    const proof = createMockLinkProof();
    
    try {
        // Deactivate asset
        console.log(`   Deactivating asset ${testAsset.assetId}...`);
        const deactivateResult = await TEST_CONFIG.assetCanister.deactivateAssetTriad(
            testAsset.user.identity,
            testAsset.assetId,
            proof
        );
        
        if ('ok' in deactivateResult) {
            console.log(`   ✅ Asset ${testAsset.assetId} deactivated`);
            logTest("Asset Deactivation", true);
            
            // Verify deactivation
            const assetResult = await TEST_CONFIG.assetCanister.getAsset(testAsset.assetId);
            if ('ok' in assetResult) {
                const isDeactivated = !assetResult.ok.active;
                logTest("Deactivation Verification", isDeactivated);
            }
        } else {
            logTest("Asset Deactivation", false, deactivateResult.err);
        }
        
        // Reactivate asset
        console.log(`   Reactivating asset ${testAsset.assetId}...`);
        const reactivateResult = await TEST_CONFIG.assetCanister.reactivateAssetTriad(
            testAsset.user.identity,
            testAsset.assetId,  
            proof
        );
        
        if ('ok' in reactivateResult) {
            console.log(`   ✅ Asset ${testAsset.assetId} reactivated`);
            logTest("Asset Reactivation", true);
            
            // Verify reactivation
            const assetResult = await TEST_CONFIG.assetCanister.getAsset(testAsset.assetId);
            if ('ok' in assetResult) {
                const isActive = assetResult.ok.active;
                logTest("Reactivation Verification", isActive);
            }
        } else {
            logTest("Asset Reactivation", false, reactivateResult.err);
        }
        
    } catch (error) {
        logTest("Asset Lifecycle", false, error.message);
    }
}

// Test 7: Final System State
async function testFinalSystemState(initialStats) {
    console.log("\n📊 Testing Final System State...");
    
    try {
        const finalStats = await TEST_CONFIG.assetCanister.getSystemStats();
        console.log(`   📈 Statistics Comparison:`);
        console.log(`      Total Assets: ${initialStats?.totalAssets || 0} → ${finalStats.totalAssets}`);
        console.log(`      Active Assets: ${initialStats?.activeAssets || 0} → ${finalStats.activeAssets}`);
        console.log(`      Triad Verified: ${initialStats?.triadVerifiedAssets || 0} → ${finalStats.triadVerifiedAssets}`);
        
        const hasNewAssets = finalStats.totalAssets > (initialStats?.totalAssets || 0);
        const hasTriadAssets = finalStats.triadVerifiedAssets > (initialStats?.triadVerifiedAssets || 0);
        
        logTest("Final System State", hasNewAssets && hasTriadAssets, 
            !hasNewAssets ? "No new assets created" : !hasTriadAssets ? "No Triad-verified assets" : "");
            
        return finalStats;
    } catch (error) {
        logTest("Final System State", false, error.message);
        return null;
    }
}

// Performance Test: Owner Query Speed
async function testOwnerQueryPerformance() {
    console.log("\n⚡ Testing Owner Query Performance...");
    
    try {
        const startTime = Date.now();
        const aliceAssets = await TEST_CONFIG.assetCanister.getAssetsByOwner(TEST_USERS.alice.identity);
        const endTime = Date.now();
        
        const duration = endTime - startTime;
        console.log(`   📊 Owner query completed in ${duration}ms`);
        console.log(`   📄 Found ${aliceAssets.length} assets for Alice`);
        
        logTest("Owner Query Performance", duration < 1000, 
            duration >= 1000 ? `Query took ${duration}ms (should be <1000ms)` : "");
            
    } catch (error) {
        logTest("Owner Query Performance", false, error.message);
    }
}

// Main test execution
async function runTests() {
    console.log("🧪 ASSET CANISTER TRIAD INTEGRATION TEST SUITE");
    console.log("=".repeat(60));
    
    // Initialize
    const initialized = await initializeTest();
    if (!initialized) {
        console.log("❌ Test initialization failed. Exiting.");
        return;
    }
    
    // Execute test suite
    const initialStats = await testInitialSystemState();
    const triadAssets = await testTriadAssetRegistration();
    const legacyAssets = await testLegacyAssetRegistration();
    await testAssetQueries(triadAssets);
    await testTriadAssetTransfer(triadAssets);
    await testAssetLifecycle(triadAssets);
    await testOwnerQueryPerformance();
    const finalStats = await testFinalSystemState(initialStats);
    
    // Test summary
    console.log("\n" + "=".repeat(60));
    console.log("🎯 TEST SUMMARY");
    console.log("=".repeat(60));
    console.log(`Total Tests: ${testResults.total}`);
    console.log(`✅ Passed: ${testResults.passed}`);
    console.log(`❌ Failed: ${testResults.failed}`);
    console.log(`Success Rate: ${Math.round((testResults.passed / testResults.total) * 100)}%`);
    
    if (testResults.failed > 0) {
        console.log("\n🚨 FAILED TESTS:");
        testResults.errors.forEach(error => console.log(`   • ${error}`));
    }
    
    if (testResults.passed === testResults.total) {
        console.log("\n🎉 ALL TESTS PASSED! Asset Canister Triad integration is working correctly.");
    } else {
        console.log(`\n⚠️  ${testResults.failed} tests failed. Review the errors above.`);
    }
    
    console.log("\n📋 NEXT STEPS:");
    console.log("   1. Connect real Identity, User, and Wallet canisters");
    console.log("   2. Replace mock LinkProof with real cryptographic verification");
    console.log("   3. Test with larger datasets for performance validation");
    console.log("   4. Implement event hub integration for audit trails");
    console.log("   5. Start migrating other canisters to Triad architecture");
}

// Handle script execution
if (require.main === module) {
    runTests().catch(error => {
        console.error("🚨 Test execution failed:", error);
        process.exit(1);
    });
}

module.exports = { runTests, testResults };

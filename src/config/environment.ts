// AxiaSystem Environment Configuration
// Automatically manages canister IDs across development, testnet, and production

import { useState, useEffect } from 'react';

export type NetworkType = 'local' | 'ic' | 'testnet';

export interface CanisterConfig {
  [key: string]: string;
}

export interface NetworkConfig {
  host: string;
  replica_host: string;
  description: string;
}

// Network configurations
export const NETWORKS: Record<NetworkType, NetworkConfig> = {
  local: {
    host: 'http://localhost:8000',
    replica_host: 'http://127.0.0.1:8000',
    description: 'Local development network'
  },
  ic: {
    host: 'https://ic0.app',
    replica_host: 'https://ic0.app', 
    description: 'Internet Computer mainnet'
  },
  testnet: {
    host: 'https://testnet.dfinity.network',
    replica_host: 'https://testnet.dfinity.network',
    description: 'IC testnet environment'
  }
};

// Environment detection
export const getCurrentNetwork = (): NetworkType => {
  // Check environment variables first
  if (typeof process !== 'undefined' && process?.env) {
    const envNetwork = process.env.DFX_NETWORK || process.env.NODE_ENV;
    if (envNetwork === 'production') return 'ic';
    if (envNetwork === 'testnet') return 'testnet';
    if (envNetwork === 'development' || envNetwork === 'local') return 'local';
  }
  
  // Check hostname for browser environments
  if (typeof window !== 'undefined') {
    const hostname = window.location.hostname;
    if (hostname.includes('ic0.app') || hostname.includes('icp0.io')) return 'ic';
    if (hostname.includes('testnet')) return 'testnet';
    if (hostname.includes('localhost') || hostname === '127.0.0.1') return 'local';
  }
  
  // Default to local for development
  return 'local';
};

// Dynamic canister ID loading
export const loadCanisterIds = async (network?: NetworkType): Promise<CanisterConfig> => {
  const targetNetwork = network || getCurrentNetwork();
  
  try {
    // Try to load network-specific canister IDs
    const response = await fetch(`/canister_ids_${targetNetwork}.json`);
    if (response.ok) {
      return await response.json();
    }
  } catch (error) {
    console.warn(`Could not load canister IDs for ${targetNetwork}, falling back to default`);
  }
  
  try {
    // Fallback to default canister_ids.json
    const response = await fetch('/canister_ids.json');
    if (response.ok) {
      return await response.json();
    }
  } catch (error) {
    console.warn('Could not load default canister IDs');
  }
  
  // Final fallback to hardcoded IDs (development)
  return getDefaultCanisterIds(targetNetwork);
};

// Default canister IDs for development
const getDefaultCanisterIds = (network: NetworkType): CanisterConfig => {
  // These will be updated by the update_canister_ids.sh script
  return {
    asset: 'bw4dl-smaaa-aaaaa-qaacq-cai',
    asset_registry: 'ucwa4-rx777-77774-qaada-cai',
    user: 'xad5d-bh777-77774-qaaia-cai',
    identity: 'asrmz-lmaaa-aaaaa-qaaeq-cai',
    wallet: 'cuj6u-c4aaa-aaaaa-qaajq-cai',
    AxiaSystem_backend: 'be2us-64aaa-aaaaa-qaabq-cai'
  };
};

// Canister management class
export class CanisterManager {
  private network: NetworkType;
  private canisterIds: CanisterConfig = {};
  private initialized = false;

  constructor(network?: NetworkType) {
    this.network = network || getCurrentNetwork();
  }

  async initialize(): Promise<void> {
    if (this.initialized) return;
    
    this.canisterIds = await loadCanisterIds(this.network);
    this.initialized = true;
    
    console.log(`🔧 CanisterManager initialized for ${this.network}`, this.canisterIds);
  }

  async getCanisterId(name: string): Promise<string> {
    await this.initialize();
    
    const id = this.canisterIds[name];
    if (!id) {
      throw new Error(`Canister ID not found for: ${name}`);
    }
    
    return id;
  }

  async getAllCanisterIds(): Promise<CanisterConfig> {
    await this.initialize();
    return { ...this.canisterIds };
  }

  getNetworkConfig(): NetworkConfig {
    return NETWORKS[this.network];
  }

  getCurrentNetwork(): NetworkType {
    return this.network;
  }

  // Switch networks (useful for admin interfaces)
  async switchNetwork(network: NetworkType): Promise<void> {
    this.network = network;
    this.initialized = false;
    await this.initialize();
  }

  // Helper to create actor configurations
  async createActorConfig(canisterName: string) {
    const canisterId = await this.getCanisterId(canisterName);
    const networkConfig = this.getNetworkConfig();
    
    return {
      canisterId,
      host: networkConfig.host,
      // Dynamic import for IDL factory
      idlFactory: async () => {
        const module = await import(`../declarations/${canisterName}/${canisterName}.did.js`);
        return module.idlFactory;
      },
    };
  }
}

// Global instance
export const canisterManager = new CanisterManager();

// React hook for easy integration
export const useCanisterManager = () => {
  const [isReady, setIsReady] = useState(false);
  
  useEffect(() => {
    canisterManager.initialize().then(() => setIsReady(true));
  }, []);
  
  return {
    canisterManager,
    isReady,
    network: canisterManager.getCurrentNetwork(),
    networkConfig: canisterManager.getNetworkConfig()
  };
};

// Development utilities
export const devUtils = {
  // Log all canister IDs
  async logCanisterIds() {
    const ids = await canisterManager.getAllCanisterIds();
    console.table(ids);
  },
  
  // Validate canister ID format
  validateCanisterId(id: string): boolean {
    return /^[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{3}$/.test(id);
  },
  
  // Check if running in development
  isDevelopment(): boolean {
    return canisterManager.getCurrentNetwork() === 'local';
  }
};

// Export for global access
if (typeof window !== 'undefined') {
  (window as any).AxiaCanisterManager = canisterManager;
  (window as any).AxiaDevUtils = devUtils;
}

<script>
  import { onMount } from 'svelte';
  import NamoraInsights from './NamoraInsights.svelte';
  
  let currentModule = 'overview';
  let connected = false;
  let activeAdminTab = 'dashboard';
  let userSearchQuery = '';
  let adminData = {
    totalUsers: 42,
    activeProjects: 7,
    systemHealth: '🟢',
    queueLength: 3,
    recentActions: [
      { timestamp: '2024-01-15 14:23', action: 'User registration processed', admin: 'System' },
      { timestamp: '2024-01-15 13:45', action: 'Payment timeout resolved', admin: 'AutoAdmin' },
      { timestamp: '2024-01-15 12:10', action: 'Asset registry updated', admin: 'Admin-001' }
    ],
    users: [
      { 
        principal: 'rdmx6-jaaaa-aaaah-qcaiq-cai', 
        name: 'Alice Builder', 
        registrationDate: '2024-01-10', 
        projectCount: 3, 
        isActive: true 
      },
      { 
        principal: 'rrkah-fqaaa-aaaah-qcaiq-cai', 
        name: 'Bob Creator', 
        registrationDate: '2024-01-12', 
        projectCount: 1, 
        isActive: true 
      }
    ],
    activityLogs: [
      { 
        timestamp: '2024-01-15 14:23:12', 
        action: 'User Registration', 
        actor: 'alice.principal', 
        details: 'New user identity created', 
        success: true 
      },
      { 
        timestamp: '2024-01-15 14:20:45', 
        action: 'Payment Processing', 
        actor: 'bob.principal', 
        details: 'Cross-chain payment initiated', 
        success: true 
      }
    ]
  };
  let userPrincipal = null;
  
  // Core AxiaSystem modules based on your canisters
  const modules = [
    {
      id: 'overview',
      name: 'Civilization Overview',
      icon: '🏛️',
      description: 'The sovereign framework dashboard',
      color: 'from-blue-500 to-purple-600'
    },
    {
      id: 'admin',
      name: 'AxiaAdmin',
      icon: '⚡',
      description: 'System administration & oversight',
      color: 'from-amber-500 to-red-600'
    },
    {
      id: 'identity',
      name: 'AxiaIdentity',
      icon: '🔐',
      description: 'Self-sovereign identity management',
      color: 'from-emerald-500 to-teal-600'
    },
    {
      id: 'assets',
      name: 'AxiaAsset',
      icon: '💎',
      description: 'Digital & physical asset registry',
      color: 'from-amber-500 to-orange-600'
    },
    {
      id: 'wallet',
      name: 'AxiaWallet',
      icon: '👛',
      description: 'Programmable multi-chain wallet',
      color: 'from-green-500 to-emerald-600'
    },
    {
      id: 'payment',
      name: 'AxiaPayment',
      icon: '💰',
      description: 'Cross-dimensional value transfer',
      color: 'from-blue-500 to-cyan-600'
    },
    {
      id: 'governance',
      name: 'AxiaGovernance',
      icon: '🗳️',
      description: 'Decentralized decision framework',
      color: 'from-purple-500 to-pink-600'
    },
    {
      id: 'bridge',
      name: 'AxiaBridge',
      icon: '🌉',
      description: 'XRPL & multi-chain connector',
      color: 'from-red-500 to-rose-600'
    }
  ];

  function selectModule(moduleId) {
    currentModule = moduleId;
  }

  onMount(() => {
    // Simulate connection status
    setTimeout(() => {
      connected = true;
      userPrincipal = "2vxsx-fae";
    }, 1000);
  });
</script>

<main class="civilization-framework">
  <!-- Golden Ratio Header: 15.2% of viewport -->
  <header class="sovereign-header">
    <div class="header-content">
      <div class="logo-section">
        <h1 class="civilization-title">⚡ AxiaSystem</h1>
        <p class="subtitle">Sovereign Civilization Framework</p>
      </div>
      
      <div class="connection-status">
        {#if connected}
          <div class="connected">
            <span class="status-indicator"></span>
            <span class="principal-id">{userPrincipal}</span>
          </div>
        {:else}
          <div class="connecting">
            <span class="loading-spinner"></span>
            <span>Connecting to ICP...</span>
          </div>
        {/if}
      </div>
    </div>
  </header>

  <!-- Main Content Area: 61.8% + 38.2% split -->
  <div class="main-container">
    <!-- Navigation Sidebar: 38.2% -->
    <nav class="module-navigation">
      <div class="nav-title">System Modules</div>
      {#each modules as module}
        <button
          class="module-button {currentModule === module.id ? 'active' : ''}"
          class:active={currentModule === module.id}
          on:click={() => selectModule(module.id)}
        >
          <div class="module-icon">{module.icon}</div>
          <div class="module-info">
            <div class="module-name">{module.name}</div>
            <div class="module-desc">{module.description}</div>
          </div>
          <div class="module-gradient bg-gradient-to-r {module.color}"></div>
        </button>
      {/each}
    </nav>

    <!-- Primary Content: 61.8% -->
    <section class="content-area">
      {#if currentModule === 'overview'}
        <div class="overview-dashboard">
          <h2 class="section-title">Civilization Status</h2>
          
          <div class="metrics-grid">
            <div class="metric-card">
              <div class="metric-value">7</div>
              <div class="metric-label">Active Modules</div>
              <div class="metric-icon">🏗️</div>
            </div>
            
            <div class="metric-card">
              <div class="metric-value">∞</div>
              <div class="metric-label">Possibilities</div>
              <div class="metric-icon">🚀</div>
            </div>
            
            <div class="metric-card">
              <div class="metric-value">ICP</div>
              <div class="metric-label">Network</div>
              <div class="metric-icon">🌐</div>
            </div>
          </div>

          <div class="philosophy-section">
            <blockquote class="manifesto">
              "We are not optimizing for profit. We are optimizing for life, trust, and legacy."
            </blockquote>
            <p class="manifesto-detail">
              AxiaSystem is the nervous system of a sovereign civilization, designed to scale 
              from individuals to entire cities, cultures, and economies.
            </p>
          </div>
        </div>
      
      {:else if currentModule === 'admin'}
        <div class="admin-panel">
          <h2 class="section-title">⚡ AxiaAdmin - System Command Center</h2>
          <p class="module-intro">Comprehensive administrative oversight and control</p>
          
          <div class="admin-tabs">
            <button 
              class="tab-button {activeAdminTab === 'dashboard' ? 'active' : ''}" 
              on:click={() => activeAdminTab = 'dashboard'}
            >
              Dashboard
            </button>
            <button 
              class="tab-button {activeAdminTab === 'insights' ? 'active' : ''}" 
              on:click={() => activeAdminTab = 'insights'}
            >
              🧠 NamoraAI Insights
            </button>
            <button 
              class="tab-button {activeAdminTab === 'users' ? 'active' : ''}" 
              on:click={() => activeAdminTab = 'users'}
            >
              User Management
            </button>
            <button 
              class="tab-button {activeAdminTab === 'system' ? 'active' : ''}" 
              on:click={() => activeAdminTab = 'system'}
            >
              System Health
            </button>
            <button 
              class="tab-button {activeAdminTab === 'logs' ? 'active' : ''}" 
              on:click={() => activeAdminTab = 'logs'}
            >
              Activity Logs
            </button>
          </div>

          {#if activeAdminTab === 'dashboard'}
            <div class="admin-dashboard">
              <div class="admin-metrics-grid">
                <div class="admin-metric-card">
                  <div class="admin-metric-value">{adminData.totalUsers}</div>
                  <div class="admin-metric-label">Total Users</div>
                  <div class="admin-metric-change">+12 today</div>
                </div>
                <div class="admin-metric-card">
                  <div class="admin-metric-value">{adminData.activeProjects}</div>
                  <div class="admin-metric-label">Active Projects</div>
                  <div class="admin-metric-change">+3 this week</div>
                </div>
                <div class="admin-metric-card">
                  <div class="admin-metric-value">{adminData.systemHealth}</div>
                  <div class="admin-metric-label">System Health</div>
                  <div class="admin-metric-change">All operational</div>
                </div>
                <div class="admin-metric-card">
                  <div class="admin-metric-value">{adminData.queueLength}</div>
                  <div class="admin-metric-label">Queue Length</div>
                  <div class="admin-metric-change">Real-time</div>
                </div>
              </div>

              <div class="admin-overview-grid">
                <div class="admin-section">
                  <h3 class="admin-section-title">Recent Admin Actions</h3>
                  <div class="admin-log-list">
                    {#each adminData.recentActions as action}
                      <div class="admin-log-item">
                        <div class="log-time">{action.timestamp}</div>
                        <div class="log-action">{action.action}</div>
                        <div class="log-admin">{action.admin}</div>
                      </div>
                    {/each}
                  </div>
                </div>

                <div class="admin-section">
                  <h3 class="admin-section-title">System Status</h3>
                  <div class="system-status-grid">
                    <div class="status-item">
                      <span class="status-dot green"></span>
                      <span>Identity Service</span>
                    </div>
                    <div class="status-item">
                      <span class="status-dot green"></span>
                      <span>Payment Engine</span>
                    </div>
                    <div class="status-item">
                      <span class="status-dot green"></span>
                      <span>Asset Registry</span>
                    </div>
                    <div class="status-item">
                      <span class="status-dot yellow"></span>
                      <span>XRPL Bridge</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

          {:else if activeAdminTab === 'insights'}
            <NamoraInsights />

          {:else if activeAdminTab === 'users'}
            <div class="user-management">
              <div class="admin-controls">
                <input 
                  type="text" 
                  placeholder="Search users..." 
                  class="admin-search"
                  bind:value={userSearchQuery}
                />
                <button class="admin-button primary">Refresh Data</button>
              </div>

              <div class="user-table">
                <div class="user-table-header">
                  <div>Identity</div>
                  <div>Registration</div>
                  <div>Projects</div>
                  <div>Status</div>
                  <div>Actions</div>
                </div>
                {#each adminData.users as user}
                  <div class="user-table-row">
                    <div class="user-identity">
                      <div class="user-principal">{user.principal.slice(0, 12)}...</div>
                      <div class="user-name">{user.name || 'Anonymous'}</div>
                    </div>
                    <div class="user-date">{user.registrationDate}</div>
                    <div class="user-projects">{user.projectCount}</div>
                    <div class="user-status">
                      <span class="status-badge {user.isActive ? 'active' : 'inactive'}">
                        {user.isActive ? 'Active' : 'Inactive'}
                      </span>
                    </div>
                    <div class="user-actions">
                      <button class="action-btn view">View</button>
                      <button class="action-btn audit">Audit</button>
                    </div>
                  </div>
                {/each}
              </div>
            </div>

          {:else if activeAdminTab === 'system'}
            <div class="system-health">
              <div class="health-overview-grid">
                <div class="health-card">
                  <h4 class="health-title">Canister Health</h4>
                  <div class="health-indicators">
                    <div class="health-item">
                      <span class="health-dot green"></span>
                      <span>Backend: Healthy</span>
                    </div>
                    <div class="health-item">
                      <span class="health-dot green"></span>
                      <span>Admin: Operational</span>
                    </div>
                    <div class="health-item">
                      <span class="health-dot green"></span>
                      <span>Identity: Running</span>
                    </div>
                    <div class="health-item">
                      <span class="health-dot yellow"></span>
                      <span>Bridge: Monitoring</span>
                    </div>
                  </div>
                </div>

                <div class="health-card">
                  <h4 class="health-title">Resource Usage</h4>
                  <div class="resource-usage">
                    <div class="resource-item">
                      <span>Memory Usage</span>
                      <div class="resource-bar">
                        <div class="resource-fill" style="width: 45%"></div>
                      </div>
                      <span>45%</span>
                    </div>
                    <div class="resource-item">
                      <span>Cycle Balance</span>
                      <div class="resource-bar">
                        <div class="resource-fill" style="width: 72%"></div>
                      </div>
                      <span>72%</span>
                    </div>
                  </div>
                </div>
              </div>

              <div class="maintenance-section">
                <h3 class="admin-section-title">System Maintenance</h3>
                <div class="maintenance-grid">
                  <button class="maintenance-btn">Process Escrow Timeouts</button>
                  <button class="maintenance-btn">Retry Failed Payments</button>
                  <button class="maintenance-btn">Clean Temp Data</button>
                  <button class="maintenance-btn">Generate Health Report</button>
                </div>
              </div>
            </div>

          {:else if activeAdminTab === 'logs'}
            <div class="activity-logs">
              <div class="log-controls">
                <select class="log-filter">
                  <option>All Activities</option>
                  <option>User Actions</option>
                  <option>System Events</option>
                  <option>Admin Actions</option>
                </select>
                <input type="date" class="log-date" />
                <button class="admin-button secondary">Export Logs</button>
              </div>

              <div class="log-table">
                <div class="log-table-header">
                  <div>Timestamp</div>
                  <div>Action</div>
                  <div>Actor</div>
                  <div>Details</div>
                  <div>Status</div>
                </div>
                {#each adminData.activityLogs as log}
                  <div class="log-table-row">
                    <div class="log-timestamp">{log.timestamp}</div>
                    <div class="log-action-type">{log.action}</div>
                    <div class="log-actor">{log.actor}</div>
                    <div class="log-details">{log.details}</div>
                    <div class="log-status">
                      <span class="status-badge {log.success ? 'success' : 'error'}">
                        {log.success ? 'Success' : 'Error'}
                      </span>
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>
      
      {:else if currentModule === 'identity'}
        <div class="module-content">
          <h2 class="section-title">🔐 AxiaIdentity</h2>
          <p class="module-intro">Self-sovereign identity with cryptographic proof</p>
          
          <div class="identity-actions">
            <button class="action-button primary">Create Identity</button>
            <button class="action-button secondary">Verify Credentials</button>
            <button class="action-button secondary">Manage Permissions</button>
          </div>
        </div>

      {:else if currentModule === 'assets'}
        <div class="module-content">
          <h2 class="section-title">💎 AxiaAsset</h2>
          <p class="module-intro">Bridge physical and digital asset worlds</p>
          
          <div class="asset-grid">
            <div class="asset-placeholder">
              <div class="asset-icon">🏠</div>
              <div class="asset-type">Real Estate</div>
            </div>
            <div class="asset-placeholder">
              <div class="asset-icon">🎨</div>
              <div class="asset-type">Digital Art</div>
            </div>
            <div class="asset-placeholder">
              <div class="asset-icon">⚡</div>
              <div class="asset-type">Energy Rights</div>
            </div>
          </div>
        </div>

      {:else if currentModule === 'wallet'}
        <div class="module-content">
          <h2 class="section-title">👛 AxiaWallet</h2>
          <p class="module-intro">Programmable multi-chain wallet with social delegation</p>
          
          <div class="wallet-overview">
            <div class="balance-card">
              <div class="balance-amount">0.00 ICP</div>
              <div class="balance-label">Available Balance</div>
            </div>
          </div>
        </div>

      {:else if currentModule === 'payment'}
        <div class="module-content">
          <h2 class="section-title">💰 AxiaPayment</h2>
          <p class="module-intro">Cross-dimensional value transfer system</p>
          
          <div class="payment-interface">
            <button class="action-button primary large">Send Payment</button>
            <button class="action-button secondary large">Request Payment</button>
          </div>
        </div>

      {:else if currentModule === 'governance'}
        <div class="module-content">
          <h2 class="section-title">🗳️ AxiaGovernance</h2>
          <p class="module-intro">Generalized governance for decentralized action</p>
          
          <div class="governance-panel">
            <div class="proposal-stats">
              <div class="stat">
                <div class="stat-number">0</div>
                <div class="stat-label">Active Proposals</div>
              </div>
              <div class="stat">
                <div class="stat-number">∞</div>
                <div class="stat-label">Voting Power</div>
              </div>
            </div>
          </div>
        </div>

      {:else if currentModule === 'bridge'}
        <div class="module-content">
          <h2 class="section-title">🌉 AxiaBridge</h2>
          <p class="module-intro">Connect to XRPL and external blockchain networks</p>
          
          <div class="bridge-status">
            <div class="bridge-connection">
              <div class="connection-indicator offline"></div>
              <span>XRPL Bridge: Offline</span>
            </div>
          </div>
        </div>
      {/if}
    </section>
  </div>

  <!-- Footer: 10.1% -->
  <footer class="civilization-footer">
    <div class="footer-content">
      <div class="build-info">
        <span>Genesis Framework</span>
        <span class="separator">•</span>
        <span>Internet Computer Protocol</span>
        <span class="separator">•</span>
        <span>Built with Svelte</span>
      </div>
      <div class="version-info">v0.1.0-genesis</div>
    </div>
  </footer>
</main>

<style>
  /* Golden Ratio CSS Variables */
  :root {
    --phi: 1.618;
    --phi-inv: 0.618;
    --phi-sq: 0.382;
    --phi-third: 0.236;
    --phi-fourth: 0.152;
    --phi-fifth: 0.101;
    
    /* Sovereign Color Palette */
    --primary-dark: #0a0b1e;
    --primary-medium: #1a1b3e;
    --primary-light: #2a2b5e;
    --accent-gold: #f7d794;
    --accent-silver: #c8d6e5;
    --success: #10b981;
    --warning: #f59e0b;
    --danger: #ef4444;
  }

  .civilization-framework {
    min-height: 100vh;
    background: linear-gradient(135deg, var(--primary-dark) 0%, var(--primary-medium) 100%);
    color: white;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
    display: flex;
    flex-direction: column;
  }

  /* Header: 15.2% of viewport */
  .sovereign-header {
    height: calc(var(--phi-fourth) * 100vh);
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    display: flex;
    align-items: center;
  }

  .header-content {
    width: 100%;
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .civilization-title {
    font-size: 2.5rem;
    font-weight: 800;
    margin: 0;
    background: linear-gradient(45deg, var(--accent-gold), var(--accent-silver));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  .subtitle {
    margin: 0;
    color: var(--accent-silver);
    font-size: 0.9rem;
    opacity: 0.8;
  }

  .connection-status {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .connected {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background: rgba(16, 185, 129, 0.2);
    padding: 0.5rem 1rem;
    border-radius: 50px;
    border: 1px solid var(--success);
  }

  .status-indicator {
    width: 8px;
    height: 8px;
    background: var(--success);
    border-radius: 50%;
    animation: pulse 2s infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }

  .principal-id {
    font-family: monospace;
    font-size: 0.8rem;
  }

  /* Main Container */
  .main-container {
    flex: 1;
    display: flex;
    max-width: 1200px;
    margin: 0 auto;
    width: 100%;
    gap: 2rem;
    padding: 2rem;
  }

  /* Navigation: 38.2% */
  .module-navigation {
    width: calc(var(--phi-sq) * 100%);
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .nav-title {
    font-size: 1.2rem;
    font-weight: 600;
    color: var(--accent-gold);
    margin-bottom: 1rem;
    padding: 0 1rem;
  }

  .module-button {
    position: relative;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    padding: 1.5rem;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    gap: 1rem;
    text-align: left;
    overflow: hidden;
  }

  .module-button:hover {
    background: rgba(255, 255, 255, 0.1);
    transform: translateY(-2px);
  }

  .module-button.active {
    background: rgba(255, 255, 255, 0.15);
    border-color: var(--accent-gold);
  }

  .module-icon {
    font-size: 2rem;
    z-index: 2;
  }

  .module-info {
    flex: 1;
    z-index: 2;
  }

  .module-name {
    font-weight: 600;
    margin-bottom: 0.25rem;
  }

  .module-desc {
    font-size: 0.8rem;
    opacity: 0.7;
  }

  .module-gradient {
    position: absolute;
    top: 0;
    right: 0;
    width: 4px;
    height: 100%;
    opacity: 0.7;
  }

  /* Content Area: 61.8% */
  .content-area {
    width: calc(var(--phi-inv) * 100%);
    background: rgba(255, 255, 255, 0.03);
    border-radius: 16px;
    padding: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .section-title {
    font-size: 2rem;
    font-weight: 700;
    margin: 0 0 1rem 0;
    color: var(--accent-gold);
  }

  .module-intro {
    color: var(--accent-silver);
    margin-bottom: 2rem;
    font-size: 1.1rem;
  }

  /* Overview Dashboard */
  .metrics-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1.5rem;
    margin-bottom: 3rem;
  }

  .metric-card {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 2rem;
    text-align: center;
    border: 1px solid rgba(255, 255, 255, 0.1);
    position: relative;
  }

  .metric-value {
    font-size: 2.5rem;
    font-weight: 800;
    color: var(--accent-gold);
    margin-bottom: 0.5rem;
  }

  .metric-label {
    color: var(--accent-silver);
    font-size: 0.9rem;
  }

  .metric-icon {
    position: absolute;
    top: 1rem;
    right: 1rem;
    font-size: 1.5rem;
    opacity: 0.3;
  }

  .philosophy-section {
    background: linear-gradient(135deg, rgba(247, 215, 148, 0.1), rgba(200, 214, 229, 0.1));
    border-radius: 16px;
    padding: 2rem;
    border: 1px solid rgba(247, 215, 148, 0.2);
  }

  .manifesto {
    font-size: 1.3rem;
    font-style: italic;
    color: var(--accent-gold);
    margin: 0 0 1rem 0;
    text-align: center;
  }

  .manifesto-detail {
    color: var(--accent-silver);
    line-height: 1.6;
    margin: 0;
  }

  /* Action Buttons */
  .action-button {
    padding: 1rem 2rem;
    border-radius: 8px;
    border: none;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    margin-right: 1rem;
  }

  .action-button.primary {
    background: linear-gradient(45deg, var(--accent-gold), #f39c12);
    color: var(--primary-dark);
  }

  .action-button.secondary {
    background: rgba(255, 255, 255, 0.1);
    color: white;
    border: 1px solid rgba(255, 255, 255, 0.3);
  }

  .action-button.large {
    padding: 1.5rem 3rem;
    font-size: 1.1rem;
  }

  .action-button:hover {
    transform: translateY(-2px);
  }

  /* Footer: 10.1% */
  .civilization-footer {
    height: calc(var(--phi-fifth) * 100vh);
    background: rgba(0, 0, 0, 0.3);
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .footer-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    max-width: 1200px;
    padding: 0 2rem;
  }

  .build-info {
    display: flex;
    gap: 1rem;
    color: var(--accent-silver);
    opacity: 0.7;
    font-size: 0.9rem;
  }

  .separator {
    opacity: 0.5;
  }

  .version-info {
    font-family: monospace;
    color: var(--accent-gold);
    font-size: 0.8rem;
  }

  /* Loading Animation */
  .loading-spinner {
    width: 16px;
    height: 16px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top: 2px solid white;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  /* Module-specific styles */
  .identity-actions, .payment-interface {
    display: flex;
    gap: 1rem;
    margin-top: 2rem;
  }

  .asset-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1.5rem;
    margin-top: 2rem;
  }

  .asset-placeholder {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 2rem;
    text-align: center;
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .asset-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  .asset-type {
    color: var(--accent-silver);
  }

  .wallet-overview {
    margin-top: 2rem;
  }

  .balance-card {
    background: rgba(16, 185, 129, 0.1);
    border: 1px solid var(--success);
    border-radius: 12px;
    padding: 2rem;
    text-align: center;
  }

  .balance-amount {
    font-size: 2.5rem;
    font-weight: 800;
    color: var(--success);
    margin-bottom: 0.5rem;
  }

  .balance-label {
    color: var(--accent-silver);
  }

  .governance-panel {
    margin-top: 2rem;
  }

  .proposal-stats {
    display: flex;
    gap: 2rem;
  }

  .stat {
    text-align: center;
  }

  .stat-number {
    font-size: 2rem;
    font-weight: 800;
    color: var(--accent-gold);
  }

  .stat-label {
    color: var(--accent-silver);
    font-size: 0.9rem;
  }

  .bridge-status {
    margin-top: 2rem;
  }

  .bridge-connection {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem;
    background: rgba(239, 68, 68, 0.1);
    border: 1px solid var(--danger);
    border-radius: 8px;
  }

  .connection-indicator {
    width: 12px;
    height: 12px;
    border-radius: 50%;
  }

  .connection-indicator.offline {
    background: var(--danger);
  }

  /* Admin Panel Styles */
  .admin-panel {
    width: 100%;
  }

  .admin-tabs {
    display: flex;
    gap: 1rem;
    margin: 2rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  }

  .tab-button {
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.7);
    padding: 1rem 1.5rem;
    cursor: pointer;
    border-radius: 8px 8px 0 0;
    transition: all 0.3s ease;
    font-weight: 500;
  }

  .tab-button:hover {
    color: white;
    background: rgba(255, 255, 255, 0.05);
  }

  .tab-button.active {
    color: var(--accent-gold);
    background: rgba(247, 215, 148, 0.1);
    border-bottom: 2px solid var(--accent-gold);
  }

  .admin-metrics-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1.5rem;
    margin: 2rem 0;
  }

  .admin-metric-card {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    padding: 1.5rem;
    text-align: center;
  }

  .admin-metric-value {
    font-size: 2.5rem;
    font-weight: bold;
    color: var(--accent-gold);
    margin-bottom: 0.5rem;
  }

  .admin-metric-label {
    font-weight: 500;
    margin-bottom: 0.5rem;
  }

  .admin-metric-change {
    font-size: 0.8rem;
    color: var(--success);
  }

  .admin-overview-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
    margin-top: 2rem;
  }

  .admin-section {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 1.5rem;
  }

  .admin-section-title {
    font-size: 1.1rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: var(--accent-gold);
  }

  .admin-log-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .admin-log-item {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    padding: 1rem;
    font-size: 0.9rem;
  }

  .log-time {
    color: var(--accent-silver);
    font-size: 0.8rem;
    margin-bottom: 0.25rem;
  }

  .log-action {
    font-weight: 500;
    margin-bottom: 0.25rem;
  }

  .log-admin {
    color: var(--accent-gold);
    font-size: 0.8rem;
  }

  .system-status-grid {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .status-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
  }

  .status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
  }

  .status-dot.green {
    background: var(--success);
  }

  .status-dot.yellow {
    background: var(--warning);
  }

  .status-dot.red {
    background: var(--danger);
  }

  /* User Management */
  .admin-controls {
    display: flex;
    gap: 1rem;
    margin: 2rem 0;
    align-items: center;
  }

  .admin-search {
    flex: 1;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 0.75rem 1rem;
    color: white;
    font-size: 0.9rem;
  }

  .admin-search::placeholder {
    color: rgba(255, 255, 255, 0.5);
  }

  .admin-button {
    background: linear-gradient(135deg, var(--accent-gold), #f39c12);
    border: none;
    border-radius: 8px;
    padding: 0.75rem 1.5rem;
    color: var(--primary-dark);
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
  }

  .admin-button:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(247, 215, 148, 0.3);
  }

  .admin-button.secondary {
    background: rgba(255, 255, 255, 0.1);
    color: white;
  }

  .user-table {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    overflow: hidden;
  }

  .user-table-header {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr 1fr 1fr;
    gap: 1rem;
    background: rgba(255, 255, 255, 0.1);
    padding: 1rem;
    font-weight: 600;
    color: var(--accent-gold);
  }

  .user-table-row {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr 1fr 1fr;
    gap: 1rem;
    padding: 1rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    align-items: center;
  }

  .user-table-row:last-child {
    border-bottom: none;
  }

  .user-identity {
    display: flex;
    flex-direction: column;
  }

  .user-principal {
    font-family: monospace;
    font-size: 0.8rem;
    color: var(--accent-silver);
  }

  .user-name {
    font-weight: 500;
    margin-top: 0.25rem;
  }

  .status-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 12px;
    font-size: 0.8rem;
    font-weight: 500;
  }

  .status-badge.active {
    background: rgba(16, 185, 129, 0.2);
    color: var(--success);
  }

  .status-badge.inactive {
    background: rgba(239, 68, 68, 0.2);
    color: var(--danger);
  }

  .status-badge.success {
    background: rgba(16, 185, 129, 0.2);
    color: var(--success);
  }

  .status-badge.error {
    background: rgba(239, 68, 68, 0.2);
    color: var(--danger);
  }

  .user-actions {
    display: flex;
    gap: 0.5rem;
  }

  .action-btn {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 6px;
    padding: 0.5rem 1rem;
    color: white;
    font-size: 0.8rem;
    cursor: pointer;
    transition: all 0.3s ease;
  }

  .action-btn:hover {
    background: rgba(255, 255, 255, 0.2);
  }

  /* System Health */
  .health-overview-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
    margin: 2rem 0;
  }

  .health-card {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 1.5rem;
  }

  .health-title {
    font-size: 1.1rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: var(--accent-gold);
  }

  .health-indicators {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .health-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
  }

  .health-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
  }

  .health-dot.green {
    background: var(--success);
  }

  .health-dot.yellow {
    background: var(--warning);
  }

  .resource-usage {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .resource-item {
    display: grid;
    grid-template-columns: 1fr 2fr auto;
    gap: 1rem;
    align-items: center;
  }

  .resource-bar {
    background: rgba(255, 255, 255, 0.1);
    height: 8px;
    border-radius: 4px;
    overflow: hidden;
  }

  .resource-fill {
    background: linear-gradient(90deg, var(--success), var(--warning));
    height: 100%;
    border-radius: 4px;
    transition: width 0.3s ease;
  }

  .maintenance-section {
    margin-top: 2rem;
  }

  .maintenance-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
  }

  .maintenance-btn {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 1rem;
    color: white;
    cursor: pointer;
    transition: all 0.3s ease;
  }

  .maintenance-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    transform: translateY(-1px);
  }

  /* Activity Logs */
  .log-controls {
    display: flex;
    gap: 1rem;
    margin: 2rem 0;
    align-items: center;
  }

  .log-filter, .log-date {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 0.75rem;
    color: white;
    font-size: 0.9rem;
  }

  .log-table {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    overflow: hidden;
  }

  .log-table-header {
    display: grid;
    grid-template-columns: 1.5fr 1fr 1fr 2fr 1fr;
    gap: 1rem;
    background: rgba(255, 255, 255, 0.1);
    padding: 1rem;
    font-weight: 600;
    color: var(--accent-gold);
  }

  .log-table-row {
    display: grid;
    grid-template-columns: 1.5fr 1fr 1fr 2fr 1fr;
    gap: 1rem;
    padding: 1rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    align-items: center;
    font-size: 0.9rem;
  }

  .log-table-row:last-child {
    border-bottom: none;
  }

  .log-timestamp {
    font-family: monospace;
    color: var(--accent-silver);
    font-size: 0.8rem;
  }

  .log-action-type {
    font-weight: 500;
  }

  .log-actor {
    font-family: monospace;
    color: var(--accent-gold);
    font-size: 0.8rem;
  }

  .log-details {
    color: rgba(255, 255, 255, 0.8);
  }

  /* Responsive Design for Admin */
  @media (max-width: 768px) {
    .admin-overview-grid,
    .health-overview-grid {
      grid-template-columns: 1fr;
    }

    .user-table-header,
    .user-table-row {
      grid-template-columns: 1fr;
      gap: 0.5rem;
    }

    .log-table-header,
    .log-table-row {
      grid-template-columns: 1fr;
      gap: 0.5rem;
    }

    .admin-controls {
      flex-direction: column;
    }

    .admin-tabs {
      flex-wrap: wrap;
    }
  }
</style>

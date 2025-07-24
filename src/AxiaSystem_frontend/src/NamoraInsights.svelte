<!-- 🧠 NamoraAI Insights Component - System-Wide Observability Dashboard -->
<script>
  import { onMount } from 'svelte';
  
  // Mock data - will be replaced with actual canister calls
  let insights = [];
  let filteredInsights = [];
  let loading = true;
  let error = null;
  
  // Filter options
  let selectedSeverity = 'all';
  let selectedSource = 'all';
  let searchTerm = '';
  
  // Statistics
  let stats = {
    total: 0,
    errors: 0,
    warnings: 0,
    info: 0,
    activeModules: []
  };

  // Severity filter options
  const severityOptions = [
    { value: 'all', label: 'All Severities', color: 'bg-gray-500' },
    { value: 'error', label: 'Errors', color: 'bg-red-500' },
    { value: 'warning', label: 'Warnings', color: 'bg-yellow-500' },
    { value: 'info', label: 'Info', color: 'bg-blue-500' }
  ];

  // Source filter options
  const sourceOptions = [
    { value: 'all', label: 'All Modules' },
    { value: 'user', label: 'User Management' },
    { value: 'wallet', label: 'Wallet System' },
    { value: 'payment', label: 'Payment Engine' },
    { value: 'escrow', label: 'Escrow Service' },
    { value: 'identity', label: 'Identity Service' },
    { value: 'governance', label: 'Governance' },
    { value: 'asset', label: 'Asset Registry' },
    { value: 'namora_ai', label: 'NamoraAI' }
  ];

  // Mock insights data
  const mockInsights = [
    {
      source: 'user',
      severity: 'info',
      message: 'User successfully created with ID: abc123..., username: alice_builder',
      timestamp: Date.now() * 1000000 - 3600000000000,
      id: 1
    },
    {
      source: 'wallet',
      severity: 'warning',
      message: 'Low balance detected for owner: def456... - current balance: 42',
      timestamp: Date.now() * 1000000 - 1800000000000,
      id: 2
    },
    {
      source: 'payment',
      severity: 'info',
      message: 'Payment successfully initiated - Transaction ID: 789, Amount: 1000',
      timestamp: Date.now() * 1000000 - 900000000000,
      id: 3
    },
    {
      source: 'escrow',
      severity: 'error',
      message: 'Escrow creation failed: Insufficient balance for escrow amount',
      timestamp: Date.now() * 1000000 - 600000000000,
      id: 4
    },
    {
      source: 'governance',
      severity: 'info',
      message: 'Governance proposal #12 successfully created by ghi789...',
      timestamp: Date.now() * 1000000 - 300000000000,
      id: 5
    },
    {
      source: 'identity',
      severity: 'warning',
      message: 'Identity creation failed for user: jkl012... - Invalid metadata format',
      timestamp: Date.now() * 1000000 - 150000000000,
      id: 6
    },
    {
      source: 'wallet',
      severity: 'info',
      message: 'Balance successfully updated for owner: mno345..., new balance: 2500',
      timestamp: Date.now() * 1000000 - 60000000000,
      id: 7
    },
    {
      source: 'governance',
      severity: 'warning',
      message: 'High event queue length detected: 150 events pending',
      timestamp: Date.now() * 1000000 - 30000000000,
      id: 8
    }
  ];

  function loadInsights() {
    loading = true;
    
    // Simulate API call delay
    setTimeout(() => {
      insights = mockInsights;
      updateStats();
      filterInsights();
      loading = false;
    }, 1000);
  }

  function updateStats() {
    stats.total = insights.length;
    stats.errors = insights.filter(i => i.severity === 'error').length;
    stats.warnings = insights.filter(i => i.severity === 'warning').length;
    stats.info = insights.filter(i => i.severity === 'info').length;
    stats.activeModules = [...new Set(insights.map(i => i.source))];
  }

  function filterInsights() {
    filteredInsights = insights.filter(insight => {
      const matchesSeverity = selectedSeverity === 'all' || insight.severity === selectedSeverity;
      const matchesSource = selectedSource === 'all' || insight.source === selectedSource;
      const matchesSearch = searchTerm === '' || 
        insight.message.toLowerCase().includes(searchTerm.toLowerCase()) ||
        insight.source.toLowerCase().includes(searchTerm.toLowerCase());
      
      return matchesSeverity && matchesSource && matchesSearch;
    });
  }

  function formatTimestamp(timestamp) {
    const date = new Date(timestamp / 1000000); // Convert from nanoseconds
    return date.toLocaleString();
  }

  function getSeverityColor(severity) {
    switch (severity) {
      case 'error': return 'text-red-400 bg-red-900/20 border-red-500/30';
      case 'warning': return 'text-yellow-400 bg-yellow-900/20 border-yellow-500/30';
      case 'info': return 'text-blue-400 bg-blue-900/20 border-blue-500/30';
      default: return 'text-gray-400 bg-gray-900/20 border-gray-500/30';
    }
  }

  function getSourceIcon(source) {
    const icons = {
      user: '👤',
      wallet: '👛',
      payment: '💰',
      escrow: '🔒',
      identity: '🔐',
      governance: '🗳️',
      asset: '💎',
      namora_ai: '🧠'
    };
    return icons[source] || '⚡';
  }

  function clearAllInsights() {
    if (confirm('Are you sure you want to clear all insights? This action cannot be undone.')) {
      insights = [];
      filteredInsights = [];
      updateStats();
    }
  }

  // Reactive statements
  $: if (selectedSeverity || selectedSource || searchTerm) {
    filterInsights();
  }

  onMount(() => {
    loadInsights();
    
    // Auto-refresh every 30 seconds
    const interval = setInterval(loadInsights, 30000);
    
    return () => clearInterval(interval);
  });
</script>

<div class="namora-insights">
  <div class="insights-header">
    <div class="header-content">
      <div class="title-section">
        <h2 class="insights-title">🧠 NamoraAI System Insights</h2>
        <p class="insights-subtitle">Real-time observability across all system modules</p>
      </div>
      
      <div class="header-actions">
        <button class="refresh-btn" on:click={loadInsights} disabled={loading}>
          <span class="refresh-icon" class:spinning={loading}>🔄</span>
          Refresh
        </button>
        <button class="clear-btn" on:click={clearAllInsights}>
          🧹 Clear All
        </button>
      </div>
    </div>
  </div>

  <!-- Statistics Dashboard -->
  <div class="stats-grid">
    <div class="stat-card total">
      <div class="stat-value">{stats.total}</div>
      <div class="stat-label">Total Insights</div>
    </div>
    <div class="stat-card errors">
      <div class="stat-value">{stats.errors}</div>
      <div class="stat-label">Errors</div>
    </div>
    <div class="stat-card warnings">
      <div class="stat-value">{stats.warnings}</div>
      <div class="stat-label">Warnings</div>
    </div>
    <div class="stat-card info">
      <div class="stat-value">{stats.info}</div>
      <div class="stat-label">Info</div>
    </div>
    <div class="stat-card modules">
      <div class="stat-value">{stats.activeModules.length}</div>
      <div class="stat-label">Active Modules</div>
    </div>
  </div>

  <!-- Filters -->
  <div class="filters-section">
    <div class="filter-group">
      <label for="severity-filter">Severity:</label>
      <select id="severity-filter" bind:value={selectedSeverity} class="filter-select">
        {#each severityOptions as option}
          <option value={option.value}>{option.label}</option>
        {/each}
      </select>
    </div>

    <div class="filter-group">
      <label for="source-filter">Module:</label>
      <select id="source-filter" bind:value={selectedSource} class="filter-select">
        {#each sourceOptions as option}
          <option value={option.value}>{option.label}</option>
        {/each}
      </select>
    </div>

    <div class="filter-group search-group">
      <label for="search-input">Search:</label>
      <input 
        id="search-input"
        type="text" 
        bind:value={searchTerm} 
        placeholder="Search insights..." 
        class="search-input"
      />
    </div>
  </div>

  <!-- Insights List -->
  <div class="insights-container">
    {#if loading}
      <div class="loading-state">
        <div class="loading-spinner"></div>
        <p>Loading system insights...</p>
      </div>
    {:else if error}
      <div class="error-state">
        <p>Error loading insights: {error}</p>
        <button on:click={loadInsights}>Try Again</button>
      </div>
    {:else if filteredInsights.length === 0}
      <div class="empty-state">
        <div class="empty-icon">🔍</div>
        <p>No insights match your current filters</p>
        <button on:click={() => { selectedSeverity = 'all'; selectedSource = 'all'; searchTerm = ''; }}>
          Clear Filters
        </button>
      </div>
    {:else}
      <div class="insights-list">
        {#each filteredInsights as insight (insight.id)}
          <div class="insight-card {getSeverityColor(insight.severity)}">
            <div class="insight-header">
              <div class="insight-source">
                <span class="source-icon">{getSourceIcon(insight.source)}</span>
                <span class="source-name">{insight.source}</span>
              </div>
              <div class="insight-timestamp">
                {formatTimestamp(insight.timestamp)}
              </div>
            </div>
            <div class="insight-message">
              {insight.message}
            </div>
            <div class="insight-footer">
              <span class="severity-badge {insight.severity}">
                {insight.severity.toUpperCase()}
              </span>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>

<style>
  .namora-insights {
    padding: 2rem;
    max-width: 1400px;
    margin: 0 auto;
    background: linear-gradient(135deg, #0a0b1e 0%, #1a1b3e 100%);
    color: white;
    border-radius: 12px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
  }

  .insights-header {
    margin-bottom: 2rem;
  }

  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 2rem;
  }

  .insights-title {
    font-size: 2rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
    background: linear-gradient(135deg, #f7d794, #f39c12);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  .insights-subtitle {
    color: rgba(255, 255, 255, 0.7);
    font-size: 1.1rem;
  }

  .header-actions {
    display: flex;
    gap: 1rem;
  }

  .refresh-btn, .clear-btn {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: white;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .refresh-btn:hover, .clear-btn:hover {
    background: rgba(255, 255, 255, 0.2);
    transform: translateY(-1px);
  }

  .refresh-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .refresh-icon.spinning {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1.5rem;
    margin-bottom: 2rem;
  }

  .stat-card {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    padding: 1.5rem;
    text-align: center;
    transition: all 0.3s ease;
  }

  .stat-card:hover {
    background: rgba(255, 255, 255, 0.1);
    transform: translateY(-2px);
  }

  .stat-value {
    font-size: 2.5rem;
    font-weight: bold;
    margin-bottom: 0.5rem;
  }

  .stat-card.total .stat-value { color: #f7d794; }
  .stat-card.errors .stat-value { color: #ef4444; }
  .stat-card.warnings .stat-value { color: #f59e0b; }
  .stat-card.info .stat-value { color: #3b82f6; }
  .stat-card.modules .stat-value { color: #10b981; }

  .stat-label {
    color: rgba(255, 255, 255, 0.7);
    font-weight: 500;
  }

  .filters-section {
    display: flex;
    gap: 2rem;
    margin-bottom: 2rem;
    padding: 1.5rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    flex-wrap: wrap;
  }

  .filter-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .search-group {
    flex: 1;
    min-width: 200px;
  }

  .filter-group label {
    font-weight: 600;
    color: #f7d794;
    white-space: nowrap;
  }

  .filter-select, .search-input {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 6px;
    padding: 0.5rem 1rem;
    color: white;
    font-size: 0.9rem;
  }

  .search-input {
    flex: 1;
  }

  .filter-select:focus, .search-input:focus {
    outline: none;
    border-color: #f7d794;
    background: rgba(255, 255, 255, 0.15);
  }

  .insights-container {
    min-height: 400px;
  }

  .loading-state, .error-state, .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem 2rem;
    text-align: center;
  }

  .loading-spinner {
    width: 40px;
    height: 40px;
    border: 3px solid rgba(255, 255, 255, 0.1);
    border-top: 3px solid #f7d794;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 1rem;
  }

  .empty-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
    opacity: 0.6;
  }

  .insights-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .insight-card {
    border: 1px solid;
    border-radius: 12px;
    padding: 1.5rem;
    transition: all 0.3s ease;
  }

  .insight-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
  }

  .insight-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .insight-source {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .source-icon {
    font-size: 1.5rem;
  }

  .source-name {
    font-weight: 600;
    text-transform: capitalize;
  }

  .insight-timestamp {
    font-size: 0.8rem;
    color: rgba(255, 255, 255, 0.6);
    font-family: monospace;
  }

  .insight-message {
    font-size: 1rem;
    line-height: 1.5;
    margin-bottom: 1rem;
    color: rgba(255, 255, 255, 0.9);
  }

  .insight-footer {
    display: flex;
    justify-content: flex-end;
  }

  .severity-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 12px;
    font-size: 0.7rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .severity-badge.error {
    background: rgba(239, 68, 68, 0.2);
    color: #fca5a5;
  }

  .severity-badge.warning {
    background: rgba(245, 158, 11, 0.2);
    color: #fbbf24;
  }

  .severity-badge.info {
    background: rgba(59, 130, 246, 0.2);
    color: #93c5fd;
  }

  @media (max-width: 768px) {
    .namora-insights {
      padding: 1rem;
    }

    .header-content {
      flex-direction: column;
      gap: 1rem;
    }

    .filters-section {
      flex-direction: column;
      gap: 1rem;
    }

    .insight-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
    }
  }
</style>

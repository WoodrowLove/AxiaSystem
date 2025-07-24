<!-- 🚨 NamoraAI Smart Alerts Dashboard Component -->
<script>
  import { onMount } from 'svelte';
  
  let alerts = [];
  let filteredAlerts = [];
  let systemHealth = null;
  let loading = true;
  let selectedSeverity = 'all';
  let selectedCategory = 'all';
  let showResolved = false;
  
  // Alert severity options
  const severityOptions = [
    { value: 'all', label: 'All Severities', color: 'bg-gray-500' },
    { value: 'critical', label: 'Critical', color: 'bg-red-600' },
    { value: 'high', label: 'High', color: 'bg-red-500' },
    { value: 'medium', label: 'Medium', color: 'bg-yellow-500' },
    { value: 'low', label: 'Low', color: 'bg-blue-500' }
  ];

  // Alert category options
  const categoryOptions = [
    { value: 'all', label: 'All Categories' },
    { value: 'security', label: 'Security' },
    { value: 'performance', label: 'Performance' },
    { value: 'financial', label: 'Financial' },
    { value: 'operational', label: 'Operational' },
    { value: 'compliance', label: 'Compliance' },
    { value: 'userBehavior', label: 'User Behavior' }
  ];

  // Mock alerts data (replace with actual canister calls)
  const mockAlerts = [
    {
      id: 1,
      timestamp: Date.now() * 1000000 - 1800000000000,
      severity: 'high',
      category: 'operational',
      title: 'Error Spike Detected',
      description: 'payment has generated 5 errors in the last 5 minutes',
      affectedSources: ['payment'],
      confidence: 0.9,
      recommendations: [
        'Investigate recent changes to payment',
        'Check system resources and dependencies',
        'Review error logs for common patterns'
      ],
      isResolved: false,
      resolvedAt: null,
      resolvedBy: null,
      resolutionNotes: null
    },
    {
      id: 2,
      timestamp: Date.now() * 1000000 - 3600000000000,
      severity: 'medium',
      category: 'financial',
      title: 'Multiple Low Balance Warnings',
      description: 'Detected 8 low balance warnings across the system',
      affectedSources: ['wallet'],
      confidence: 0.8,
      recommendations: [
        'Review user wallet funding patterns',
        'Consider implementing balance alerts for users',
        'Analyze if this indicates system-wide liquidity issues'
      ],
      isResolved: true,
      resolvedAt: Date.now() * 1000000 - 1800000000000,
      resolvedBy: 'admin_user',
      resolutionNotes: 'Added automated balance monitoring alerts'
    },
    {
      id: 3,
      timestamp: Date.now() * 1000000 - 900000000000,
      severity: 'medium',
      category: 'security',
      title: 'Unusual Administrative Activity',
      description: 'High volume of administrative operations detected',
      affectedSources: ['admin', 'governance'],
      confidence: 0.7,
      recommendations: [
        'Review recent administrative actions',
        'Verify all admin operations were authorized',
        'Check for unusual access patterns'
      ],
      isResolved: false,
      resolvedAt: null,
      resolvedBy: null,
      resolutionNotes: null
    }
  ];

  const mockSystemHealth = {
    overallScore: 87.5,
    timestamp: Date.now() * 1000000,
    dimensions: [
      {
        name: 'Performance',
        score: 85.0,
        weight: 0.4,
        factors: ['Error rate', 'Warning frequency'],
        status: 'excellent'
      },
      {
        name: 'Reliability',
        score: 92.0,
        weight: 0.4,
        factors: ['System uptime', 'Error frequency'],
        status: 'excellent'
      },
      {
        name: 'Security',
        score: 95.0,
        weight: 0.2,
        factors: ['Access patterns', 'Authentication events'],
        status: 'excellent'
      }
    ],
    criticalIssues: [],
    recommendations: ['System operating normally'],
    lastUpdated: Date.now() * 1000000
  };

  function loadAlerts() {
    loading = true;
    
    // Simulate API call delay
    setTimeout(() => {
      alerts = mockAlerts;
      systemHealth = mockSystemHealth;
      filterAlerts();
      loading = false;
    }, 1000);
  }

  function filterAlerts() {
    filteredAlerts = alerts.filter(alert => {
      const matchesSeverity = selectedSeverity === 'all' || alert.severity === selectedSeverity;
      const matchesCategory = selectedCategory === 'all' || alert.category === selectedCategory;
      const matchesResolved = showResolved || !alert.isResolved;
      
      return matchesSeverity && matchesCategory && matchesResolved;
    });
  }

  function formatTimestamp(timestamp) {
    const date = new Date(timestamp / 1000000);
    return date.toLocaleString();
  }

  function getSeverityColor(severity) {
    switch (severity) {
      case 'critical': return 'text-red-300 bg-red-900/30 border-red-500/50';
      case 'high': return 'text-red-400 bg-red-900/20 border-red-500/30';
      case 'medium': return 'text-yellow-400 bg-yellow-900/20 border-yellow-500/30';
      case 'low': return 'text-blue-400 bg-blue-900/20 border-blue-500/30';
      default: return 'text-gray-400 bg-gray-900/20 border-gray-500/30';
    }
  }

  function getCategoryIcon(category) {
    const icons = {
      security: '🔒',
      performance: '⚡',
      financial: '💰',
      operational: '⚙️',
      compliance: '📋',
      userBehavior: '👤'
    };
    return icons[category] || '🚨';
  }

  function getHealthColor(score) {
    if (score >= 90) return 'text-green-400';
    if (score >= 75) return 'text-yellow-400';
    if (score >= 60) return 'text-orange-400';
    return 'text-red-400';
  }

  function resolveAlert(alertId) {
    const notes = prompt('Enter resolution notes:');
    if (notes) {
      alerts = alerts.map(alert => {
        if (alert.id === alertId) {
          return {
            ...alert,
            isResolved: true,
            resolvedAt: Date.now() * 1000000,
            resolvedBy: 'current_user',
            resolutionNotes: notes
          };
        }
        return alert;
      });
      filterAlerts();
    }
  }

  // Reactive statements
  $: if (selectedSeverity || selectedCategory || showResolved) {
    filterAlerts();
  }

  onMount(() => {
    loadAlerts();
    
    // Auto-refresh every 30 seconds
    const interval = setInterval(loadAlerts, 30000);
    
    return () => clearInterval(interval);
  });
</script>

<div class="smart-alerts">
  <div class="alerts-header">
    <div class="header-content">
      <div class="title-section">
        <h2 class="alerts-title">🚨 Smart Alerts & System Health</h2>
        <p class="alerts-subtitle">AI-powered monitoring and intelligent alerting</p>
      </div>
      
      <div class="header-actions">
        <button class="refresh-btn" on:click={loadAlerts} disabled={loading}>
          <span class="refresh-icon" class:spinning={loading}>🔄</span>
          Refresh
        </button>
      </div>
    </div>
  </div>

  <!-- System Health Overview -->
  {#if systemHealth}
    <div class="health-overview">
      <div class="overall-health">
        <div class="health-score {getHealthColor(systemHealth.overallScore)}">
          {systemHealth.overallScore.toFixed(1)}%
        </div>
        <div class="health-label">Overall System Health</div>
      </div>
      
      <div class="health-dimensions">
        {#each systemHealth.dimensions as dimension}
          <div class="dimension">
            <div class="dimension-name">{dimension.name}</div>
            <div class="dimension-score {getHealthColor(dimension.score)}">
              {dimension.score.toFixed(1)}%
            </div>
            <div class="dimension-status">{dimension.status}</div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

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
      <label for="category-filter">Category:</label>
      <select id="category-filter" bind:value={selectedCategory} class="filter-select">
        {#each categoryOptions as option}
          <option value={option.value}>{option.label}</option>
        {/each}
      </select>
    </div>

    <div class="filter-group">
      <label>
        <input type="checkbox" bind:checked={showResolved} />
        Show Resolved
      </label>
    </div>
  </div>

  <!-- Alerts List -->
  <div class="alerts-container">
    {#if loading}
      <div class="loading-state">
        <div class="loading-spinner"></div>
        <p>Loading smart alerts...</p>
      </div>
    {:else if filteredAlerts.length === 0}
      <div class="empty-state">
        <div class="empty-icon">✅</div>
        <p>No alerts match your current filters</p>
        <button on:click={() => { selectedSeverity = 'all'; selectedCategory = 'all'; showResolved = false; }}>
          Clear Filters
        </button>
      </div>
    {:else}
      <div class="alerts-list">
        {#each filteredAlerts as alert (alert.id)}
          <div class="alert-card {getSeverityColor(alert.severity)}" class:resolved={alert.isResolved}>
            <div class="alert-header">
              <div class="alert-info">
                <span class="category-icon">{getCategoryIcon(alert.category)}</span>
                <div class="alert-title">{alert.title}</div>
                <div class="severity-badge {alert.severity}">
                  {alert.severity.toUpperCase()}
                </div>
              </div>
              <div class="alert-timestamp">
                {formatTimestamp(alert.timestamp)}
              </div>
            </div>
            
            <div class="alert-description">
              {alert.description}
            </div>
            
            <div class="alert-details">
              <div class="affected-sources">
                <strong>Affected:</strong> {alert.affectedSources.join(', ')}
              </div>
              <div class="confidence">
                <strong>Confidence:</strong> {(alert.confidence * 100).toFixed(0)}%
              </div>
            </div>
            
            <div class="recommendations">
              <strong>Recommendations:</strong>
              <ul>
                {#each alert.recommendations as rec}
                  <li>{rec}</li>
                {/each}
              </ul>
            </div>
            
            <div class="alert-actions">
              {#if alert.isResolved}
                <div class="resolution-info">
                  <div class="resolved-badge">✅ Resolved</div>
                  <div class="resolution-details">
                    <div>By: {alert.resolvedBy}</div>
                    <div>At: {formatTimestamp(alert.resolvedAt)}</div>
                    {#if alert.resolutionNotes}
                      <div>Notes: {alert.resolutionNotes}</div>
                    {/if}
                  </div>
                </div>
              {:else}
                <button class="resolve-btn" on:click={() => resolveAlert(alert.id)}>
                  Mark as Resolved
                </button>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>

<style>
  .smart-alerts {
    padding: 2rem;
    max-width: 1400px;
    margin: 0 auto;
    background: linear-gradient(135deg, #0a0b1e 0%, #1a1b3e 100%);
    color: white;
    border-radius: 12px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
  }

  .alerts-header {
    margin-bottom: 2rem;
  }

  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 2rem;
  }

  .alerts-title {
    font-size: 2rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
    background: linear-gradient(135deg, #ff6b6b, #ffa726);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  .alerts-subtitle {
    color: rgba(255, 255, 255, 0.7);
    font-size: 1.1rem;
  }

  .health-overview {
    display: flex;
    gap: 2rem;
    margin-bottom: 2rem;
    padding: 1.5rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .overall-health {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }

  .health-score {
    font-size: 3rem;
    font-weight: bold;
    margin-bottom: 0.5rem;
  }

  .health-label {
    color: rgba(255, 255, 255, 0.7);
    font-weight: 500;
  }

  .health-dimensions {
    display: flex;
    gap: 2rem;
    flex: 1;
  }

  .dimension {
    text-align: center;
    flex: 1;
  }

  .dimension-name {
    font-weight: 600;
    margin-bottom: 0.5rem;
    color: #f7d794;
  }

  .dimension-score {
    font-size: 1.5rem;
    font-weight: bold;
    margin-bottom: 0.25rem;
  }

  .dimension-status {
    font-size: 0.8rem;
    color: rgba(255, 255, 255, 0.6);
    text-transform: capitalize;
  }

  .filters-section {
    display: flex;
    gap: 2rem;
    margin-bottom: 2rem;
    padding: 1.5rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    flex-wrap: wrap;
    align-items: center;
  }

  .filter-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .filter-group label {
    font-weight: 600;
    color: #f7d794;
    white-space: nowrap;
  }

  .filter-select {
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 6px;
    padding: 0.5rem 1rem;
    color: white;
    font-size: 0.9rem;
  }

  .alerts-list {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .alert-card {
    border: 1px solid;
    border-radius: 12px;
    padding: 1.5rem;
    transition: all 0.3s ease;
  }

  .alert-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
  }

  .alert-card.resolved {
    opacity: 0.7;
  }

  .alert-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 1rem;
  }

  .alert-info {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .category-icon {
    font-size: 1.5rem;
  }

  .alert-title {
    font-size: 1.2rem;
    font-weight: 600;
  }

  .severity-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 12px;
    font-size: 0.7rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .severity-badge.critical {
    background: rgba(220, 38, 38, 0.2);
    color: #fca5a5;
  }

  .severity-badge.high {
    background: rgba(239, 68, 68, 0.2);
    color: #fca5a5;
  }

  .severity-badge.medium {
    background: rgba(245, 158, 11, 0.2);
    color: #fbbf24;
  }

  .severity-badge.low {
    background: rgba(59, 130, 246, 0.2);
    color: #93c5fd;
  }

  .alert-timestamp {
    font-size: 0.8rem;
    color: rgba(255, 255, 255, 0.6);
    font-family: monospace;
  }

  .alert-description {
    font-size: 1rem;
    line-height: 1.5;
    margin-bottom: 1rem;
    color: rgba(255, 255, 255, 0.9);
  }

  .alert-details {
    display: flex;
    gap: 2rem;
    margin-bottom: 1rem;
    font-size: 0.9rem;
  }

  .recommendations {
    margin-bottom: 1rem;
    font-size: 0.9rem;
  }

  .recommendations ul {
    margin-top: 0.5rem;
    padding-left: 1.5rem;
  }

  .recommendations li {
    margin-bottom: 0.25rem;
    color: rgba(255, 255, 255, 0.8);
  }

  .alert-actions {
    display: flex;
    justify-content: flex-end;
    align-items: center;
  }

  .resolve-btn {
    background: linear-gradient(135deg, #10b981, #059669);
    border: none;
    color: white;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.3s ease;
  }

  .resolve-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  }

  .resolution-info {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .resolved-badge {
    background: rgba(16, 185, 129, 0.2);
    color: #6ee7b7;
    padding: 0.25rem 0.75rem;
    border-radius: 12px;
    font-size: 0.8rem;
    font-weight: 600;
  }

  .resolution-details {
    font-size: 0.8rem;
    color: rgba(255, 255, 255, 0.6);
  }

  .loading-state, .empty-state {
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
    border-top: 3px solid #ff6b6b;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 1rem;
  }

  .empty-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
    opacity: 0.6;
  }

  .refresh-btn {
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

  .refresh-btn:hover {
    background: rgba(255, 255, 255, 0.2);
    transform: translateY(-1px);
  }

  .refresh-icon.spinning {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  @media (max-width: 768px) {
    .smart-alerts {
      padding: 1rem;
    }

    .header-content {
      flex-direction: column;
      gap: 1rem;
    }

    .health-overview {
      flex-direction: column;
      gap: 1rem;
    }

    .health-dimensions {
      flex-direction: column;
      gap: 1rem;
    }

    .filters-section {
      flex-direction: column;
      gap: 1rem;
      align-items: stretch;
    }

    .alert-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
    }

    .alert-details {
      flex-direction: column;
      gap: 0.5rem;
    }
  }
</style>

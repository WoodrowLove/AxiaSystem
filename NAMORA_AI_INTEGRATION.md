# 🧠 NamoraAI Observability Integration Guide

## Overview

This guide covers the complete integration of the NamoraAI observability layer with your live AxiaSystem deployment, transforming the current mock data implementation into a fully functional real-time monitoring system.

## Current State ✅

### Completed Infrastructure
- **Core Types**: `types/insight.mo`, `types/alert.mo`, `types/analytics.mo`
- **Intelligence Engine**: Advanced AI-powered analysis and alerting
- **Central Hub**: `namora_ai/main.mo` with full API suite
- **Instrumented Canisters**: 7+ canisters with `emitInsight()` functions
- **Frontend Components**: 
  - `NamoraInsights.svelte` - Basic insights dashboard
  - `SmartAlerts.svelte` - Advanced alerts and health monitoring

### Current Mock Data
The frontend currently uses mock data to demonstrate functionality. The following components need live canister integration:

```javascript
// Current Mock Implementation
const mockInsights = [...];
const mockAlerts = [...];
const mockSystemHealth = {...};
```

## Phase 1: Deploy NamoraAI Canister

### 1.1 Update dfx.json
Add the NamoraAI canister to your deployment configuration:

```json
{
  "canisters": {
    "namora_ai": {
      "type": "motoko",
      "main": "src/AxiaSystem_backend/namora_ai/main.mo",
      "canister_id": "YOUR_NAMORA_AI_CANISTER_ID"
    }
  }
}
```

### 1.2 Deploy the Canister
```bash
# Build and deploy NamoraAI
dfx build namora_ai
dfx deploy namora_ai

# Get the canister ID
dfx canister id namora_ai
```

### 1.3 Update Environment Variables
Add the NamoraAI canister ID to your environment:

```bash
# Add to .env
CANISTER_ID_NAMORA_AI=your_actual_canister_id
```

## Phase 2: Connect Existing Canisters

### 2.1 Replace Mock Calls with Real Canister Calls
Update all instrumented canisters to call the actual NamoraAI canister:

```motoko
// Replace this comment in each canister:
// await NamoraAI.pushInsight(insight);

// With actual canister call:
let namoraAI = actor("YOUR_NAMORA_AI_CANISTER_ID") : actor {
    pushInsight: (Insight.SystemInsight) -> async ();
};
await namoraAI.pushInsight(insight);
```

### 2.2 Auto-Instrument Remaining Canisters
Run the provided script to add observability to remaining canisters:

```bash
# Run the auto-instrumentation script
./instrument_observability.sh

# Review and customize the generated code
# Add specific emitInsight() calls to business logic
```

## Phase 3: Frontend Integration

### 3.1 Create Canister Interface
Create a TypeScript interface for the NamoraAI canister:

```typescript
// src/declarations/namora_ai/index.ts
export interface NamoraAI {
  getRecentInsights(): Promise<SystemInsight[]>;
  getInsightsBySeverity(severity: string): Promise<SystemInsight[]>;
  getInsightsBySource(source: string): Promise<SystemInsight[]>;
  getSystemHealthSummary(): Promise<SystemHealthSummary>;
  getSmartAlerts(): Promise<SmartAlert[]>;
  getSystemHealth(): Promise<SystemHealth>;
  pushInsight(insight: SystemInsight): Promise<void>;
  resolveAlert(alertId: number, notes: string): Promise<boolean>;
}
```

### 3.2 Replace Mock Data in NamoraInsights.svelte
```svelte
<script>
  import { createActor } from "../declarations/namora_ai";
  
  // Remove mock data
  // const mockInsights = [...];
  
  // Add real canister connection
  let namoraAI;
  
  onMount(async () => {
    namoraAI = createActor(process.env.CANISTER_ID_NAMORA_AI, {
      agentOptions: {
        host: process.env.DFX_NETWORK === "local" 
          ? "http://localhost:4943" 
          : "https://ic0.app",
      },
    });
    
    await loadInsights();
  });
  
  async function loadInsights() {
    loading = true;
    try {
      insights = await namoraAI.getRecentInsights();
      updateStats();
      filterInsights();
    } catch (error) {
      console.error("Failed to load insights:", error);
      error = error.message;
    } finally {
      loading = false;
    }
  }
</script>
```

### 3.3 Replace Mock Data in SmartAlerts.svelte
```svelte
<script>
  import { createActor } from "../declarations/namora_ai";
  
  let namoraAI;
  
  onMount(async () => {
    namoraAI = createActor(process.env.CANISTER_ID_NAMORA_AI);
    await loadAlerts();
  });
  
  async function loadAlerts() {
    loading = true;
    try {
      [alerts, systemHealth] = await Promise.all([
        namoraAI.getSmartAlerts(),
        namoraAI.getSystemHealth()
      ]);
      filterAlerts();
    } catch (error) {
      console.error("Failed to load alerts:", error);
    } finally {
      loading = false;
    }
  }
  
  async function resolveAlert(alertId) {
    const notes = prompt('Enter resolution notes:');
    if (notes) {
      try {
        const success = await namoraAI.resolveAlert(alertId, notes);
        if (success) {
          await loadAlerts(); // Refresh the alerts
        }
      } catch (error) {
        console.error("Failed to resolve alert:", error);
      }
    }
  }
</script>
```

## Phase 4: Enhanced Admin Integration

### 4.1 Update App.svelte Admin Interface
```svelte
<!-- Add SmartAlerts component to admin tabs -->
<script>
  import NamoraInsights from './NamoraInsights.svelte';
  import SmartAlerts from './SmartAlerts.svelte';
  
  let activeTab = 'overview';
  const adminTabs = [
    { id: 'overview', label: 'Overview', icon: '📊' },
    { id: 'insights', label: 'System Insights', icon: '🧠' },
    { id: 'alerts', label: 'Smart Alerts', icon: '🚨' },
    { id: 'health', label: 'System Health', icon: '❤️' },
    // ... other tabs
  ];
</script>

<!-- Add in the tab content section -->
{#if activeTab === 'alerts'}
  <SmartAlerts />
{/if}
```

### 4.2 Real-time Updates
Implement WebSocket or polling for real-time updates:

```svelte
<script>
  let updateInterval;
  
  onMount(() => {
    // Poll for updates every 30 seconds
    updateInterval = setInterval(async () => {
      if (document.visibilityState === 'visible') {
        await loadAlerts();
      }
    }, 30000);
    
    return () => {
      if (updateInterval) {
        clearInterval(updateInterval);
      }
    };
  });
</script>
```

## Phase 5: Production Optimizations

### 5.1 Caching Strategy
Implement intelligent caching to reduce canister calls:

```typescript
// utils/cache.ts
class InsightCache {
  private cache = new Map();
  private ttl = 30000; // 30 seconds
  
  async get(key: string, fetcher: () => Promise<any>) {
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.timestamp < this.ttl) {
      return cached.data;
    }
    
    const data = await fetcher();
    this.cache.set(key, { data, timestamp: Date.now() });
    return data;
  }
}
```

### 5.2 Error Handling and Retry Logic
```typescript
// utils/canister.ts
export async function callCanisterWithRetry(
  canister: any, 
  method: string, 
  args: any[] = [],
  maxRetries = 3
) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await canister[method](...args);
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
}
```

### 5.3 Performance Monitoring
Add performance metrics to track the observability system itself:

```motoko
// In namora_ai/main.mo
public func getSystemMetrics() : async {
  totalInsights: Nat;
  avgProcessingTime: Float;
  errorRate: Float;
  uptime: Nat;
} {
  {
    totalInsights = insights.size();
    avgProcessingTime = calculateAvgProcessingTime();
    errorRate = calculateErrorRate();
    uptime = Time.now() - startTime;
  }
}
```

## Phase 6: Testing and Validation

### 6.1 End-to-End Testing
Create comprehensive tests for the observability pipeline:

```bash
# Test insight flow
dfx canister call user createUser '("test_user", "test@example.com", "password")'

# Verify insight was captured
dfx canister call namora_ai getRecentInsights

# Test alert generation
# Generate multiple errors to trigger alerts
# Verify alerts appear in dashboard
```

### 6.2 Load Testing
Test the system under realistic load:

```typescript
// loadtest.ts
async function generateTestLoad() {
  const promises = [];
  for (let i = 0; i < 100; i++) {
    promises.push(
      namoraAI.pushInsight({
        source: "load_test",
        severity: "info",
        message: `Load test insight ${i}`,
        timestamp: Date.now() * 1000000
      })
    );
  }
  await Promise.all(promises);
}
```

## Phase 7: Monitoring and Maintenance

### 7.1 System Health Checks
Implement automated health checks:

```motoko
// Add to namora_ai/main.mo
system func heartbeat() : async () {
  // Run health checks every minute
  let health = await generateHealthAssessment(Buffer.toArray(insights));
  
  if (health.overallScore < 70.0) {
    await emitSelfInsight("warning", "System health score below threshold: " # Float.toText(health.overallScore));
  };
}
```

### 7.2 Alerting Integration
Connect to external alerting systems:

```motoko
// Webhook integration for critical alerts
public func sendWebhookAlert(alert: Alert.SmartAlert) : async () {
  if (alert.severity == #critical) {
    // Send to external monitoring system
    // Implementation depends on your infrastructure
  };
}
```

## Deployment Checklist

- [ ] NamoraAI canister deployed and tested
- [ ] All existing canisters updated with real pushInsight calls
- [ ] Remaining canisters instrumented with observability
- [ ] Frontend components connected to live data
- [ ] Real-time updates working
- [ ] Error handling implemented
- [ ] Performance optimizations applied
- [ ] End-to-end testing completed
- [ ] Load testing passed
- [ ] Monitoring and alerting configured
- [ ] Documentation updated

## Security Considerations

1. **Access Control**: Ensure only authorized canisters can push insights
2. **Data Privacy**: Sanitize sensitive data in insight messages
3. **Rate Limiting**: Implement protection against insight spam
4. **Audit Trail**: Log all administrative actions on alerts

## Next Steps: Advanced Features

After basic integration is complete, consider implementing:

1. **Machine Learning**: Train models on historical data for better predictions
2. **Custom Dashboards**: Allow users to create personalized monitoring views
3. **Integration APIs**: Connect with external monitoring tools (Prometheus, Grafana)
4. **Mobile Notifications**: Push critical alerts to mobile devices
5. **Compliance Reporting**: Generate automated compliance reports
6. **Incident Management**: Full incident lifecycle tracking

## Support and Resources

- **Documentation**: This guide and inline code comments
- **Testing**: Use provided test scripts and load testing tools
- **Monitoring**: Built-in system health and performance metrics
- **Community**: Share insights and improvements with the team

---

**🧠 NamoraAI Observability Integration Complete!**

This comprehensive integration transforms your AxiaSystem into a fully observable, intelligent platform with AI-powered monitoring, predictive alerting, and real-time system health assessment.

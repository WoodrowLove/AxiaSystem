# AxiaSystem Automation Quick Reference

## 🚀 Quick Commands

### Most Common Usage
```bash
# Complete automation (recommended for most cases)
./integrated_automation_manager.sh --full-integration

# Quick sync after deploying new canisters
./integrated_automation_manager.sh --canisters-only

# Update bridge after canister modifications
./integrated_automation_manager.sh --bridge-only
```

### Individual Component Management
```bash
# Canister ID management only
./simple_canister_manager.sh

# Bridge automation only
./bridge_automation_manager.sh --full-update

# Quick bridge sync
./bridge_automation_manager.sh --sync-only

# Validation checks
./integrated_automation_manager.sh --validate-only
```

## 🔄 Typical Workflow

### Development Cycle
1. **Modify/Deploy Canisters**
   ```bash
   dfx deploy my_canister
   ```

2. **Update Ecosystem**
   ```bash
   ./integrated_automation_manager.sh --full-integration
   ```

3. **Verify Everything Works**
   ```bash
   ./integrated_automation_manager.sh --validate-only
   ```

### Production Deployment
1. **Deploy to Mainnet**
   ```bash
   dfx deploy --network ic
   ```

2. **Update All Systems**
   ```bash
   ./integrated_automation_manager.sh --full-integration
   ```

3. **Verify Production Ready**
   ```bash
   ./integrated_automation_manager.sh --validate-only
   ```

## 📊 What Each Script Does

### `simple_canister_manager.sh`
- ✅ Fetches current canister IDs
- ✅ Updates `canister_ids.json`
- ✅ Generates frontend configuration
- ✅ Updates documentation

### `bridge_automation_manager.sh`
- ✅ Analyzes bridge structure
- ✅ Generates missing bindings
- ✅ Updates module declarations
- ✅ Syncs canister IDs to bridge
- ✅ Validates compilation

### `integrated_automation_manager.sh`
- ✅ Coordinates full workflow
- ✅ Runs canister + bridge automation
- ✅ Cross-system validation
- ✅ Comprehensive reporting

## 🎯 When to Use What

| Situation | Command | What It Does |
|-----------|---------|--------------|
| New canister deployed | `--full-integration` | Updates everything automatically |
| Modified canister interface | `--bridge-only` | Regenerates bridge bindings |
| Changed canister IDs | `--canisters-only` | Updates ID configurations |
| Health check | `--validate-only` | Checks system status |
| Bridge compilation issues | `bridge_automation_manager.sh --sync-only` | Fixes module declarations |

## 📁 Key Files Generated

- **`canister_ids.json`** - Current canister ID mappings
- **`src/config/canister-ids.js`** - Frontend configuration
- **`AxiaSystem-Rust-Bridge/src/constants.rs`** - Bridge canister constants
- **Documentation updates** - Automatic documentation sync

## 🔍 Troubleshooting

### Common Issues
```bash
# Bridge compilation errors
./bridge_automation_manager.sh --validate-only

# Missing canister IDs
./simple_canister_manager.sh

# Integration validation failures
./integrated_automation_manager.sh --validate-only
```

### Log Files
- `integrated_automation.log` - Full integration logs
- `bridge_automation.log` - Bridge-specific logs
- `canister_management.log` - Canister management logs

## 💡 Pro Tips

1. **Always run validation** after major changes
2. **Use full integration** when unsure what needs updating
3. **Check logs** if automation fails
4. **Backup is automatic** - all scripts create backups before changes

## 🌐 Environment Support

✅ **Local Development** (`dfx start`)  
✅ **Testnet Deployment** (`--network testnet`)  
✅ **Production Mainnet** (`--network ic`)  

All commands automatically detect and adapt to your current environment!

---

**For detailed documentation, see:** `documentation/BRIDGE_AUTOMATION_COMPLETE.md`

#!/bin/bash

# 🧠 NamoraAI Observability Auto-Instrumentation Script
# 
# This script automatically adds observability infrastructure to existing
# Motoko canisters in the AxiaSystem project.

echo "🧠 NamoraAI Auto-Instrumentation Starting..."
echo "Adding observability to remaining AxiaSystem canisters..."

# Define the base imports to add
IMPORTS='
// 🧠 NamoraAI Observability Imports
import Insight "../types/insight";
import Time "mo:base/Time";
import Debug "mo:base/Debug";'

# Define the emitInsight helper function
EMIT_INSIGHT_FUNCTION='
    // 🧠 NamoraAI Observability Helper
    private func emitInsight(severity: Text, message: Text) : async () {
        let _insight : Insight.SystemInsight = {
            source = "SOURCE_NAME";
            severity = severity;
            message = message;
            timestamp = Time.now();
        };
        Debug.print("🧠 SOURCE_NAME_UPPER INSIGHT [" # severity # "]: " # message);
        // await NamoraAI.pushInsight(insight);
    };'

# Array of canisters to instrument (excluding already done ones)
CANISTERS=(
    "asset"
    "asset_registry" 
    "nft"
    "payment_monitoring"
    "payout"
    "split_payment"
    "subscriptions"
    "token"
    "treasury"
)

# Function to add observability to a canister
instrument_canister() {
    local canister_name=$1
    local main_file="src/AxiaSystem_backend/${canister_name}/main.mo"
    
    echo "🔧 Instrumenting ${canister_name}..."
    
    if [ ! -f "$main_file" ]; then
        echo "❌ Main file not found: $main_file"
        return 1
    fi
    
    # Create backup
    cp "$main_file" "${main_file}.backup"
    
    # Check if already instrumented
    if grep -q "NamoraAI Observability" "$main_file"; then
        echo "✅ ${canister_name} already instrumented"
        return 0
    fi
    
    # Get the source name (uppercase for debug messages)
    local source_upper=$(echo "$canister_name" | tr '[:lower:]' '[:upper:]')
    
    # Prepare the customized function
    local custom_function=$(echo "$EMIT_INSIGHT_FUNCTION" | sed "s/SOURCE_NAME/${canister_name}/g" | sed "s/SOURCE_NAME_UPPER/${source_upper}/g")
    
    # Find the actor line and add imports after it
    local actor_line=$(grep -n "^actor" "$main_file" | head -1 | cut -d: -f1)
    
    if [ -z "$actor_line" ]; then
        echo "❌ Could not find actor declaration in $main_file"
        return 1
    fi
    
    # Create temporary file with instrumentation
    {
        # Add everything before the actor line
        head -n $((actor_line - 1)) "$main_file"
        
        # Add imports
        echo "$IMPORTS"
        echo ""
        
        # Add the actor line and everything after
        tail -n +$actor_line "$main_file"
    } > "${main_file}.tmp"
    
    # Find where to insert the emitInsight function (after actor opening brace)
    local brace_line=$(grep -n "^actor.*{" "${main_file}.tmp" | head -1 | cut -d: -f1)
    
    if [ -n "$brace_line" ]; then
        # Insert emitInsight function after actor opening brace
        {
            head -n $brace_line "${main_file}.tmp"
            echo "$custom_function"
            echo ""
            tail -n +$((brace_line + 1)) "${main_file}.tmp"
        } > "${main_file}.final"
        
        mv "${main_file}.final" "$main_file"
    else
        mv "${main_file}.tmp" "$main_file"
    fi
    
    # Clean up
    rm -f "${main_file}.tmp" "${main_file}.final"
    
    echo "✅ ${canister_name} instrumented successfully"
    
    # Add sample insight calls for common patterns
    add_sample_insights "$main_file" "$canister_name"
}

# Function to add sample insight calls to common function patterns
add_sample_insights() {
    local file=$1
    local canister_name=$2
    
    echo "📝 Adding sample insight calls to ${canister_name}..."
    
    # Look for common function patterns and suggest where to add insights
    local functions=$(grep -n "public.*func.*:" "$file" | head -3)
    
    if [ -n "$functions" ]; then
        echo "💡 Consider adding emitInsight() calls to these functions:"
        echo "$functions" | while read line; do
            local line_num=$(echo "$line" | cut -d: -f1)
            local func_name=$(echo "$line" | sed 's/.*func \([^(]*\).*/\1/')
            echo "   Line $line_num: $func_name"
        done
        echo ""
    fi
}

# Function to validate instrumentation
validate_instrumentation() {
    local canister_name=$1
    local main_file="src/AxiaSystem_backend/${canister_name}/main.mo"
    
    echo "🔍 Validating ${canister_name} instrumentation..."
    
    # Check for required components
    local has_imports=$(grep -c "NamoraAI Observability" "$main_file")
    local has_function=$(grep -c "emitInsight" "$main_file")
    
    if [ "$has_imports" -gt 0 ] && [ "$has_function" -gt 0 ]; then
        echo "✅ ${canister_name} validation passed"
        return 0
    else
        echo "❌ ${canister_name} validation failed"
        return 1
    fi
}

# Main execution
echo "🚀 Starting auto-instrumentation for ${#CANISTERS[@]} canisters..."
echo ""

successful=0
failed=0

for canister in "${CANISTERS[@]}"; do
    echo "----------------------------------------"
    
    if instrument_canister "$canister"; then
        if validate_instrumentation "$canister"; then
            ((successful++))
            echo "🎉 ${canister} ready for observability!"
        else
            ((failed++))
            echo "⚠️  ${canister} instrumented but validation failed"
        fi
    else
        ((failed++))
        echo "💥 ${canister} instrumentation failed"
    fi
    
    echo ""
done

echo "========================================"
echo "🧠 NamoraAI Auto-Instrumentation Complete!"
echo ""
echo "📊 Results:"
echo "   ✅ Successful: $successful"
echo "   ❌ Failed: $failed"
echo "   📁 Total: ${#CANISTERS[@]}"
echo ""

if [ $successful -gt 0 ]; then
    echo "🎯 Next Steps:"
    echo "1. Review the instrumented files and add specific emitInsight() calls"
    echo "2. Test compilation with: dfx build"
    echo "3. Deploy updated canisters: dfx deploy"
    echo "4. Connect frontend to actual NamoraAI canister calls"
    echo ""
fi

if [ $failed -gt 0 ]; then
    echo "⚠️  Manual Review Required:"
    echo "Some canisters failed auto-instrumentation."
    echo "Check the backup files (.backup) if you need to restore."
    echo ""
fi

echo "🧠 NamoraAI observability layer expansion complete!"
echo "🔗 Next: Connect frontend components to live canister data"

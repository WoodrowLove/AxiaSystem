#!/bin/bash

echo "🔍 Searching for sequence mismatch errors in AxiaSystem..."

echo -e "\n📌 1. Exact 'CheckSequence' string matches:"
grep -r 'CheckSequence' src/

echo -e "\n📌 2. Any 'return #err' lines mentioning sequence:"
grep -r 'return #err' src/ | grep -i sequence

echo -e "\n📌 3. Any use of 'sequenceMap', 'sequenceTable', or similar patterns:"
grep -r -E 'sequenceMap|sequenceTable' src/

echo -e "\n📌 4. Any 'msg.caller' checks that may trigger sequence-related issues:"
grep -r 'msg.caller' src/ | grep -i sequence

echo -e "\n📌 5. Any general use of 'case (#err' switch handling:"
grep -r 'case (#err' src/

echo -e "\n✅ Done. Review output for conditional checks tied to identity or sequence control."
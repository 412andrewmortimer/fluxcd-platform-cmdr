#!/bin/bash

echo "🛑 Port-Forward Cleanup"
echo "======================"
echo ""

# Find all kubectl port-forward processes
PF_PIDS=$(ps aux | grep '[k]ubectl port-forward' | awk '{print $2}')

if [ -z "$PF_PIDS" ]; then
  echo "✅ No active port-forward processes found"
  exit 0
fi

echo "Found active port-forward processes:"
echo ""
ps aux | grep '[k]ubectl port-forward' | awk '{print "  PID " $2 ": " $11 " " $12 " " $13 " " $14 " " $15}'
echo ""

read -p "Kill all port-forward processes? [y/N]: " confirm

case $confirm in
  y|Y|yes|Yes|YES)
    echo ""
    echo "Stopping port-forwards..."
    echo "$PF_PIDS" | while read pid; do
      if kill "$pid" 2>/dev/null; then
        echo "  ✓ Stopped PID $pid"
      else
        echo "  ✗ Failed to stop PID $pid (may require sudo)"
      fi
    done
    echo ""
    echo "✅ Done!"
    ;;
  *)
    echo ""
    echo "❌ Cancelled"
    exit 1
    ;;
esac

#!/bin/bash
# Run fatigue recovery unit tests using GUT

echo "Running Fatigue Recovery System Tests..."
echo "========================================="

godot4 --headless --script addons/gut/gut_cmdln.gd \
  -gtest=tests/unit/test_fatigue_recovery.gd \
  -gexit

echo ""
echo "Tests complete!"

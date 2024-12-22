#!/bin/bash

# Define the versions to test
versions=("3.0.1" "4.0.1")

# Check if the --local flag is passed
local_install=false
if [[ "$1" == "--local" ]]; then
  local_install=true
fi

# Function to run the benchmark
run_benchmark() {
  cd benchmark

  echo "Running benchmark..."

  dart run bin/benchmark.dart

  cd ..
}

if [ "$local_install" = true ]; then
  echo "Testing local version of computables..."

  # Add the local version of the computables library
  dart pub add computables --path $(dirname "$(pwd)")

  # Get dependencies
  dart pub get

  # Run the benchmark
  run_benchmark
else
  # Loop over each version
  for version in "${versions[@]}"
  do
    echo "Testing computables version $version..."

    # Add the specific version of the computables library
    dart pub add computables:$version

    # Get dependencies
    dart pub get

    # Run the benchmark
    run_benchmark
  done
fi
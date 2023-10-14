#!/usr/bin/env bash

for dir in helm-charts/*; do
  if [ -d "$dir" ]; then
    helm dep update "$dir"
  fi
done

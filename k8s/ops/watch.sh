#!/bin/bash

echo "Get resource usage | all pods"
while true
do
  kubectl top pod sarsys-ops-server-0 -n sarsys --containers
  kubectl top pod sarsys-ops-server-1 -n sarsys --containers | grep  sarsys-ops-server-1
  kubectl top pod sarsys-ops-server-2 -n sarsys --containers | grep  sarsys-ops-server-2
  echo "Waiting for 5s..."
  sleep 5
  echo "---------------------------"
done

echo "[✓] sarsys-ops-server watch completed"
#!/bin/bash
PCI="03:00.0"
echo "DPU $PCI ..."
for worker in worker1-dpu worker2-dpu; do
t=$(ssh $worker sudo mget_temp -d $PCI | cut -d\  -f1)
echo "$worker $t C "
done

#!/bin/bash
PCI="00:10.0"
echo "DPU $PCI ..."
for worker in worker1 worker2; do
t=$(ssh $worker sudo mget_temp -d $PCI | cut -d\  -f1)
echo "$worker $t C "
done

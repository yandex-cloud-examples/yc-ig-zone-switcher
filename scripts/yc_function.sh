#!/bin/bash

function log {
   yc logging write --resource-id follow-the-leader --group-id $LOG_GROUP_ID --message "$1"
}
# get current master zone
mdb_master_zone=$(yc $MDB_STYPE hosts list --cluster-id $CLUSTER_ID --format json | \
  jq -r '.[] | select ((.role == "MASTER") and (.health == "ALIVE")).zone_id')
# get current ig zone
ig_zones=$(yc compute instance-group get --id $IG_ID --format json|jq -r '.allocation_policy.zones')
# compare them
if [ $(jq length <<< $ig_zones) -gt 1 ]; then
  # IG has multiple zones - do nothing
  log "IG has multiple zones"
 elif [ $(jq -r '[.[]][0].zone_id' <<< $ig_zones) == $mdb_master_zone ]; then
  # same zone - do nothing
  log "MDB master and IG zones are the same"
else
  # different zones - updating
  log "MDB master and IG zones are different"
  cpath=/function/storage/u01/$$
  #get the template from object storage
  mkdir -p $cpath
  yc storage s3api get-object --bucket $YC_BUCKET --key $IG_TEMPLATE  $cpath/$IG_TEMPLATE
  # customize template
  sed -i "s/<<ZONE_ID>>/$mdb_master_zone/g" $cpath/$IG_TEMPLATE
  # change zone
  yc compute instance-group update --id $IG_ID --file $cpath/$IG_TEMPLATE --async
  rm $cpath/$IG_TEMPLATE
  log "Instance group has been updated"
fi
exit 0

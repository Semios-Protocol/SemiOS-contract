# ABI
forge inspect D4AUniversalClaimer abi >deployed-contracts-info/frontend-abi/D4AUniversalClaimer.json
forge inspect PDCreateProjectProxy abi >deployed-contracts-info/frontend-abi/PDCreateProjectProxy.json
forge inspect PDProtocolReadable abi >deployed-contracts-info/frontend-abi/PDProtocolReadable.json
forge inspect PDProtocolSetter abi >deployed-contracts-info/frontend-abi/PDProtocolSetter.json
forge inspect PDProtocol abi >deployed-contracts-info/frontend-abi/PDProtocol.json
forge inspect D4ACreate abi >deployed-contracts-info/frontend-abi/D4ACreate.json
forge inspect PDCreate abi >deployed-contracts-info/frontend-abi/PDCreate.json
forge inspect PDBasicDao abi >deployed-contracts-info/frontend-abi/PDBasicDao.json
forge inspect PermissionControl abi >deployed-contracts-info/frontend-abi/PermissionControl.json
forge inspect PDRound abi >deployed-contracts-info/frontend-abi/PDRound.json
forge inspect D4AERC20 abi >deployed-contracts-info/frontend-abi/D4AERC20.json


# event selector
echo "{}" >deployed-contracts-info/selector.json
# DRB
forge inspect D4ADrb events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
# Protocol
forge inspect D4AProtocolSetter events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
forge inspect D4AProtocol events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
forge inspect D4AProtocolReadable events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
forge inspect D4ADiamond events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
forge inspect D4ASettings events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
# Permission Control
forge inspect PermissionControl events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
# Naive Owner
forge inspect NaiveOwner events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
# Roayalty Splitter
forge inspect D4ARoyaltySplitterFactory events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
forge inspect D4ARoyaltySplitter events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
# D4A Token
forge inspect D4AERC20 events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
forge inspect D4AERC721WithFilter events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
# 1.3
forge inspect PDCreate events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
forge inspect PDProtocol events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json
forge inspect PDRound events | jq --slurpfile existing deployed-contracts-info/selector.json '. + $existing[0]' >temp.json && mv temp.json deployed-contracts-info/selector.json



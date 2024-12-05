# gluesync-k8-helm-template-examples

## Getting started
This repository contains a simple deployable helm configuration for the main gluesync components. For this example, the gluesync source agent is MySQL while the gluesync target agent is Vertica.
In order to test the migration, both deployment and service must be provided for the respective databases.

For an updated gs-license.dat file please contact the Molo17 support.

##### Install the chart on the cluster
helm install gluesync-trial ./ --values ./values.yaml

##### Uninstall the chart from the cluster
helm uninstall gluesync-trial

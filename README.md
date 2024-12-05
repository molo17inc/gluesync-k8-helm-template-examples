# gluesync-k8-helm-template-examples

## Getting started
This repository contains a simple deployable helm configuration for the main Gluesync components. For this example, the Gluesync source agent is MySQL while the Gluesync target agent is Vertica.
In order to test the migration, both deployment and service must be provided for the respective databases.

For an updated gs-license.dat file please contact the MOLO17 sales team by writing an email to sales@molo17.com or request a trial from our website at https://molo17.com/get-gluesync.

##### Install the chart on the cluster
helm install gluesync-trial ./ --values ./values.yaml

##### Uninstall the chart from the cluster
helm uninstall gluesync-trial

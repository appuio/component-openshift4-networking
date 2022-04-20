// main template for openshift4-networking
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local resourceLocker = import 'lib/resource-locker.libjsonnet';
// The hiera parameters for the component
local params = inv.parameters.openshift4_networking;


local patch =
  resourceLocker.Patch(kube._Object('batch/v1', 'CronJob', 'ip-reconciler') {
    metadata+: {
      namespace: params.namespace,
    },
  }, {
    spec: {
      jobTemplate: {
        spec: {
          template: {
            spec: {
              nodeSelector: params.nodeSelector,
            },
          },
        },
      },
    },
  });

// Define outputs below
{
  '10_node_selector_patch': patch,
}

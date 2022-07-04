local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_networking;

local syn_metrics =
  params.monitoring.enabled &&
  std.member(inv.applications, 'prometheus');

if syn_metrics then
  {
    '20_metrics_servicemonitors': [],
  }
else
  {
  }

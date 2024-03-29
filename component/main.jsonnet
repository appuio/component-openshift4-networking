// main template for openshift4-networking
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local po = import 'lib/patch-operator.libsonnet';
// The hiera parameters for the component
local params = inv.parameters.openshift4_networking;

local patches =
  std.flattenArrays(
    std.filterMap(
      function(n) n != null && params.patches[n] != null,
      function(n)
        local p = params.patches[n];
        po.Patch(
          kube._Object(p.target.apiVersion, p.target.kind, p.target.name)
          + if p.target.namespace != null then
            {
              metadata+: {
                namespace: p.target.namespace,
              },
            }
          else
            {}
          , p.patch
        ),
      std.objectFields(params.patches)
    )
  );

// Define outputs below
{
  '00_namespace': kube.Namespace(params.namespace),
  '10_node_selector_patch': patches,
}

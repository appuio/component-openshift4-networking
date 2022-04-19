local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_networking;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('openshift4-networking', params.namespace);

{
  'openshift4-networking': app,
}

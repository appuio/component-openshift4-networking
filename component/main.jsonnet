// main template for openshift4-networking
local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';

// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.openshift4_networking;

local metadataPatch = {
  annotations+: {
    'syn.tools/source': 'https://github.com/appuio/component-openshift4-networking.git',
  },
  labels+: {
    'app.kubernetes.io/managed-by': 'espejote',
    'app.kubernetes.io/part-of': 'syn',
    'app.kubernetes.io/component': 'openshift4-networking',
  },
  namespace: 'openshift-multus',
};

local patch = {
  apiVersion: 'batch/v1',
  kind: 'CronJob',
  metadata: {
    name: 'ip-reconciler',
    namespace: metadataPatch.namespace,
  },
  spec: {
    jobTemplate: {
      spec: {
        template: {
          spec: {
            nodeSelector: params.defaultNodeSelector,
          },
        },
      },
    },
  },
};

local serviceAccount = {
  apiVersion: 'v1',
  kind: 'ServiceAccount',
  metadata: {
    name: 'config-batch-cronjob-ip-reconciler',
  } + metadataPatch,
};

local role = {
  apiVersion: 'rbac.authorization.k8s.io/v1',
  kind: 'Role',
  metadata: {
    name: 'syn-espejote:config-batch-cronjob-ip-reconciler',
  } + metadataPatch,
  rules: [
    {
      apiGroups: [ 'batch' ],
      resources: [ 'configmaps' ],
      resourceNames: [ 'ip-reconciler' ],
      verbs: [ '*' ],
    },
  ],
};

local roleBinding = {
  apiVersion: 'rbac.authorization.k8s.io/v1',
  kind: 'RoleBinding',
  metadata: {
    name: 'syn-espejote:config-batch-cronjob-ip-reconciler',
  } + metadataPatch,
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'Role',
    name: role.metadata.name,
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: serviceAccount.metadata.name,
      namespace: serviceAccount.metadata.namespace,
    },
  ],
};

local managedResource = esp.managedResource('config-openshift-io-ingresses-cluster-manager', 'openshift-multus') {
  metadata+: metadataPatch,
  spec: {
    applyOptions: {
      force: true,
    },
    serviceAccountRef: {
      name: serviceAccount.metadata.name,
    },
    template: std.manifestJson(patch),
    triggers: [ {
      name: 'cronjob',
      watchResource: {
        apiVersion: patch.apiVersion,
        kind: patch.kind,
        name: patch.metadata.name,
        namespace: patch.metadata.namespace,
      },
    } ],
  },
};

// Define outputs below
{
  '00_namespace': {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      annotations+: {
        'argocd.argoproj.io/sync-options': 'Prune=false',
      },
      name: 'openshift-networking',
    },
  },
  '10_node_selector_patch': [
    serviceAccount,
    role,
    roleBinding,
    managedResource,
  ],
}

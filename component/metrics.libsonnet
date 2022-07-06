local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.openshift4_networking;

local syn_metrics =
  params.monitoring.enabled &&
  std.member(inv.applications, 'prometheus');

local nsName = 'syn-monitoring-openshift4-networking';
local promInstance =
  if params.monitoring.instance != null then
    params.monitoring.instance
  else
    inv.parameters.prometheus.defaultInstance;

local serviceMonitors = [
  prom.ServiceMonitor('multus-admission-controller') {
    targetNamespace: 'openshift-multus',
    selector: {
      matchLabels: {
        app: 'multus-admission-controller',
      },
    },
    endpoints: {
      multus:
        prom.ServiceMonitorHttpsEndpoint(
          'multus-admission-controller.openshift-multus.svc'
        ) {
          metricRelabelings: [
            prom.DropRuntimeMetrics,
          ],
        },
    },
    spec+: {
      // copied from OCP-managed ServiceMonitor, not sure if this is actually
      // required.
      jobLabel: 'app',
    },
  },
  prom.ServiceMonitor('multus-network') {
    targetNamespace: 'openshift-multus',
    selector: {
      matchLabels: {
        service: 'netowrk-metrics-service',
      },
    },
    endpoints: {
      network_metrics:
        prom.ServiceMonitorHttpsEndpoint(
          'network-metrics-service.openshift-multus.svc',
        ) {
          // OCP-managed ServiceMonitor has a 10s interval, but that seems
          // unnecessary.
          metricRelabelings: [
            prom.DropRuntimeMetrics,
          ],
        },
    },
  },
  prom.ServiceMonitor('network-check-source') {
    targetNamespace: 'openshift-network-diagnostics',
    selector: {
      matchLabels: {
        app: 'network-check-source',
      },
    },
    endpoints: {
      check:
        prom.ServiceMonitorHttpsEndpoint(
          'network-check-source.openshift-network-diagnostics.svc'
        ) {
          port: 'check-endpoints',
          tlsConfig+: {
            // OCP-managed ServiceMonitor also uses insecureSkipVerify
            insecureSkipVerify: true,
          },
          metricRelabelings: [
            prom.DropRuntimeMetrics,
            // Drop controller runtime & API server metrics
            {
              action: 'drop',
              regex:
                '(workqueue_.*|apiserver_.*|rest_client_.*|' +
                'authenticat(ion|ed)_.*)',
              sourceLabels: [ '__name__' ],
            },
          ],
        },
    },
    spec+: {
      jobLabel: 'component',
    },
  },
  prom.ServiceMonitor('openshift-sdn') {
    targetNamespace: 'openshift-sdn',
    selector: {
      matchLabels: {
        app: 'sdn',
      },
    },
    endpoints: {
      sdn:
        prom.ServiceMonitorHttpsEndpoint(
          'sdn.openshift-sdn.svc'
        ) {
          metricRelabelings: [
            prom.DropRuntimeMetrics,
          ],
        },
    },
    spec+: {
      jobLabel: 'app',
    },
  },
  prom.ServiceMonitor('ovn-master') {
    targetNamespace: 'openshift-ovn-kubernetes',
    selector: {
      matchLabels: {
        app: 'ovnkube-master',
      },
    },
    endpoints: {
      ovn_master:
        prom.ServiceMonitorHttpsEndpoint(
          'ovn-kubernetes-master.openshift-ovn-kubernetes.svc'
        ) {
          metricRelabelings: [
            prom.DropRuntimeMetrics,
          ],
        },
    },
  },
  prom.ServiceMonitor('ovn-node') {
    targetNamespace: 'openshift-ovn-kubernetes',
    selector: {
      matchLabels: {
        app: 'ovnkube-node',
      },
    },
    endpoints: {
      ovn_node_1:
        prom.ServiceMonitorHttpsEndpoint(
          'ovn-kubernetes-node.openshift-ovn-kubernetes.svc'
        ) {
          metricRelabelings: [
            prom.DropRuntimeMetrics,
          ],
        },
      ovn_node_2:
        prom.ServiceMonitorHttpsEndpoint(
          'ovn-kubernetes-node.openshift-ovn-kubernetes.svc'
        ) {
          port: 'ovn-metrics',
          metricRelabelings: [
            prom.DropRuntimeMetrics,
          ],
        },
    },
  },
];

if syn_metrics then
  {
    '20_metrics_namespace': prom.RegisterNamespace(
      kube.Namespace(nsName),
      instance=promInstance
    ),
    [if params.monitoring.enableServiceMonitors['network-check-source']
    then '20_metrics_networkpolicy']: [
      // openshift-multus and openshift-sdn don't have default
      // networkpolicies, and openshift-ovn-kubernetes metrics are exposed on
      // hostport. TBD: do we need additional networkpolicy on Cilium-enabled
      // clusters?
      prom.NetworkPolicy(instance=promInstance) {
        metadata+: {
          namespace: 'openshift-network-diagnostics',
        },
      },
    ],
    '20_metrics_servicemonitors': std.filter(
      function(it) it != null,
      [
        if params.monitoring.enableServiceMonitors[sm.metadata.name] then
          sm {
            metadata+: {
              name: '%s-%s' % [ sm.targetNamespace, sm.metadata.name ],
              namespace: nsName,
            },
          }
        for sm in serviceMonitors
      ]
    ),
  }
else
  std.trace(
    'Monitoring disabled or component `prometheus` not present, '
    + 'not deploying ServiceMonitors',
    {}
  )

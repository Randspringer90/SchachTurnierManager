import type { CapacitorConfig } from '@capacitor/cli';

// Capacitor 7 host masks are matched label by label. These masks cover only loopback,
// IPv4 private/link-local ranges and one-label mDNS names; no catch-all host is allowed.
const localNetworkHosts = [
  'localhost',
  '127.*.*.*',
  '10.*.*.*',
  '169.254.*.*',
  '192.168.*.*',
  '172.16.*.*', '172.17.*.*', '172.18.*.*', '172.19.*.*',
  '172.20.*.*', '172.21.*.*', '172.22.*.*', '172.23.*.*',
  '172.24.*.*', '172.25.*.*', '172.26.*.*', '172.27.*.*',
  '172.28.*.*', '172.29.*.*', '172.30.*.*', '172.31.*.*',
  '*.local',
];

const config: CapacitorConfig = {
  appId: 'io.github.randspringer90.schachturniermanager',
  appName: 'SchachTurnierManager',
  webDir: '../SchachTurnierManager.Mobile/companion-web',
  android: {
    // The local launcher is served from Capacitor's HTTPS origin while tournament PCs use
    // user-entered HTTP LAN addresses. Public hosts remain blocked by both JS and HostMask.
    allowMixedContent: true,
  },
  server: {
    allowNavigation: localNetworkHosts,
  },
};

export default config;

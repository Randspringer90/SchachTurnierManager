import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { serviceWorkerBuildFingerprint } from './service-worker-build.mjs';

export default defineConfig({
  plugins: [react(), serviceWorkerBuildFingerprint()],
  server: {
    // The API proxy is a local trusted client from the backend's perspective.
    // Keep the dev listener private; wildcard binding would expose that trust to LAN clients.
    host: '127.0.0.1',
    port: 5173,
    proxy: {
      '/api': 'http://127.0.0.1:5088'
    }
  }
});

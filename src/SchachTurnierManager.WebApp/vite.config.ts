import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    // host: true bindet alle Interfaces (localhost bleibt erreichbar) und erlaubt den
    // Zugriff vom Handy im gleichen WLAN/Hotspot fuer die QR-Wuerfelseite. /api wird
    // serverseitig zum Backend auf 127.0.0.1:5088 geproxyt, daher kein Backend-Hostwechsel noetig.
    host: true,
    port: 5173,
    proxy: {
      '/api': 'http://127.0.0.1:5088'
    }
  }
});

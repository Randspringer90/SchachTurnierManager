import type { CapacitorConfig } from '@capacitor/cli';

// STM-MOB-001: Android-Begleit-App (Companion) zum SchachTurnierManager-PC.
// Die App bündelt das bestehende React-/Vite-Frontend und verbindet sich zur Laufzeit mit
// einem vom Nutzer konfigurierten SchachTurnierManager-WebApi-Server im lokalen Netz.
// Bewusst KEINE feste Server-URL, keine Cloud, kein Tracking, keine feste IP.
const config: CapacitorConfig = {
  appId: 'io.github.randspringer90.schachturniermanager',
  appName: 'SchachTurnierManager',
  // Companion-Launcher (statische Konfigurationsseite). Die eigentliche WebApp wird zur
  // Laufzeit vom konfigurierten PC geladen, nicht mit in die APK gebündelt.
  webDir: '../SchachTurnierManager.Mobile/companion-web',
  // Keine eingebaute server.url: die Verbindung zum PC wird zur Laufzeit konfiguriert.
  android: {
    // Release-Flavor: kein Cleartext. Der ausdrücklich gekennzeichnete Test-Build darf HTTP
    // im privaten LAN über eine eigene Network-Security-Config erlauben (STM-MOB-001, Test-Flavor).
    allowMixedContent: false
  }
};

export default config;

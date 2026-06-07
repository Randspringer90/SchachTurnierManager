# Persistence

MVP verwendet `InMemoryTournamentStore` aus dem Application-Projekt.
Die spätere SQLite-/EF-Core-Anbindung gehört hierher, damit Domain und Application frei von Infrastrukturdetails bleiben.

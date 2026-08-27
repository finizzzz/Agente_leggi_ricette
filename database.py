import os
import mysql.connector
from dotenv import load_dotenv

load_dotenv()

db_host = os.getenv("DB_HOST", "localhost")
db_user = os.getenv("DB_USER", "root")
db_password = os.getenv("DB_PASSWORD")

def inizializza_database():
    try:
        # 1. Connessione al server e verifica database
        conn = mysql.connector.connect(host=db_host, user=db_user, password=db_password)
        cursor = conn.cursor()
        cursor.execute("CREATE DATABASE IF NOT EXISTS panificio_db")
        cursor.close()
        conn.close()

        # 2. Connessione specifica al database panificio_db
        conn = mysql.connector.connect(host=db_host, user=db_user, password=db_password, database="panificio_db")
        cursor = conn.cursor()

        # Tabella 1: Macchinari
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS macchinari (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nome VARCHAR(100) NOT NULL,
            tipo VARCHAR(50) NOT NULL,
            capacita_teglie INT DEFAULT NULL
        )
        """)

        # Tabella 2: Dipendenti
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS dipendenti (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nome VARCHAR(100) NOT NULL,
            ruolo VARCHAR(50) NOT NULL,
            turno_inizio TIME NOT NULL,
            turno_fine TIME NOT NULL
        )
        """)

        # Tabella 3: Ricette
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS ricette (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nome_ricetta VARCHAR(150) NOT NULL UNIQUE,
            resa_kg DECIMAL(6,2),
            dati_json JSON NOT NULL,
            data_creazione TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)

        # Tabella 4: Ordini
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS ordini (
            id INT AUTO_INCREMENT PRIMARY KEY,
            cliente VARCHAR(100) DEFAULT 'Banco',
            ricetta_id INT NOT NULL,
            quantita_kg DECIMAL(6,2) NOT NULL,
            data_consegna DATE NOT NULL,
            orario_consegna TIME NOT NULL,
            stato ENUM('in_attesa', 'pianificato', 'completato') DEFAULT 'in_attesa',
            FOREIGN KEY (ricetta_id) REFERENCES ricette(id) ON DELETE CASCADE
        )
        """)

        # ---> LA NUOVA TABELLA 5: Orari Panificio <---
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS orari_panificio (
            id INT AUTO_INCREMENT PRIMARY KEY,
            giorno_settimana VARCHAR(15) NOT NULL UNIQUE,
            orario_apertura TIME,
            orario_chiusura TIME,
            giorno_di_chiusura BOOLEAN DEFAULT FALSE
        )
        """)

        conn.commit()
        print("✅ Tutte le 5 tabelle (inclusi gli 'orari_panificio') sono state create/verificate con successo!")

        cursor.close()
        conn.close()

    except mysql.connector.Error as err:
        print(f"❌ Errore durante l'inizializzazione del database: {err}")

if __name__ == "__main__":
    inizializza_database()
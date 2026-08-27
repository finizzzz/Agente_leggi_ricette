import os
import json
import mysql.connector
from dotenv import load_dotenv

load_dotenv()

db_host = os.getenv("DB_HOST", "localhost")
db_user = os.getenv("DB_USER", "root")
db_password = os.getenv("DB_PASSWORD")

def popola_dati():
    try:
        conn = mysql.connector.connect(
            host=db_host,
            user=db_user,
            password=db_password,
            database="panificio_db"
        )
        cursor = conn.cursor()

        # 1. Pulizia tabelle esistenti
        cursor.execute("DELETE FROM ordini")
        cursor.execute("DELETE FROM ricette")
        cursor.execute("DELETE FROM dipendenti")
        cursor.execute("DELETE FROM macchinari")
        cursor.execute("DELETE FROM orari_panificio")

        # 2. Macchinari (Invariati)
        macchinari = [
            ("Impastatrice a spirale", "Impastatrice", 50),
            ("Forno a piani", "Forno", 8),
            ("Cella di lievitazione", "Cella", 12),
            ("Banco di lavoro", "Banco", None)
        ]
        cursor.executemany("INSERT INTO macchinari (nome, tipo, capacita_teglie) VALUES (%s, %s, %s)", macchinari)

        # 3. I NUOVI TURNI DIPENDENTI (Arrivo all'01:00 di notte)
        dipendenti = [
            ("Mario Rossi", "Mastro Panettiere", "01:00:00", "09:00:00"),
            ("Luigi Verdi", "Aiuto Fornaio", "01:00:00", "09:00:00")
        ]
        cursor.executemany("INSERT INTO dipendenti (nome, ruolo, turno_inizio, turno_fine) VALUES (%s, %s, %s, %s)", dipendenti)

        # 4. I NUOVI ORARI PANIFICIO (Consegne 04:30 - 10:00)
        orari = [
            ("Lunedì", "04:30:00", "10:00:00", False),
            ("Martedì", "04:30:00", "10:00:00", False),
            ("Mercoledì", "04:30:00", "10:00:00", False),
            ("Giovedì", "04:30:00", "10:00:00", False),
            ("Venerdì", "04:30:00", "10:00:00", False),
            ("Sabato", "04:30:00", "10:00:00", False),
            ("Domenica", None, None, True)
        ]
        cursor.executemany("INSERT INTO orari_panificio (giorno_settimana, orario_apertura, orario_chiusura, giorno_di_chiusura) VALUES (%s, %s, %s, %s)", orari)

        # 5. Ricetta JSON (Invariata)
        ricetta_ciabatta_json = {
            "nome_ricetta": "Ciabatta Artigianale con Biga",
            "dettagli_produzione": {
                "peso_totale_impasto_crudo_kg": 9.72,
                "resa_prodotto_cotto_kg": 8.26,
                "resa_stimata_pezzi": 24,
                "peso_per_pezzo_grammi": 350
            },
            "ingredienti": [
                {"nome_ingrediente": "Farina", "quantita": 6.0, "unita_di_misura": "kg"},
                {"nome_ingrediente": "Acqua", "quantita": 3.5, "unita_di_misura": "litri"},
                {"nome_ingrediente": "Lievito", "quantita": 0.05, "unita_di_misura": "kg"},
                {"nome_ingrediente": "Sale", "quantita": 0.12, "unita_di_misura": "kg"}
            ],
            "fasi": [
                {"nome_fase": "Impasto Finale", "macchinario_richiesto": "Impastatrice a spirale", "tempo_minuti": 18, "temperatura_gradi": None, "capacita_teglie_richieste": None},
                {"nome_fase": "Spezzatura e Formatura", "macchinario_richiesto": "Banco di lavoro", "tempo_minuti": 40, "temperatura_gradi": None, "capacita_teglie_richieste": 6},
                {"nome_fase": "Cottura", "macchinario_richiesto": "Forno a piani", "tempo_minuti": 25, "temperatura_gradi": 240, "capacita_teglie_richieste": 6}
            ]
        }
        cursor.execute("INSERT INTO ricette (nome_ricetta, resa_kg, dati_json) VALUES (%s, %s, %s)",
            ("Ciabatta Artigianale con Biga", 8.26, json.dumps(ricetta_ciabatta_json))
        )
        ricetta_id = cursor.lastrowid

        # 6. IL NUOVO ORDINE: 50 KG alle ore 06:00
        cursor.execute(
            """
            INSERT INTO ordini (cliente, ricetta_id, quantita_kg, data_consegna, orario_consegna, stato)
            VALUES (%s, %s, %s, CURDATE() + INTERVAL 1 DAY, %s, %s)
            """,
            ("Ristorante Bella Italia", ricetta_id, 50.00, "06:00:00", "in_attesa")
        )

        conn.commit()
        print("🎉 Scenario di Stress Test caricato nel Database!")

        cursor.close()
        conn.close()

    except mysql.connector.Error as err:
        print(f"❌ Errore durante l'inserimento dati: {err}")

if __name__ == "__main__":
    popola_dati()
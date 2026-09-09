import json 
import os
import mysql.connector
from fastapi import FastAPI
from dotenv import load_dotenv
from pydantic import BaseModel
from datetime import date, time
from fastapi import File, UploadFile
import shutil
import PyPDF2
import docx
from google import genai
from google.genai import types
from fastapi.middleware.cors import CORSMiddleware 
from typing import Optional # Aggiungi questa riga in cima con le altre import!

# 1. Carichiamo le password dal file .env protetto
load_dotenv()

app = FastAPI(title="API Panificio IA")

# Diciamo a FastAPI di far passare le richieste di Chrome
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# I "modelli" dei dati che ci aspettiamo di ricevere dal tablet
class NuovoOrdine(BaseModel):
    cliente: str
    ricetta_id: int
    quantita_kg: float
    data_consegna: date
    orario_consegna: time

class MacchinarioDati(BaseModel):
    nome: str
    tipo: str
    capacita: int

class DipendenteDati(BaseModel):
    nome: str
    ruolo: str
    turno_inizio: str
    turno_fine: str

class TurnoDati(BaseModel):
    data_turno: str 
    tipo: str
    dipendente: Optional[str] = ""
    ruolo_dipendente: Optional[str] = ""
    cliente: Optional[str] = ""
    orario: str

class RicettaDati(BaseModel):
    nome_ricetta: str
    resa_kg: float
    dati_json: dict  # L'intero pacchetto con ingredienti e fasi

# 2. Creiamo un "cacciavite" per collegarci rapidamente a MySQL
def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD"),
        database="panificio_db" 
    )

# La porta di benvenuto 
@app.get("/")
def benvenuto():
    return {"messaggio": "Benvenuto nel Server API del Panificio! Il motore è acceso."}

# --- ORDINI ---
@app.post("/ordini")
def salva_ordine(ordine: NuovoOrdine):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = """
            INSERT INTO ordini (cliente, ricetta_id, quantita_kg, data_consegna, orario_consegna, stato)
            VALUES (%s, %s, %s, %s, %s, 'in_attesa')
        """
        valori = (ordine.cliente, ordine.ricetta_id, ordine.quantita_kg, ordine.data_consegna, ordine.orario_consegna)
        cursor.execute(query, valori)
        conn.commit() 
        nuovo_id = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": f"Ordine {nuovo_id} salvato correttamente!"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- DIPENDENTI ---
@app.get("/dipendenti")
def ottieni_dipendenti():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM dipendenti")
        lista_dipendenti = cursor.fetchall()
        for dip in lista_dipendenti:
            dip['turno_inizio'] = str(dip['turno_inizio'])
            dip['turno_fine'] = str(dip['turno_fine'])
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista_dipendenti}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- AGGIUNGI DIPENDENTE ---
@app.post("/dipendenti")
def aggiungi_dipendente(dipendente: DipendenteDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "INSERT INTO dipendenti (nome, ruolo, turno_inizio, turno_fine) VALUES (%s, %s, %s, %s)"
        cursor.execute(query, (dipendente.nome, dipendente.ruolo, dipendente.turno_inizio, dipendente.turno_fine))
        conn.commit()
        nuovo_id = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Dipendente aggiunto", "id": nuovo_id}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- MODIFICA DIPENDENTE ---
@app.put("/dipendenti/{id_dipendente}")
def modifica_dipendente(id_dipendente: int, dipendente: DipendenteDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "UPDATE dipendenti SET nome=%s, ruolo=%s, turno_inizio=%s, turno_fine=%s WHERE id=%s"
        cursor.execute(query, (dipendente.nome, dipendente.ruolo, dipendente.turno_inizio, dipendente.turno_fine, id_dipendente))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Dipendente aggiornato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- ELIMINA DIPENDENTE ---
@app.delete("/dipendenti/{id_dipendente}")
def elimina_dipendente(id_dipendente: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "DELETE FROM dipendenti WHERE id=%s"
        cursor.execute(query, (id_dipendente,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Dipendente eliminato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# ==========================================
# CRUD TURNI CALENDARIO
# ==========================================
@app.get("/turni")
def ottieni_turni():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM turni_calendario")
        lista_turni = cursor.fetchall()
        
        # Convertiamo la data di MySQL in stringa per Flutter
        for turno in lista_turni:
            turno['data_turno'] = str(turno['data_turno'])
            
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista_turni}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.post("/turni")
def aggiungi_turno(turno: TurnoDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = """
            INSERT INTO turni_calendario (data_turno, tipo, dipendente, ruolo_dipendente, cliente, orario) 
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query, (turno.data_turno, turno.tipo, turno.dipendente, turno.ruolo_dipendente, turno.cliente, turno.orario))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Turno salvato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- MODIFICA TURNO CALENDARIO (PUT) ---
@app.put("/turni/{id_turno}")
def modifica_turno(id_turno: int, turno: TurnoDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = """
            UPDATE turni_calendario 
            SET data_turno=%s, tipo=%s, dipendente=%s, ruolo_dipendente=%s, cliente=%s, orario=%s
            WHERE id=%s
        """
        cursor.execute(query, (
            turno.data_turno, 
            turno.tipo, 
            turno.dipendente, 
            turno.ruolo_dipendente, 
            turno.cliente, 
            turno.orario, 
            id_turno
        ))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Turno aggiornato con successo"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.delete("/turni/{id_turno}")
def elimina_turno(id_turno: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM turni_calendario WHERE id=%s", (id_turno,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Turno eliminato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- RICETTE ---
@app.get("/ricette")
def ottieni_ricette():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM ricette")
        lista_ricette = cursor.fetchall()
        for ricetta in lista_ricette:
            if isinstance(ricetta['dati_json'], str):
                ricetta['dati_json'] = json.loads(ricetta['dati_json'])
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista_ricette}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- AGGIUNGI RICETTA MANUALE ---
@app.post("/ricette")
def aggiungi_ricetta(ricetta: RicettaDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "INSERT INTO ricette (nome_ricetta, resa_kg, dati_json) VALUES (%s, %s, %s)"
        # json.dumps trasforma il dizionario di Python in una stringa perfetta per MySQL
        cursor.execute(query, (ricetta.nome_ricetta, ricetta.resa_kg, json.dumps(ricetta.dati_json)))
        conn.commit()
        nuovo_id = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Ricetta aggiunta", "id": nuovo_id}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- MODIFICA RICETTA ---
@app.put("/ricette/{id_ricetta}")
def modifica_ricetta(id_ricetta: int, ricetta: RicettaDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "UPDATE ricette SET nome_ricetta=%s, resa_kg=%s, dati_json=%s WHERE id=%s"
        cursor.execute(query, (ricetta.nome_ricetta, ricetta.resa_kg, json.dumps(ricetta.dati_json), id_ricetta))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Ricetta aggiornata"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- ELIMINA RICETTA ---
@app.delete("/ricette/{id_ricetta}")
def elimina_ricetta(id_ricetta: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM ricette WHERE id=%s", (id_ricetta,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Ricetta eliminata"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# --- INTELLIGENZA ARTIFICIALE ---
@app.post("/analizza_documento")
async def analizza_documento(file: UploadFile = File(...)):
    percorso_temp = f"temp_{file.filename}"
    try:
        with open(percorso_temp, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        testo_estratto = ""
        if percorso_temp.lower().endswith('.pdf'):
            with open(percorso_temp, 'rb') as f:
                lettore = PyPDF2.PdfReader(f)
                for pagina in lettore.pages:
                    testo_estratto += pagina.extract_text() + "\n"
        elif percorso_temp.lower().endswith('.docx'):
            documento = docx.Document(percorso_temp)
            testo_estratto = "\n".join([paragrafo.text for paragrafo in documento.paragraphs])
        else:
            os.remove(percorso_temp)
            return {"successo": False, "errore": "Formato non supportato."}

        os.remove(percorso_temp)

        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        istruzioni = """
        Sei il cervello NLP di un gestionale per panifici. 
        Estrai le informazioni tecniche dalla ricetta e restituiscile ESCLUSIVAMENTE in formato JSON puro.
        La struttura esatta DEVE essere questa:
        {
          "nome": "Nome prodotto",
          "resa_quantita": 0.0,
          "resa_unita": "Kg o Pz",
          "lista_ingredienti": [{"nome": "...", "quantita": 0.0, "unita": "g, Kg, ml, L o Pz"}],
          "lista_fasi": [{"nome_fase": "...", "macchinario": "...", "tempo_minuti": 0}]
        }
        """
        configurazione = types.GenerateContentConfig(
            system_instruction=istruzioni,
            response_mime_type="application/json",
            temperature=0.1
        )
        
        risposta = client.models.generate_content(
            model='gemini-3.6-flash',
            contents=testo_estratto,
            config=configurazione
        )
        
        testo_pulito = risposta.text.strip()
        if testo_pulito.startswith("```"):
            testo_pulito = "\n".join(testo_pulito.split("\n")[1:-1])
            
        dati_estratti = json.loads(testo_pulito)

        conn = get_db_connection()
        cursor = conn.cursor()
        nome_ricetta = dati_estratti.get('nome', 'Ricetta da Documento')
        try:
            resa_kg = float(dati_estratti.get('resa_quantita', 0.0))
        except ValueError:
            resa_kg = 0.0
            
        query = "INSERT INTO ricette (nome_ricetta, resa_kg, dati_json) VALUES (%s, %s, %s)"
        valori = (nome_ricetta, resa_kg, json.dumps(dati_estratti))
        cursor.execute(query, valori)
        conn.commit()
        nuovo_id = cursor.lastrowid
        cursor.close()
        conn.close()
        dati_estratti['id'] = nuovo_id

        return {"successo": True, "messaggio": "Salvata nel DB!", "dati_ia": dati_estratti}

    except Exception as e:
        if os.path.exists(percorso_temp):
            os.remove(percorso_temp)
        return {"successo": False, "errore": str(e)}

# --- MACCHINARI CRUD (Create, Read, Update, Delete) ---
@app.get("/macchinari")
def ottieni_macchinari():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True) 
        cursor.execute("SELECT id, nome, tipo, IFNULL(capacita_teglie, 0) AS capacita FROM macchinari")
        lista_macchinari = cursor.fetchall()
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista_macchinari}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.post("/macchinari")
def aggiungi_macchinario(macchina: MacchinarioDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "INSERT INTO macchinari (nome, tipo, capacita_teglie) VALUES (%s, %s, %s)"
        cursor.execute(query, (macchina.nome, macchina.tipo, macchina.capacita))
        conn.commit()
        nuovo_id = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Macchinario aggiunto", "id": nuovo_id}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.put("/macchinari/{id_macchina}")
def modifica_macchinario(id_macchina: int, macchina: MacchinarioDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "UPDATE macchinari SET nome=%s, tipo=%s, capacita_teglie=%s WHERE id=%s"
        cursor.execute(query, (macchina.nome, macchina.tipo, macchina.capacita, id_macchina))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Macchinario aggiornato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.delete("/macchinari/{id_macchina}")
def elimina_macchinario(id_macchina: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "DELETE FROM macchinari WHERE id=%s"
        cursor.execute(query, (id_macchina,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Macchinario eliminato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}
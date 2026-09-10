import json 
import os
import mysql.connector
from fastapi import FastAPI
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from datetime import date, time
from fastapi import File, UploadFile
import shutil
import PyPDF2
import docx
from google import genai
from google.genai import types
from fastapi.middleware.cors import CORSMiddleware 
from typing import Optional
import requests 

# 1. Carichiamo le password
load_dotenv()

app = FastAPI(title="API Panificio IA")

# 2. CORS per permettere la connessione
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- MODELLI DATI ---
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
    dipendente: Optional[str] = Field(default="")
    ruolo_dipendente: Optional[str] = Field(default="")
    cliente: Optional[str] = Field(default="")
    orario: str

class RicettaDati(BaseModel):
    nome_ricetta: str
    resa_kg: float
    dati_json: dict

# --- CONNESSIONE DB ---
def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD"),
        database="panificio_db" 
    )

# ==========================================
# ORDINI
# ==========================================
@app.get("/ordini")
def ottieni_ordini():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        query = """
            SELECT 
                o.id, 
                o.cliente, 
                o.quantita_kg AS kg, 
                o.orario_consegna AS orario, 
                o.stato, 
                r.nome_ricetta AS prodotto
            FROM ordini o
            LEFT JOIN ricette r ON o.ricetta_id = r.id
        """
        cursor.execute(query)
        lista_ordini = cursor.fetchall()
        
        for ordine in lista_ordini:
            if ordine['orario']:
                ordine['orario'] = str(ordine['orario'])[:5] 
                
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista_ordini}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.post("/ordini")
def salva_ordine(ordine: NuovoOrdine):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Controllo di sicurezza: verifichiamo che la ricetta esista!
        cursor.execute("SELECT id FROM ricette WHERE id = %s", (ordine.ricetta_id,))
        if not cursor.fetchone():
            return {"successo": False, "errore": f"La ricetta con ID {ordine.ricetta_id} non esiste. Vai prima nella sezione Ricette e creane una!"}

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

@app.put("/ordini/{id_ordine}")
def modifica_ordine(id_ordine: int, ordine: NuovoOrdine):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = """
            UPDATE ordini 
            SET cliente=%s, ricetta_id=%s, quantita_kg=%s, data_consegna=%s, orario_consegna=%s 
            WHERE id=%s
        """
        cursor.execute(query, (ordine.cliente, ordine.ricetta_id, ordine.quantita_kg, ordine.data_consegna, ordine.orario_consegna, id_ordine))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Ordine aggiornato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.delete("/ordini/{id_ordine}")
def elimina_ordine(id_ordine: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM ordini WHERE id=%s", (id_ordine,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Ordine eliminato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}
# ==========================================
# DIPENDENTI
# ==========================================
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
# TURNI CALENDARIO
# ==========================================
@app.get("/turni")
def ottieni_turni():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM turni_calendario")
        lista_turni = cursor.fetchall()
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
        query = "INSERT INTO turni_calendario (data_turno, tipo, dipendente, ruolo_dipendente, cliente, orario) VALUES (%s, %s, %s, %s, %s, %s)"
        cursor.execute(query, (turno.data_turno, turno.tipo, turno.dipendente, turno.ruolo_dipendente, turno.cliente, turno.orario))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Turno salvato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.put("/turni/{id_turno}")
def modifica_turno(id_turno: int, turno: TurnoDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "UPDATE turni_calendario SET data_turno=%s, tipo=%s, dipendente=%s, ruolo_dipendente=%s, cliente=%s, orario=%s WHERE id=%s"
        cursor.execute(query, (turno.data_turno, turno.tipo, turno.dipendente, turno.ruolo_dipendente, turno.cliente, turno.orario, id_turno))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Turno aggiornato"}
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

# ==========================================
# RICETTE E IA
# ==========================================
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

@app.post("/ricette")
def aggiungi_ricetta(ricetta: RicettaDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "INSERT INTO ricette (nome_ricetta, resa_kg, dati_json) VALUES (%s, %s, %s)"
        cursor.execute(query, (ricetta.nome_ricetta, ricetta.resa_kg, json.dumps(ricetta.dati_json)))
        conn.commit()
        nuovo_id = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Ricetta aggiunta", "id": nuovo_id}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

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

@app.post("/analizza_documento")
async def analizza_documento(file: UploadFile = File(...)):
    percorso_temp = f"temp_{file.filename}"
    try:
        # 1. Salvataggio e lettura (Uguale a prima)
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

        # 2. IL NUOVO PROMPT "MASTRO PANETTIERE" SEVERO
        istruzioni = f"""
        Sei il cervello NLP di un gestionale per panifici. Leggi la seguente ricetta.
        
        REGOLE FERREE:
        1. Quantità: Usa SOLO numeri (es. 500, 1.5). Non scrivere lettere nella quantità.
        2. Macchinari: Per "macchinario" DEVI usare ESCLUSIVAMENTE uno di questi: "Impastatrice a spirale", "Forno a piani", "Cella di lievitazione", "Banco di lavoro".
        
        Testo ricetta:
        {testo_estratto}
        
        Devi restituire ESCLUSIVAMENTE questo formato JSON (compilato con i dati trovati):
        {{
          "nome": "Nome prodotto",
          "resa_quantita": 0.0,
          "resa_unita": "Kg o Pz",
          "lista_ingredienti": [{{"nome": "...", "quantita": 0.0, "unita": "g, Kg, ml, L o Pz"}}],
          "lista_fasi": [{{"nome_fase": "...", "macchinario": "...", "tempo_minuti": 0}}]
        }}
        """

        # 3. CHIAMIAMO LA TUA IA LOCALE (OLLAMA)
        url_ollama = "http://localhost:11434/api/generate"
        payload = {
            "model": "llama3",
            "prompt": istruzioni,
            "format": "json", # LA MAGIA: Questo obbliga l'IA a restituire SOLO dati Json perfetti!
            "stream": False
        }
        
        risposta_locale = requests.post(url_ollama, json=payload)
        dati_risposta = risposta_locale.json()
        
        testo_pulito = dati_risposta.get("response", "").strip()
        
        # Pulizia extra
        if testo_pulito.startswith("```"):
            testo_pulito = "\n".join(testo_pulito.split("\n")[1:-1])
            
        dati_estratti = json.loads(testo_pulito)

        # 4. SALVATAGGIO DIRETTO IN MYSQL (Identico alla versione precedente)
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

        return {"successo": True, "messaggio": "Salvata nel DB con Llama 3!", "dati_ia": dati_estratti}

    except Exception as e:
        if os.path.exists(percorso_temp):
            os.remove(percorso_temp)
        return {"successo": False, "errore": str(e)}

# ==========================================
# MACCHINARI
# ==========================================
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
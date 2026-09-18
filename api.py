import json 
import os
import mysql.connector
from fastapi import FastAPI, File, UploadFile
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from datetime import date, time, datetime
import shutil
import PyPDF2
import docx
from fastapi.middleware.cors import CORSMiddleware 
from typing import Optional
import requests 
import math
from ortools.sat.python import cp_model

# ==========================================
# 1. INIZIALIZZAZIONE E CORS
# ==========================================
load_dotenv()

app = FastAPI(title="API Panificio IA")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# 2. MODELLI DATI
# ==========================================
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

# ==========================================
# 3. CONNESSIONE DB
# ==========================================
def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD"),
        database="panificio_db" 
    )

# ==========================================
# 4. API: ORDINI
# ==========================================
@app.get("/ordini")
def ottieni_ordini():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        query = """
            SELECT 
                o.id, o.cliente, o.quantita_kg AS kg, o.orario_consegna AS orario, 
                o.stato, r.nome_ricetta AS prodotto
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
        cursor.execute("SELECT id FROM ricette WHERE id = %s", (ordine.ricetta_id,))
        if not cursor.fetchone():
            return {"successo": False, "errore": "Ricetta non trovata."}

        query = "INSERT INTO ordini (cliente, ricetta_id, quantita_kg, data_consegna, orario_consegna, stato) VALUES (%s, %s, %s, %s, %s, 'in_attesa')"
        cursor.execute(query, (ordine.cliente, ordine.ricetta_id, ordine.quantita_kg, ordine.data_consegna, ordine.orario_consegna))
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
        query = "UPDATE ordini SET cliente=%s, ricetta_id=%s, quantita_kg=%s, data_consegna=%s, orario_consegna=%s WHERE id=%s"
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
# 5. API: DIPENDENTI E TURNI
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
        cursor.execute("DELETE FROM dipendenti WHERE id=%s", (id_dipendente,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Dipendente eliminato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

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
        data_mysql = turno.data_turno
        if "/" in data_mysql:
            try:
                dt = datetime.strptime(data_mysql, "%m/%d/%Y")
                data_mysql = dt.strftime("%Y-%m-%d")
            except ValueError:
                try:
                    dt = datetime.strptime(data_mysql, "%d/%m/%Y")
                    data_mysql = dt.strftime("%Y-%m-%d")
                except ValueError:
                    pass
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "INSERT INTO turni_calendario (data_turno, tipo, dipendente, ruolo_dipendente, cliente, orario) VALUES (%s, %s, %s, %s, %s, %s)"
        cursor.execute(query, (data_mysql, turno.tipo, turno.dipendente, turno.ruolo_dipendente, turno.cliente, turno.orario))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Turno salvato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

@app.put("/turni/{id_turno}")
def modifica_turno(id_turno: int, turno: TurnoDati):
    try:
        data_mysql = turno.data_turno
        if "/" in data_mysql:
            try:
                dt = datetime.strptime(data_mysql, "%m/%d/%Y")
                data_mysql = dt.strftime("%Y-%m-%d")
            except ValueError:
                try:
                    dt = datetime.strptime(data_mysql, "%d/%m/%Y")
                    data_mysql = dt.strftime("%Y-%m-%d")
                except ValueError:
                    pass
        conn = get_db_connection()
        cursor = conn.cursor()
        query = "UPDATE turni_calendario SET data_turno=%s, tipo=%s, dipendente=%s, ruolo_dipendente=%s, cliente=%s, orario=%s WHERE id=%s"
        cursor.execute(query, (data_mysql, turno.tipo, turno.dipendente, turno.ruolo_dipendente, turno.cliente, turno.orario, id_turno))
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
# 6. API: MACCHINARI
# ==========================================
@app.get("/macchinari")
def ottieni_macchinari():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True) 
        cursor.execute("SELECT id, nome, tipo, IFNULL(capacita_teglie, 999) AS capacita FROM macchinari")
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
        cursor.execute("DELETE FROM macchinari WHERE id=%s", (id_macchina,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Macchinario eliminato"}
    except Exception as e:
        return {"successo": False, "errore": str(e)}

# ==========================================
# 7. API: RICETTE E AGENTE NLP
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

        istruzioni = f"""
        Sei il cervello NLP di un gestionale per panifici. Leggi la seguente ricetta.
        
        REGOLE FERREE:
        1. Quantità: Usa SOLO numeri (es. 500, 1.5). Non scrivere lettere nella quantità.
        2. Macchinari: Per "macchinario" DEVI usare ESCLUSIVAMENTE uno di questi: "Impastatrice a spirale", "Forno a piani", "Cella di lievitazione", "Banco di lavoro".
        
        Testo ricetta:
        {testo_estratto}
        
        Devi restituire ESCLUSIVAMENTE questo formato JSON:
        {{
          "nome": "Nome prodotto",
          "resa_quantita": 0.0,
          "resa_unita": "Kg o Pz",
          "lista_ingredienti": [{{"nome": "...", "quantita": 0.0, "unita": "g, Kg, ml, L o Pz"}}],
          "lista_fasi": [{{"nome_fase": "...", "macchinario": "...", "tempo_minuti": 0}}]
        }}
        """

        url_ollama = "http://localhost:11434/api/generate"
        payload = {
            "model": "llama3", 
            "prompt": istruzioni,
            "format": "json", 
            "stream": False
        }
        
        risposta_locale = requests.post(url_ollama, json=payload)
        dati_risposta = risposta_locale.json()
        
        testo_pulito = dati_risposta.get("response", "").strip()
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
        cursor.execute(query, (nome_ricetta, resa_kg, json.dumps(dati_estratti)))
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
# 8. IL PULSANTE MAGICO: SCHEDULATORE (UNIONE ORDINI E TEAM LIQUIDO)
# ==========================================
@app.post("/calcola_turni")
def calcola_turni():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT o.id, o.quantita_kg, o.orario_consegna, r.id as ricetta_id, r.nome_ricetta, r.resa_kg, r.dati_json
            FROM ordini o 
            JOIN ricette r ON o.ricetta_id = r.id
            WHERE o.stato = 'in_attesa' AND o.data_consegna = CURDATE() + INTERVAL 1 DAY
        """)
        ordini_domani = cursor.fetchall()
        
        if not ordini_domani:
            return {"successo": True, "messaggio": "Nessun ordine per domani. Il panificio può riposare!", "tabella": []}

        cursor.execute("SELECT nome, IFNULL(capacita_teglie, 999) as capacita FROM macchinari")
        macchinari_db = cursor.fetchall()
        nomi_macchinari = [m['nome'] for m in macchinari_db]
        
        cursor.execute("SELECT nome, turno_inizio FROM dipendenti")
        dipendenti_db = cursor.fetchall()
        nomi_dipendenti = [row['nome'] for row in dipendenti_db]

        primo_dipendente = dipendenti_db[0] if dipendenti_db else None
        
        if not primo_dipendente or not nomi_dipendenti:
            return {"successo": False, "errore": "Impossibile calcolare: nessun dipendente in turno!"}

        inizio_minuti_assoluti = primo_dipendente['turno_inizio'].total_seconds() // 60

        # --- NOVITÀ: RAGGRUPPAMENTO ORDINI UGUALI ---
        # Se ci sono 3 ordini di Ciabatte alle 06:00, li fonde in un unico calcolo di produzione!
        ordini_raggruppati = {}
        for o in ordini_domani:
            chiave = (o['ricetta_id'], str(o['orario_consegna']))
            if chiave not in ordini_raggruppati:
                ordini_raggruppati[chiave] = {
                    'lista_id': [],
                    'quantita_kg': 0.0,
                    'orario_consegna': o['orario_consegna'],
                    'nome_ricetta': o['nome_ricetta'],
                    'dati_json': o['dati_json']
                }
            ordini_raggruppati[chiave]['quantita_kg'] += float(o['quantita_kg'])
            ordini_raggruppati[chiave]['lista_id'].append(o['id'])

        # --- TRADUZIONE IN BATCH (Infornate) ---
        tutti_i_task = []
        orizzonte_massimo = 0
        KG_PER_TEGLIA = 2.0 

        for chiave, super_ordine in ordini_raggruppati.items():
            consegna_minuti = super_ordine['orario_consegna'].total_seconds() // 60
            deadline_relativa = int(consegna_minuti - inizio_minuti_assoluti)
            if deadline_relativa > orizzonte_massimo:
                orizzonte_massimo = deadline_relativa
                
            totale_teglie = math.ceil(super_ordine['quantita_kg'] / KG_PER_TEGLIA)

            ricetta = json.loads(super_ordine['dati_json'])
            fasi = ricetta.get('lista_fasi', ricetta.get('fasi', []))
            
            capacita_minima = 999 
            for fase in fasi:
                macchina_req = fase.get('macchinario', fase.get('macchinario_richiesto', 'Banco di lavoro'))
                cap_macchina = 999
                for m in macchinari_db:
                    if m['nome'] == macchina_req:
                        cap_macchina = m['capacita']
                        break
                if cap_macchina < capacita_minima:
                    capacita_minima = cap_macchina

            numero_infornate = math.ceil(totale_teglie / capacita_minima) if capacita_minima > 0 else 1
            
            for i in range(numero_infornate):
                batch = []
                for fase in fasi:
                    nome_fase = f"{super_ordine['nome_ricetta']} (Lotto {i+1}) - {fase.get('nome_fase', 'Lavorazione')}"
                    macchina_req = fase.get('macchinario', fase.get('macchinario_richiesto', 'Banco di lavoro'))
                    durata = int(fase.get('tempo_minuti', 15))
                    # Salviamo la lista degli ID per poterli cancellare tutti insieme alla fine
                    batch.append([nome_fase, macchina_req, durata, super_ordine['lista_id']])
                tutti_i_task.append(batch)

        # --- OR-TOOLS: TEAM LIQUIDO (Tutti fanno tutto) ---
        modello = cp_model.CpModel()
        task_temporali = {}
        task_per_macchina = {macchina: [] for macchina in nomi_macchinari} 
        task_per_dipendente = {dip: [] for dip in nomi_dipendenti}

        for indice_ordine, batch in enumerate(tutti_i_task):
            task_temporali[indice_ordine] = []
            
            for indice_fase, fase in enumerate(batch):
                nome_fase, macchinario, durata, lista_id = fase[0], fase[1], fase[2], fase[3]
                id_task = f"O{indice_ordine}_F{indice_fase}" 
                
                inizio = modello.NewIntVar(0, orizzonte_massimo, f'inizio_{id_task}')
                fine = modello.NewIntVar(0, orizzonte_massimo, f'fine_{id_task}')
                intervallo_macchina = modello.NewIntervalVar(inizio, durata, fine, f'int_macchina_{id_task}')
                
                if macchinario in task_per_macchina:
                    task_per_macchina[macchinario].append(intervallo_macchina)
                    
                assegnamenti_possibili = []
                variabili_assegnazione_dipendente = {} 
                
                # Qualsiasi dipendente libero prende la task
                for nome_dip in nomi_dipendenti:
                    dip_assegnato = modello.NewBoolVar(f'assegnato_{nome_dip}_{id_task}')
                    assegnamenti_possibili.append(dip_assegnato)
                    variabili_assegnazione_dipendente[nome_dip] = dip_assegnato
                    
                    opt_inizio = modello.NewIntVar(0, orizzonte_massimo, f'opt_in_{nome_dip}_{id_task}')
                    opt_fine = modello.NewIntVar(0, orizzonte_massimo, f'opt_fi_{nome_dip}_{id_task}')
                    
                    modello.Add(opt_inizio == inizio).OnlyEnforceIf(dip_assegnato)
                    modello.Add(opt_fine == fine).OnlyEnforceIf(dip_assegnato)
                    
                    intervallo_dip = modello.NewOptionalIntervalVar(opt_inizio, durata, opt_fine, dip_assegnato, f'opt_int_{nome_dip}_{id_task}')
                    task_per_dipendente[nome_dip].append(intervallo_dip)
                    
                modello.AddExactlyOne(assegnamenti_possibili)
                
                task_temporali[indice_ordine].append({
                    'inizio': inizio, 
                    'fine': fine, 
                    'nome': nome_fase, 
                    'macchina': macchinario,
                    'lista_id': lista_id,
                    'variabili_dipendenti': variabili_assegnazione_dipendente 
                })

        for indice_ordine, batch in enumerate(tutti_i_task):
            for i in range(len(batch) - 1):
                modello.Add(task_temporali[indice_ordine][i]['fine'] <= task_temporali[indice_ordine][i+1]['inizio'])

        for macchina, intervalli in task_per_macchina.items():
            if intervalli:
                modello.AddNoOverlap(intervalli)
                
        for dip, intervalli in task_per_dipendente.items():
            if intervalli:
                modello.AddNoOverlap(intervalli)

        fine_tutte_infornate = [task_temporali[i][-1]['fine'] for i in range(len(tutti_i_task))]
        if not fine_tutte_infornate:
            return {"successo": True, "messaggio": "Nessuna infornata da calcolare.", "tabella": []}

        tempo_massimo = modello.NewIntVar(0, orizzonte_massimo, 'tempo_massimo_totale')
        modello.AddMaxEquality(tempo_massimo, fine_tutte_infornate)
        modello.Minimize(tempo_massimo)

        risolutore = cp_model.CpSolver()
        stato = risolutore.Solve(modello)

        # --- OUTPUT: SUCCESSO E CANCELLAZIONE MULTIPLA ---
        if stato == cp_model.OPTIMAL or stato == cp_model.FEASIBLE:
            tabella_finale = []
            ordini_completati = set()
            
            for indice_ordine in range(len(tutti_i_task)):
                for task in task_temporali[indice_ordine]:
                    start_time = risolutore.Value(task['inizio'])
                    end_time = risolutore.Value(task['fine'])
                    
                    dipendente_scelto = "Da Assegnare"
                    for dip, var_assegnazione in task['variabili_dipendenti'].items():
                        if risolutore.Value(var_assegnazione) == 1:
                            dipendente_scelto = dip
                            break
                    
                    tabella_finale.append({
                        "attivita": task['nome'],
                        "macchinario": task['macchina'],
                        "dipendente": dipendente_scelto,
                        "minuto_inizio": start_time,
                        "minuto_fine": end_time
                    })
                    
                    for id_ord in task['lista_id']:
                        ordini_completati.add(id_ord)
            
            for id_ord in ordini_completati:
                cursor.execute("DELETE FROM ordini WHERE id = %s", (id_ord,))
            conn.commit()
            cursor.close()
            conn.close()
            
            return {"successo": True, "messaggio": "Tabella generata! Ordini raggruppati e processati.", "tabella": tabella_finale}
        
        # --- OUTPUT: FALLIMENTO & PROMPT INTELLIGENTE ---
        else:
            # Estraiamo l'ordine più problematico (il primo per semplicità)
            primo_gruppo = list(ordini_raggruppati.values())[0]
            ids_bloccati = primo_gruppo['lista_id']
            
            prompt_generale = f"""
            Sei l'IA gestionale di un panificio. Il sistema matematico si è bloccato per mancanza di tempo.
            
            DATI OPERATIVI (Non inventare nulla):
            - Ordini bloccati: {primo_gruppo['quantita_kg']} Kg di "{primo_gruppo['nome_ricetta']}".
            - Team presente: {len(nomi_dipendenti)} dipendenti che lavorano in modalità "team liquido" (tutti fanno tutto).
            - Macchinari disponibili: {', '.join(nomi_macchinari)}.
            - Scadenza critica: ore {primo_gruppo['orario_consegna']}.
            
            ANALISI:
            La combinazione di {primo_gruppo['quantita_kg']} Kg con questi forni e {len(nomi_dipendenti)} impiegati non è fisicamente calcolabile entro le {primo_gruppo['orario_consegna']}.
            
            AZIONE:
            Decidi un orario di consegna più tardivo e realistico (es. aggiungendo da 2 a 4 ore in base alla mole di Kg indicata) per sbloccare la produzione.
            
            Restituisci ESCLUSIVAMENTE un JSON in questo formato. Niente discorsi, solo codice:
            {{
              "azione_fatta": "Spiega brevemente la tua scelta strategica in italiano",
              "nuovo_orario": "09:00:00"
            }}
            """
            
            try:
                url_ollama = "http://localhost:11434/api/generate"
                payload = {
                    "model": "qwen2.5:1.5b",
                    "prompt": prompt_generale,
                    "format": "json", 
                    "stream": False
                }
                
                risposta_locale = requests.post(url_ollama, json=payload)
                dati_risposta = risposta_locale.json()
                
                testo_json = dati_risposta.get("response", "").strip()
                correzione = json.loads(testo_json)
                
                azione_eseguita = correzione.get('azione_fatta', 'Orario ricalcolato.')
                nuovo_orario = correzione.get('nuovo_orario', '08:00:00')
                
                # Applica il posticipo a TUTTI gli ordini che facevano parte di quel gruppo problematico
                for id_ord in ids_bloccati:
                    cursor.execute(
                        "UPDATE ordini SET orario_consegna = %s WHERE id = %s",
                        (nuovo_orario, id_ord)
                    )
                conn.commit()
                cursor.close()
                conn.close()
                
                # IL FORMATTING E' CORRETTO: Assegniamo la stringa prima di ritornarla
                messaggio_ritorno = f"🤖 Intervento IA: {azione_eseguita} (Dati aggiornati, premi Ricalcola Ora!)"
                
                return {
                    "successo": False, 
                    "messaggio": messaggio_ritorno
                }

            except Exception as e:
                print(f"❌ ERRORE IA LOCALE: {e}")
                return {"successo": False, "errore": str(e)}

    except Exception as e:
        print(f"❌ ERRORE SCHEDULATORE: {e}")
        return {"successo": False, "errore": str(e)}
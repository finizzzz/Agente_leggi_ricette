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
# 4. API: ORDINI, DIPENDENTI, TURNI, MACCHINARI
# ==========================================
# [Tutte le rotte standard CRUD rimangono identiche e sicure]
@app.get("/ordini")
def ottieni_ordini():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT o.id, o.cliente, o.quantita_kg AS kg, o.orario_consegna AS orario, 
                   o.stato, r.nome_ricetta AS prodotto
            FROM ordini o LEFT JOIN ricette r ON o.ricetta_id = r.id
        """)
        lista = cursor.fetchall()
        for o in lista:
            if o['orario']: o['orario'] = str(o['orario'])[:5] 
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.post("/ordini")
def salva_ordine(ordine: NuovoOrdine):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM ricette WHERE id = %s", (ordine.ricetta_id,))
        if not cursor.fetchone(): return {"successo": False, "errore": "Ricetta non trovata."}
        cursor.execute("INSERT INTO ordini (cliente, ricetta_id, quantita_kg, data_consegna, orario_consegna, stato) VALUES (%s, %s, %s, %s, %s, 'in_attesa')", 
                       (ordine.cliente, ordine.ricetta_id, ordine.quantita_kg, ordine.data_consegna, ordine.orario_consegna))
        conn.commit() 
        nid = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": f"Ordine {nid} salvato!"}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.put("/ordini/{id_ordine}")
def modifica_ordine(id_ordine: int, ordine: NuovoOrdine):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE ordini SET cliente=%s, ricetta_id=%s, quantita_kg=%s, data_consegna=%s, orario_consegna=%s WHERE id=%s", 
                       (ordine.cliente, ordine.ricetta_id, ordine.quantita_kg, ordine.data_consegna, ordine.orario_consegna, id_ordine))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Ordine aggiornato"}
    except Exception as e: return {"successo": False, "errore": str(e)}

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
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.get("/dipendenti")
def ottieni_dipendenti():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM dipendenti")
        lista = cursor.fetchall()
        for d in lista:
            d['turno_inizio'] = str(d['turno_inizio'])
            d['turno_fine'] = str(d['turno_fine'])
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.post("/dipendenti")
def aggiungi_dipendente(dipendente: DipendenteDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO dipendenti (nome, ruolo, turno_inizio, turno_fine) VALUES (%s, %s, %s, %s)", 
                       (dipendente.nome, dipendente.ruolo, dipendente.turno_inizio, dipendente.turno_fine))
        conn.commit()
        nid = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "id": nid}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.put("/dipendenti/{id_dipendente}")
def modifica_dipendente(id_dipendente: int, dipendente: DipendenteDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE dipendenti SET nome=%s, ruolo=%s, turno_inizio=%s, turno_fine=%s WHERE id=%s", 
                       (dipendente.nome, dipendente.ruolo, dipendente.turno_inizio, dipendente.turno_fine, id_dipendente))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True, "messaggio": "Aggiornato"}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.delete("/dipendenti/{id_dipendente}")
def elimina_dipendente(id_dipendente: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM dipendenti WHERE id=%s", (id_dipendente,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.get("/turni")
def ottieni_turni():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM turni_calendario")
        lista = cursor.fetchall()
        for t in lista: t['data_turno'] = str(t['data_turno'])
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.post("/turni")
def aggiungi_turno(turno: TurnoDati):
    try:
        data_mysql = turno.data_turno
        if "/" in data_mysql:
            for fmt in ("%m/%d/%Y", "%d/%m/%Y"):
                try:
                    data_mysql = datetime.strptime(data_mysql, fmt).strftime("%Y-%m-%d")
                    break
                except ValueError: pass
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO turni_calendario (data_turno, tipo, dipendente, ruolo_dipendente, cliente, orario) VALUES (%s, %s, %s, %s, %s, %s)", 
                       (data_mysql, turno.tipo, turno.dipendente, turno.ruolo_dipendente, turno.cliente, turno.orario))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.put("/turni/{id_turno}")
def modifica_turno(id_turno: int, turno: TurnoDati):
    try:
        data_mysql = turno.data_turno
        if "/" in data_mysql:
            for fmt in ("%m/%d/%Y", "%d/%m/%Y"):
                try:
                    data_mysql = datetime.strptime(data_mysql, fmt).strftime("%Y-%m-%d")
                    break
                except ValueError: pass
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE turni_calendario SET data_turno=%s, tipo=%s, dipendente=%s, ruolo_dipendente=%s, cliente=%s, orario=%s WHERE id=%s", 
                       (data_mysql, turno.tipo, turno.dipendente, turno.ruolo_dipendente, turno.cliente, turno.orario, id_turno))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.delete("/turni/{id_turno}")
def elimina_turno(id_turno: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM turni_calendario WHERE id=%s", (id_turno,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.get("/macchinari")
def ottieni_macchinari():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True) 
        cursor.execute("SELECT id, nome, tipo, IFNULL(capacita_teglie, 999) AS capacita FROM macchinari")
        lista = cursor.fetchall()
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.post("/macchinari")
def aggiungi_macchinario(macchina: MacchinarioDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO macchinari (nome, tipo, capacita_teglie) VALUES (%s, %s, %s)", 
                       (macchina.nome, macchina.tipo, macchina.capacita))
        conn.commit()
        nid = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "id": nid}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.put("/macchinari/{id_macchina}")
def modifica_macchinario(id_macchina: int, macchina: MacchinarioDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE macchinari SET nome=%s, tipo=%s, capacita_teglie=%s WHERE id=%s", 
                       (macchina.nome, macchina.tipo, macchina.capacita, id_macchina))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.delete("/macchinari/{id_macchina}")
def elimina_macchinario(id_macchina: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM macchinari WHERE id=%s", (id_macchina,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.get("/ricette")
def ottieni_ricette():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM ricette")
        lista = cursor.fetchall()
        for r in lista:
            if isinstance(r['dati_json'], str):
                r['dati_json'] = json.loads(r['dati_json'])
        cursor.close()
        conn.close()
        return {"successo": True, "dati": lista}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.post("/ricette")
def aggiungi_ricetta(ricetta: RicettaDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO ricette (nome_ricetta, resa_kg, dati_json) VALUES (%s, %s, %s)", 
                       (ricetta.nome_ricetta, ricetta.resa_kg, json.dumps(ricetta.dati_json)))
        conn.commit()
        nid = cursor.lastrowid
        cursor.close()
        conn.close()
        return {"successo": True, "id": nid}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.put("/ricette/{id_ricetta}")
def modifica_ricetta(id_ricetta: int, ricetta: RicettaDati):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE ricette SET nome_ricetta=%s, resa_kg=%s, dati_json=%s WHERE id=%s", 
                       (ricetta.nome_ricetta, ricetta.resa_kg, json.dumps(ricetta.dati_json), id_ricetta))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True}
    except Exception as e: return {"successo": False, "errore": str(e)}

@app.delete("/ricette/{id_ricetta}")
def elimina_ricetta(id_ricetta: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM ricette WHERE id=%s", (id_ricetta,))
        conn.commit()
        cursor.close()
        conn.close()
        return {"successo": True}
    except Exception as e: return {"successo": False, "errore": str(e)}


# ==========================================
# 5. AGENTE NLP: LETTORE DI DOCUMENTI POTENZIATO
# ==========================================
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

        # IL NUOVO PROMPT ASSOLUTO: Crea le istruzioni operative per il KDS!
        istruzioni = f"""
        Sei il cervello NLP di un gestionale per panifici. Analizza questa ricetta.
        
        REGOLE FERREE:
        1. Quantità: Usa SOLO numeri. Non scrivere lettere nella quantità.
        2. Macchinari: DEVI usare ESCLUSIVAMENTE uno di questi: "Impastatrice a spirale", "Forno a piani", "Cella di lievitazione", "Banco di lavoro".
        3. DESCRIZIONE OPERATIVA: Questa è la cosa più importante. Per OGNI fase, scrivi una "descrizione_operativa" ricchissima di dettagli. Il panettiere leggerà questa descrizione sul tablet mentre lavora. Deve contenere: quantità di ingredienti da inserire in quella fase specifica, velocità della macchina, temperature, consigli pratici estratti dal testo.
        
        Testo ricetta:
        {testo_estratto}
        
        Devi restituire ESCLUSIVAMENTE un JSON con questa esatta struttura:
        {{
          "nome": "Nome prodotto",
          "resa_quantita": 0.0,
          "resa_unita": "Kg o Pz",
          "lista_ingredienti": [{{"nome": "...", "quantita": 0.0, "unita": "g, Kg, ml, L o Pz"}}],
          "lista_fasi": [
            {{
              "nome_fase": "...", 
              "macchinario": "...", 
              "tempo_minuti": 0,
              "descrizione_operativa": "Testo molto descrittivo per il fornaio. Es: 'Versare 5Kg di farina e 3L di acqua. Azionare la spirale a vel. 1 per 5 min. Temperatura ideale 24°C.'"
            }}
          ]
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

        # Salvataggio diretto
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
# 6. IL PULSANTE MAGICO: SCHEDULATORE (UNIONE ORDINI, TEAM LIQUIDO E ISTRUZIONI)
# ==========================================
@app.post("/calcola_turni")
def calcola_turni():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT o.id, o.quantita_kg, o.orario_consegna, r.id as ricetta_id, r.nome_ricetta, r.resa_kg, r.dati_json
            FROM ordini o JOIN ricette r ON o.ricetta_id = r.id
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

        # RAGGRUPPAMENTO ORDINI UGUALI
        ordini_raggruppati = {}
        for o in ordini_domani:
            chiave = (o['ricetta_id'], str(o['orario_consegna']))
            if chiave not in ordini_raggruppati:
                ordini_raggruppati[chiave] = {
                    'lista_id': [], 'quantita_kg': 0.0,
                    'orario_consegna': o['orario_consegna'],
                    'nome_ricetta': o['nome_ricetta'],
                    'dati_json': o['dati_json']
                }
            ordini_raggruppati[chiave]['quantita_kg'] += float(o['quantita_kg'])
            ordini_raggruppati[chiave]['lista_id'].append(o['id'])

        # TRADUZIONE IN BATCH (Infornate) con TRASPORTO ISTRUZIONI
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
                if cap_macchina < capacita_minima: capacita_minima = cap_macchina

            numero_infornate = math.ceil(totale_teglie / capacita_minima) if capacita_minima > 0 else 1
            
            for i in range(numero_infornate):
                batch = []
                for fase in fasi:
                    nome_fase = f"{super_ordine['nome_ricetta']} (Lotto {i+1}) - {fase.get('nome_fase', 'Lavorazione')}"
                    macchina_req = fase.get('macchinario', fase.get('macchinario_richiesto', 'Banco di lavoro'))
                    durata = int(fase.get('tempo_minuti', 15))
                    # RECUPERIAMO LA DESCRIZIONE OPERATIVA! (Se non c'è, mettiamo un testo di default)
                    descrizione = fase.get('descrizione_operativa', 'Procedere secondo il manuale standard.')
                    
                    batch.append([nome_fase, macchina_req, durata, super_ordine['lista_id'], descrizione])
                tutti_i_task.append(batch)

        # OR-TOOLS: TEAM LIQUIDO 
        modello = cp_model.CpModel()
        task_temporali = {}
        task_per_macchina = {macchina: [] for macchina in nomi_macchinari} 
        task_per_dipendente = {dip: [] for dip in nomi_dipendenti}

        for indice_ordine, batch in enumerate(tutti_i_task):
            task_temporali[indice_ordine] = []
            
            for indice_fase, fase in enumerate(batch):
                nome_fase, macchinario, durata, lista_id, descrizione = fase[0], fase[1], fase[2], fase[3], fase[4]
                id_task = f"O{indice_ordine}_F{indice_fase}" 
                
                inizio = modello.NewIntVar(0, orizzonte_massimo, f'inizio_{id_task}')
                fine = modello.NewIntVar(0, orizzonte_massimo, f'fine_{id_task}')
                intervallo_macchina = modello.NewIntervalVar(inizio, durata, fine, f'int_macchina_{id_task}')
                
                if macchinario in task_per_macchina:
                    task_per_macchina[macchinario].append(intervallo_macchina)
                    
                assegnamenti_possibili = []
                variabili_assegnazione_dipendente = {} 
                
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
                    'descrizione': descrizione, # <--- TRASPORTIAMO LA DESCRIZIONE FINO ALLA FINE!
                    'variabili_dipendenti': variabili_assegnazione_dipendente 
                })

        for indice_ordine, batch in enumerate(tutti_i_task):
            for i in range(len(batch) - 1):
                modello.Add(task_temporali[indice_ordine][i]['fine'] <= task_temporali[indice_ordine][i+1]['inizio'])

        for macchina, intervalli in task_per_macchina.items():
            if intervalli: modello.AddNoOverlap(intervalli)
                
        for dip, intervalli in task_per_dipendente.items():
            if intervalli: modello.AddNoOverlap(intervalli)

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
                        "descrizione_operativa": task['descrizione'], # <--- ECCOLA! PRONTA PER IL TABLET
                        "macchinario": task['macchina'],
                        "dipendente": dipendente_scelto,
                        "minuto_inizio": start_time,
                        "minuto_fine": end_time
                    })
                    for id_ord in task['lista_id']: ordini_completati.add(id_ord)
            
            for id_ord in ordini_completati:
                cursor.execute("DELETE FROM ordini WHERE id = %s", (id_ord,))
            conn.commit()
            cursor.close()
            conn.close()
            
            return {"successo": True, "messaggio": "Tabella generata!", "tabella": tabella_finale}
        
        # --- OUTPUT: FALLIMENTO & PROMPT INTELLIGENTE ---
        else:
            primo_gruppo = list(ordini_raggruppati.values())[0]
            ids_bloccati = primo_gruppo['lista_id']
            
            prompt_generale = f"""
            Sei l'IA gestionale di un panificio. Il sistema matematico si è bloccato per mancanza di tempo.
            DATI: {primo_gruppo['quantita_kg']} Kg di "{primo_gruppo['nome_ricetta']}". {len(nomi_dipendenti)} dipendenti. Macchine: {', '.join(nomi_macchinari)}. Scadenza: ore {primo_gruppo['orario_consegna']}.
            Decidi un orario di consegna realistico per sbloccare la produzione. Restituisci SOLO JSON:
            {{ "azione_fatta": "Spiega la scelta...", "nuovo_orario": "09:00:00" }}
            """
            try:
                url_ollama = "http://localhost:11434/api/generate"
                payload = { "model": "qwen2.5:1.5b", "prompt": prompt_generale, "format": "json", "stream": False }
                risposta_locale = requests.post(url_ollama, json=payload)
                dati_risposta = risposta_locale.json()
                correzione = json.loads(dati_risposta.get("response", "").strip())
                
                azione_eseguita = correzione.get('azione_fatta', 'Orario ricalcolato.')
                nuovo_orario = correzione.get('nuovo_orario', '08:00:00')
                
                for id_ord in ids_bloccati:
                    cursor.execute("UPDATE ordini SET orario_consegna = %s WHERE id = %s", (nuovo_orario, id_ord))
                conn.commit()
                cursor.close()
                conn.close()
                return {"successo": False, "messaggio": f"🤖 Intervento IA: {azione_eseguita} (Dati aggiornati, premi Ricalcola Ora!)"}
            except Exception as e: return {"successo": False, "errore": str(e)}

    except Exception as e: return {"successo": False, "errore": str(e)}
import os
import json
import math
import mysql.connector
from datetime import timedelta
from dotenv import load_dotenv
from google import genai
from ortools.sat.python import cp_model

# --- INIZIALIZZAZIONE ---
load_dotenv()
db_host = os.getenv("DB_HOST", "localhost")
db_user = os.getenv("DB_USER", "root")
db_password = os.getenv("DB_PASSWORD")
mia_chiave = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=mia_chiave)

def get_db_connection():
    return mysql.connector.connect(host=db_host, user=db_user, password=db_password, database="panificio_db")

print("🔄 Avvio Schedulatore: Ricerca ordini per DOMANI in corso...")

try:
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    # 1. Macchinari e Turni (come da prassi)
    cursor.execute("SELECT nome FROM macchinari")
    macchinari = [row['nome'] for row in cursor.fetchall()]

    cursor.execute("SELECT turno_inizio FROM dipendenti LIMIT 1")
    turno_inizio = cursor.fetchone()['turno_inizio']

    # 2. FILTRO: Prendiamo SOLO gli ordini destinati a DOMANI
    cursor.execute("""
        SELECT o.id, o.quantita_kg, o.orario_consegna, r.nome_ricetta, r.resa_kg, r.dati_json
        FROM ordini o 
        JOIN ricette r ON o.ricetta_id = r.id
        WHERE o.stato = 'in_attesa' AND o.data_consegna = CURDATE() + INTERVAL 1 DAY
    """)
    ordini_domani = cursor.fetchall()
    
except Exception as e:
    print(f"❌ Errore Database: {e}")
    exit()

if not ordini_domani:
    print("✅ Nessun ordine in attesa per domani. Il panificio può riposare!")
    exit()

# --- PREPARAZIONE MATEMATICA (Gestiamo il primo ordine per semplicità del test) ---
ordine = ordini_domani[0]
id_ordine = ordine['id']
inizio_minuti = turno_inizio.total_seconds() // 60
consegna_minuti = ordine['orario_consegna'].total_seconds() // 60
orizzonte_temporale = int(consegna_minuti - inizio_minuti)

resa_kg = float(ordine['resa_kg'])
quantita_kg = float(ordine['quantita_kg'])
numero_infornate = math.ceil(quantita_kg / resa_kg)

ricetta = json.loads(ordine['dati_json'])
fasi = ricetta['fasi']

tutti_gli_ordini = []
for i in range(numero_infornate):
    singolo_batch = []
    for fase in fasi:
        singolo_batch.append([f"{fase['nome_fase']} {i+1}", fase['macchinario_richiesto'], int(fase['tempo_minuti'])])
    tutti_gli_ordini.append(singolo_batch)

print(f"📦 Trovato ordine per DOMANI: {quantita_kg} kg di '{ordine['nome_ricetta']}' alle {ordine['orario_consegna']}")

# --- IL MOTORE OR-TOOLS ---
modello = cp_model.CpModel()
task_temporali = {}
task_per_macchina = {macchina: [] for macchina in macchinari}

for indice_ordine, batch in enumerate(tutti_gli_ordini):
    task_temporali[indice_ordine] = []
    for indice_fase, fase in enumerate(batch):
        nome_fase, macchinario, durata = fase[0], fase[1], fase[2]
        inizio = modello.NewIntVar(0, orizzonte_temporale, f'inizio_{nome_fase}')
        fine = modello.NewIntVar(0, orizzonte_temporale, f'fine_{nome_fase}')
        intervallo = modello.NewIntervalVar(inizio, durata, fine, f'intervallo_{nome_fase}')
        task_temporali[indice_ordine].append({'inizio': inizio, 'fine': fine, 'nome': nome_fase, 'macchina': macchinario})
        if macchinario in task_per_macchina:
            task_per_macchina[macchinario].append(intervallo)

for indice_ordine, batch in enumerate(tutti_gli_ordini):
    for i in range(len(batch) - 1):
        modello.Add(task_temporali[indice_ordine][i]['fine'] <= task_temporali[indice_ordine][i+1]['inizio'])

for macchina, intervalli in task_per_macchina.items():
    if intervalli:
        modello.AddNoOverlap(intervalli)

fine_tutte_infornate = [task_temporali[i][-1]['fine'] for i in range(numero_infornate)]
tempo_massimo = modello.NewIntVar(0, orizzonte_temporale, 'tempo_massimo_totale')
modello.AddMaxEquality(tempo_massimo, fine_tutte_infornate)
modello.Minimize(tempo_massimo)

risolutore = cp_model.CpSolver()
stato = risolutore.Solve(modello)

# --- OUTPUT, AUTO-CORREZIONE IA E PULIZIA DB ---
if stato == cp_model.OPTIMAL or stato == cp_model.FEASIBLE:
    print(f"\n✅ TABELLA DI MARCIA OTTIMIZZATA! Lavoro completato in {risolutore.ObjectiveValue()} minuti.")
    
    # PULIZIA: Ordine schedulato, lo eliminiamo!
    try:
        cursor.execute("DELETE FROM ordini WHERE id = %s", (id_ordine,))
        conn.commit()
        print("🗑️ Ordine completato rimosso automaticamente dal Database.")
    except Exception as e:
        print(f"Errore durante l'eliminazione: {e}")
        
else:
    print(f"\n❌ ALLARME: Impossibile completare in {orizzonte_temporale} minuti!")
    print("🤖 Attivazione Agente Autonomo per correggere il database...")
    
    prompt = f"""
    Sei l'IA autonoma del panificio. L'ordine {id_ordine} ({quantita_kg}kg di {ordine['nome_ricetta']}) 
    non può essere completato in {orizzonte_temporale} minuti con le macchine attuali ({', '.join(macchinari)}).
    
    Devi agire sui dati per renderlo fattibile.
    Scegli UNA di queste azioni:
    1. Aumentare il tempo a disposizione posticipando l'orario di consegna di 1 o 2 ore.
    
    Restituisci ESCLUSIVAMENTE un JSON formattato così, senza testo o formattazione markdown attorno:
    {{
      "azione_fatta": "Ho posticipato l'orario di consegna alle 08:00:00 per avere più tempo",
      "nuovo_orario": "08:00:00"
    }}
    """
    try:
        # Usiamo il modello standard per maggiore stabilità
        risposta = client.models.generate_content(model='gemini-1.5-flash', contents=prompt)
        
        # Puliamo la risposta nel caso l'IA aggiunga tag markdown
        testo_json = risposta.text.replace("```json", "").replace("```", "").strip()
        correzione = json.loads(testo_json)
        
        print(f"💡 AZIONE IA ESEGUITA: {correzione['azione_fatta']}")
        
        # L'IA HA DECISO: ORA AGGIORNIAMO IL DATABASE IN AUTOMATICO!
        cursor.execute(
            "UPDATE ordini SET orario_consegna = %s WHERE id = %s",
            (correzione['nuovo_orario'], id_ordine)
        )
        conn.commit()
        print(f"🔄 Database aggiornato! Al prossimo avvio lo schedulatore userà il nuovo orario.")
        
    except Exception as e:
        print(f"Errore IA durante l'auto-correzione: {e}")

cursor.close()
conn.close()
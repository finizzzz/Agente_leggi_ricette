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

print("🔄 Connessione al database in corso per estrarre i dati...")

# --- FASE 1: LETTURA DATI DAL DATABASE (IL PONTE) ---
try:
    conn = mysql.connector.connect(host=db_host, user=db_user, password=db_password, database="panificio_db")
    cursor = conn.cursor(dictionary=True) # Usiamo il dizionario per avere i nomi delle colonne

    # 1. Macchinari disponibili
    cursor.execute("SELECT nome FROM macchinari")
    macchinari = [row['nome'] for row in cursor.fetchall()]

    # 2. Orario inizio turno (Prendiamo il primo panettiere)
    cursor.execute("SELECT turno_inizio FROM dipendenti LIMIT 1")
    turno_inizio = cursor.fetchone()['turno_inizio']

    # 3. Leggiamo il primo ordine in attesa unendolo alla sua ricetta!
    cursor.execute("""
        SELECT o.quantita_kg, o.orario_consegna, r.nome_ricetta, r.resa_kg, r.dati_json
        FROM ordini o 
        JOIN ricette r ON o.ricetta_id = r.id
        WHERE o.stato = 'in_attesa' LIMIT 1
    """)
    ordine = cursor.fetchone()
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"❌ Errore durante la lettura dal Database: {e}")
    exit()

# --- FASE 2: PREPARAZIONE MATEMATICA PER OR-TOOLS ---
# Calcoliamo i minuti disponibili (dall'1:00 alle 6:00 = 300 minuti)
inizio_minuti = turno_inizio.total_seconds() // 60
consegna_minuti = ordine['orario_consegna'].total_seconds() // 60
orizzonte_temporale = int(consegna_minuti - inizio_minuti)

# Calcoliamo quante infornate servono! (Es. 50kg / 8.26kg = 7 infornate arrotondate per eccesso)
resa_kg = float(ordine['resa_kg'])
quantita_kg = float(ordine['quantita_kg'])
numero_infornate = math.ceil(quantita_kg / resa_kg)

# Decodifichiamo il JSON della ricetta estratta dal Primo Cervello
ricetta = json.loads(ordine['dati_json'])
# Decodifichiamo il JSON della ricetta estratta dal Primo Cervello
ricetta = json.loads(ordine['dati_json'])

# ---> INIZIO NUOVO BLOCCO: RICALIBRAZIONE CLIMATICA <---
temperatura_odierna = 30  # Simuliamo una giornata estiva molto calda!

print(f"\n🌡️ Rilevata temperatura laboratorio: {temperatura_odierna}°C")
if temperatura_odierna >= 28:
    print("⚠️ Giornata calda: Ricalibrazione automatica dei tempi di lievitazione (-20%)")
    for fase in ricetta['fasi']:
        # Cerchiamo parole chiave relative al riposo dell'impasto
        nome = fase['nome_fase'].lower()
        if "lievitazione" in nome or "riposo" in nome or "cella" in nome:
            tempo_originale = int(fase['tempo_minuti'])
            # Calcoliamo il nuovo tempo togliendo il 20%
            nuovo_tempo = int(tempo_originale * 0.8)
            fase['tempo_minuti'] = nuovo_tempo
            print(f"  -> {fase['nome_fase']}: tempo ridotto da {tempo_originale} a {nuovo_tempo} minuti.")
print("-" * 40)

# --- RICALIBRAZIONE UMIDITÀ ---
umidita_odierna = 35  # Simuliamo una giornata molto secca (sotto il 40%)

print(f"💧 Rilevata umidità laboratorio: {umidita_odierna}%")
if umidita_odierna < 40:
    print("⚠️ Giornata secca: Ricalibrazione automatica idratazione (+5% acqua)")
    variazione = 1.05
elif umidita_odierna > 70:
    print("⚠️ Giornata umida: Ricalibrazione automatica idratazione (-5% acqua)")
    variazione = 0.95
else:
    variazione = 1.0  # Nessuna modifica

if variazione != 1.0:
    for ingrediente in ricetta['ingredienti']:
        if "acqua" in ingrediente['nome_ingrediente'].lower():
            qta_originale = float(ingrediente['quantita'])
            nuova_qta = round(qta_originale * variazione, 2)
            ingrediente['quantita'] = nuova_qta
            print(f"  -> {ingrediente['nome_ingrediente']}: ricalibrata da {qta_originale} a {nuova_qta} {ingrediente['unita_di_misura']}.")
# ---> FINE NUOVO BLOCCO <---

fasi = ricetta['fasi']

# Moltiplichiamo le fasi per il numero di infornate necessarie
tutti_gli_ordini = []
for i in range(numero_infornate):
    singolo_batch = []
    for fase in fasi:
        # Struttura: [Nome Fase + N. Infornata, Macchinario, Durata]
        singolo_batch.append([f"{fase['nome_fase']} {i+1}", fase['macchinario_richiesto'], int(fase['tempo_minuti'])])
    tutti_gli_ordini.append(singolo_batch)

print(f"\n📦 ORDINE TROVATO: {quantita_kg} kg di '{ordine['nome_ricetta']}'")
print(f"🔁 Calcolo Matematico: Saranno necessarie {numero_infornate} infornate complete (da {resa_kg} kg l'una).")
print(f"⏱️ Tempo a disposizione: {orizzonte_temporale} minuti.\n")

# --- FASE 3: IL MOTORE OR-TOOLS ---
print("🧠 Schedulatore avviato: calcolo della tabella di marcia in corso...")
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

# Vincoli di Sequenza
for indice_ordine, batch in enumerate(tutti_gli_ordini):
    for i in range(len(batch) - 1):
        modello.Add(task_temporali[indice_ordine][i]['fine'] <= task_temporali[indice_ordine][i+1]['inizio'])

# Vincolo: Macchine non sovrapponibili!
for macchina, intervalli in task_per_macchina.items():
    if intervalli:
        modello.AddNoOverlap(intervalli)

# Minimizziamo il tempo totale
fine_tutte_infornate = [task_temporali[i][-1]['fine'] for i in range(numero_infornate)]
tempo_massimo = modello.NewIntVar(0, orizzonte_temporale, 'tempo_massimo_totale')
modello.AddMaxEquality(tempo_massimo, fine_tutte_infornate)
modello.Minimize(tempo_massimo)

# Risolviamo!
risolutore = cp_model.CpSolver()
stato = risolutore.Solve(modello)

# --- FASE 4: OUTPUT E STAFFETTA IA ---
if stato == cp_model.OPTIMAL or stato == cp_model.FEASIBLE:
    print(f"\n✅ OTTIMIZZAZIONE FATTIBILE! Tutto finito entro {risolutore.ObjectiveValue()} minuti.\n")
    # (Potremmo stampare la tabella qui, ma con 7 infornate verrebbe lunghissima!)
else:
    print(f"\n❌ ALLARME: Impossibile completare {numero_infornate} infornate in {orizzonte_temporale} minuti usando le macchine attuali!")
    print("🤖 Invio il rapporto del problema al Consulente IA...\n")
    
    rapporto = f"""
    Sei l'assistente virtuale di un panificio. 
    L'algoritmo ha bloccato la produzione perché il tempo materiale non basta.
    
    DATI PROBLEMA:
    - Ordine richiesto: {quantita_kg} kg di {ordine['nome_ricetta']}.
    - Infornate necessarie: {numero_infornate}.
    - Tempo massimo prima della consegna: {orizzonte_temporale} minuti.
    
    I macchinari ({', '.join(macchinari)}) si accavallerebbero e non c'è fisicamente tempo per cuocere {numero_infornate} batch uno dopo l'altro.
    
    Fornisci al gestore 3 opzioni pratiche, brevi e in elenco puntato per risolvere questa crisi (es. posticipare, chiamare il cliente, usare un pane sostitutivo già pronto).
    Sii molto operativo.
    """
    try:
        risposta = client.models.generate_content(
            model='gemini-3.6-flash',
            contents=rapporto
        )
        print("💡 I CONSIGLI STRATEGICI DEL TUO ASSISTENTE:")
        print(risposta.text)
    except Exception as e:
        print(f"Errore IA: {e}")
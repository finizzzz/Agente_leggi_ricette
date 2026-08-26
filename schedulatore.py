import os
from dotenv import load_dotenv
from google import genai
from ortools.sat.python import cp_model

# --- INIZIALIZZAZIONE IA GEMINI (Il nostro Consulente) ---
load_dotenv()
mia_chiave = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=mia_chiave)

# --- INIZIALIZZAZIONE OR-TOOLS (Il nostro Calcolatore) ---
modello = cp_model.CpModel()

# --- FASE 1 & 2: RISORSE E ORDINI MULTIPLI ---
macchinari = ["Impastatrice_1", "Forno_1"]

ordine_filoni = [
    ["Impasto Filoni", "Impastatrice_1", 15],
    ["Cottura Filoni", "Forno_1", 30]
]
ordine_ciabatte = [
    ["Impasto Ciabatte", "Impastatrice_1", 20],
    ["Cottura Ciabatte", "Forno_1", 25]
]

tutti_gli_ordini = [ordine_filoni, ordine_ciabatte]

# --- FASE 3: I VINCOLI TEMPORALI E FISICI ---
task_temporali = {}
# MANTENIAMO 60 MINUTI PER FORZARE L'ERRORE E TESTARE L'IA
orizzonte_temporale = 60 

task_per_macchina = {macchina: [] for macchina in macchinari}

for indice_ordine, ordine in enumerate(tutti_gli_ordini):
    task_temporali[indice_ordine] = []
    
    for indice_fase, fase in enumerate(ordine):
        nome_fase = fase[0]
        macchinario = fase[1]
        durata = fase[2]
        
        inizio = modello.NewIntVar(0, orizzonte_temporale, f'inizio_{nome_fase}')
        fine = modello.NewIntVar(0, orizzonte_temporale, f'fine_{nome_fase}')
        intervallo = modello.NewIntervalVar(inizio, durata, fine, f'intervallo_{nome_fase}')
        
        task_temporali[indice_ordine].append({'inizio': inizio, 'fine': fine, 'nome': nome_fase, 'macchina': macchinario})
        task_per_macchina[macchinario].append(intervallo)

for indice_ordine, ordine in enumerate(tutti_gli_ordini):
    for i in range(len(ordine) - 1):
        modello.Add(task_temporali[indice_ordine][i]['fine'] <= task_temporali[indice_ordine][i+1]['inizio'])

for macchina, intervalli in task_per_macchina.items():
    modello.AddNoOverlap(intervalli)

# --- FASE 4: SOLUZIONE E STAFFETTA IA ---
fine_filoni = task_temporali[0][-1]['fine']
fine_ciabatte = task_temporali[1][-1]['fine']
tempo_massimo = modello.NewIntVar(0, orizzonte_temporale, 'tempo_massimo_totale')
modello.AddMaxEquality(tempo_massimo, [fine_filoni, fine_ciabatte])
modello.Minimize(tempo_massimo)

risolutore = cp_model.CpSolver()
stato = risolutore.Solve(modello)

if stato == cp_model.OPTIMAL or stato == cp_model.FEASIBLE:
    print(f"\n✅ OTTIMIZZAZIONE FATTIBILE! Tutto finito entro {risolutore.ObjectiveValue()} minuti.\n")
    for indice_ordine, ordine in enumerate(tutti_gli_ordini):
        print(f"--- ORDINE {indice_ordine + 1} ---")
        for fase in task_temporali[indice_ordine]:
            inizio = risolutore.Value(fase['inizio'])
            fine = risolutore.Value(fase['fine'])
            print(f"🕒 Minuto {inizio:02d} al {fine:02d} | {fase['nome']} su {fase['macchina']}")
else:
    print("\n❌ ATTENZIONE: Ordine impossibile da completare con queste risorse e tempi!")
    print("🤖 Invio il problema al Consulente IA per trovare una soluzione...\n")
    
    # Prepariamo il rapporto da inviare a Gemini
    rapporto_emergenza = f"""
    Sei l'assistente virtuale di un panificio. L'algoritmo matematico ha appena bloccato la produzione.
    Problema: Il gestore ha un orario di lavoro rimanente di {orizzonte_temporale} minuti. 
    Deve produrre Filoni e Ciabatte, che richiedono l'uso alternato di {macchinari}.
    Matematicamente è impossibile completare tutto in {orizzonte_temporale} minuti.
    
    Fornisci al gestore 3 opzioni pratiche, brevi e in forma di elenco puntato per risolvere il problema (es. ritardare una consegna, dividere l'ordine, ecc.).
    Sii empatico ma molto operativo.
    """
    
    try:
        # Chiamiamo il nostro "Primo Cervello"
        risposta = client.models.generate_content(
            model='gemini-3.6-flash',
            contents=rapporto_emergenza
        )
        print("💡 I CONSIGLI DEL TUO ASSISTENTE VIRTUALE:")
        print(risposta.text)
    except Exception as e:
        print(f"Errore di connessione all'IA: {e}")
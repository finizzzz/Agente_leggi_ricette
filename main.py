import os
import PyPDF2
import docx # Nuova libreria per i file Word
from dotenv import load_dotenv
from google import genai
from google.genai import types

# 1. CARICAMENTO CHIAVE
load_dotenv()
mia_chiave = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=mia_chiave)

# 2. FUNZIONI DI LETTURA (PDF e DOCX)
def estrai_testo_da_pdf(percorso_file):
    testo = ""
    with open(percorso_file, 'rb') as file:
        lettore = PyPDF2.PdfReader(file)
        for pagina in lettore.pages:
            testo += pagina.extract_text() + "\n"
    return testo

def estrai_testo_da_docx(percorso_file):
    documento = docx.Document(percorso_file)
    testo = "\n".join([paragrafo.text for paragrafo in documento.paragraphs])
    return testo

def leggi_documento(percorso_file):
    try:
        # Controlla l'estensione del file per decidere come leggerlo
        if percorso_file.lower().endswith('.pdf'):
            return estrai_testo_da_pdf(percorso_file)
        elif percorso_file.lower().endswith('.docx'):
            return estrai_testo_da_docx(percorso_file)
        else:
            print("❌ Errore: Formato file non supportato. Usa solo .pdf o .docx")
            return None
    except FileNotFoundError:
        print(f"❌ Errore: Non trovo il file '{percorso_file}'.")
        return None
    except Exception as e:
        print(f"❌ Errore di lettura: {e}")
        return None

# 3. IL NUOVO PROMPT DA "ESPERTO PANETTIERE CON CALCOLO RESA"
istruzioni = """
Sei il cervello NLP di un gestionale per panifici. 
Estrai le informazioni tecniche da questa ricetta e restituiscile ESCLUSIVAMENTE in formato JSON. 
Devi comportarti da mastro panettiere: intuisci il numero di teglie, la temperatura e gli ingredienti.

ATTENZIONE MATEMATICA E RESA: 
1. Calcola il "peso_totale_impasto_crudo_kg" sommando matematicamente il peso di TUTTI gli ingredienti (converti grammi e litri in kg per la somma).
2. Calcola la "resa_prodotto_cotto_kg" sottraendo al peso dell'impasto crudo il 15% di calo peso dovuto all'evaporazione in cottura.

La struttura JSON deve essere ESATTAMENTE questa:
{
  "nome_ricetta": "Nome del prodotto",
  "dettagli_produzione": {
    "peso_totale_impasto_crudo_kg": numero (calcolato da te sommando gli ingredienti),
    "resa_prodotto_cotto_kg": numero (impasto crudo meno 15%),
    "resa_stimata_pezzi": numero intero (es. se la ricetta dice '30 filoni', scrivi 30. Se non c'è, ma sai il peso per pezzo, stimalo calcolando: resa_prodotto_cotto_kg diviso peso_per_pezzo_kg. Altrimenti null),
    "peso_per_pezzo_grammi": numero intero (se indicato nel testo, altrimenti null)
  },
  "ingredienti": [
    {
      "nome_ingrediente": "nome",
      "quantita": numero (usa i decimali se serve),
      "unita_di_misura": "kg, litri, grammi ecc."
    }
  ],
  "fasi": [
    {
      "nome_fase": "Nome dell'azione (es. Impasto, Riposo, Cottura)",
      "macchinario_richiesto": "Nome del macchinario o 'Banco di lavoro'",
      "tempo_minuti": numero intero (converti sempre le ore in minuti),
      "temperatura_gradi": numero intero (solo se è una cottura o una cella, altrimenti null),
      "capacita_teglie_richieste": numero intero (se la ricetta richiede l'uso di teglie, stima quante ne servono, altrimenti null)
    }
  ]
}
"""

# 4. ESECUZIONE
# Qui puoi cambiare il nome del file. Ora accetta sia .pdf che .docx!
nome_file = "ricetta_ciabatta.pdf" 
print(f"📄 Lettura del file '{nome_file}' in corso...")

testo_ricetta = leggi_documento(nome_file)

if testo_ricetta:
    print("⏳ Testo estratto! Inizio analisi avanzata con Gemini 3.6...")
    try:
        configurazione = types.GenerateContentConfig(
            system_instruction=istruzioni,
            response_mime_type="application/json",
            temperature=0.1 # Rendiamo l'IA molto precisa e poco fantasiosa sui numeri
        )
        
        risposta = client.models.generate_content(
            model='gemini-3.6-flash',
            contents=testo_ricetta,
            config=configurazione
        )
        
        print("\n✅ === SCHEDA RICETTA COMPLETA (Pronta per il Database) ===")
        print(risposta.text)
        
    except Exception as e:
        print(f"\n❌ ERRORE IA: {e}")
# Registrazione del calendario

La pagina è `registrazione.html`, collegata da entrambe le versioni del calendario.
La modalità iniziale è **demo**: salvataggio nel solo browser, separato dai dati reali. Non migra automaticamente su Supabase. Gli animali sono segnaposto; non hanno ancora benefici di gioco.

## Collegare Supabase

1. Crea un progetto su Supabase e conserva la password del database privatamente.
2. In Authentication → Sign In / Providers abilita gli accessi anonimi (Allow anonymous sign-ins). Il visitatore non deve inserire email o password: il suo codice personale recupera il profilo su una sessione anonima.
3. Nel SQL Editor esegui una volta `001_profiles.sql`.
4. Da Connect / API Keys copia URL e chiave **publishable** (oppure la precedente chiave **anon**). Non inserire mai `service_role`, `sb_secret_` o password nel sito.
5. Compila `_data/registration.yml`: `mode: supabase`, `supabase_url` e `supabase_publishable_key`. Ricostruisci Jekyll.
6. Prova creazione e rientro da un browser privato; cambio codice; rifiuto del vecchio codice; revoca dell'altro dispositivo dopo il cambio; modifica di nome e animale.

Le tabelle sono in uno schema privato, con RLS e senza accessi diretti pubblici. La funzione esposta usa `auth.uid()` e restituisce solo id, nome, animale e preferenza per la classifica. Il codice, normalizzato senza distinguere maiuscole e minuscole, mantenendo i simboli, viene salvato come SHA-256. Il codice scelto o generato ha esattamente 10 caratteri, con lettere, numeri e simboli ! @ # $ % & * + ? _ -. Non ammette spazi. Il generatore usa casualità crittografica senza distorsioni e include almeno una lettera, un numero e un simbolo. Il codice dà accesso al profilo: chi lo possiede può modificarlo. Non viene mostrato dopo il salvataggio e non è recuperabile se smarrito.

Il codice in chiaro viene conservato nel localStorage solo del browser dell'utente e può essere mostrato nel suo account. L'uscita lo cancella dal dispositivo. Sul database rimane solo l'hash. Non si richiedono email, telefono o nome anagrafico, ma un nome di fantasia. Gli identificativi tecnici necessari alle sessioni sono gestiti da Supabase Auth.

Il cambio codice scollega gli altri dispositivi; l'uscita scollega solo quello attuale. Limite applicativo: 10 tentativi di creazione/recupero/cambio codice ogni 15 minuti per utente anonimo. Questo limite non sostituisce le protezioni antiabuso di Auth: prima dell'apertura pubblica impostare limiti appropriati e valutare CAPTCHA, che richiede un'integrazione aggiuntiva nella pagina. Non eliminare indiscriminatamente gli utenti anonimi da Auth: corrispondono alle sessioni dei partecipanti.

La chiave pubblica è prevista nel browser; le chiavi segrete non servono a questo flusso.

L'header condiviso mostra animale, nome e punteggio del profilo attivo. Si aggiorna anche dopo modifica o uscita e nelle altre schede del browser. Il punteggio parte da zero; la funzione di modifica profilo non consente di impostarlo dal browser. L'assegnazione di punti arriverà con la verifica delle prove giornaliere.

Documentazione: https://supabase.com/docs/guides/auth/auth-anonymous e https://supabase.com/docs/guides/database/functions

## Verifica svolta e limiti

Il flusso demo si può verificare senza un progetto Supabase. Il collegamento remoto e lo script SQL devono ancora essere eseguiti e provati sul progetto reale. Nessun progresso giornaliero viene ancora registrato.

La preferenza show_in_leaderboard è facoltativa, inizialmente disattivata e modificabile nell’account. I profili senza preferenza precedente sono trattati come esclusi. La classifica verrà realizzata con le prove giornaliere e dovrà includere solo i profili che hanno aderito, senza esporre codici o hash.

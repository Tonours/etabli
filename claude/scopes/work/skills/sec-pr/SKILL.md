---
name: sec-pr
description: Verification automatisee d'une PR de securite Dependabot employer (body structure Fixed/Ignored/Deferred/Resolutions). Verifie que les alertes Fixed sont reellement patchees (bump/resolution >= patched version, chaine parente plausible, version saine resolue dans le lockfile via worktree isole), que les resolutions removed sont redondantes, que les justifications Ignored tiennent, surface les Deferred, et confirme la CI verte. Produit un rapport + verdict PASS/FAIL. Si PASS : coche les checkboxes du body, approuve la PR, et affiche le lien pour squash & merge manuel. Ne merge jamais automatiquement. Utiliser quand on demande de verifier/auditer une PR de securite, valider une PR Dependabot, ou /sec-pr <PR_ID>.
---

# sec-pr — Verification de PR de securite Dependabot

Procedure Claude derivee du contrat partage `workflow/skills/sec-pr.md`. Le
contrat fait foi entre runtimes (Pi le lit aussi) ; ce fichier est
l'implementation Claude et peut aller plus loin, jamais a rebours.

Audit complet d'une PR de securite employer (generee par l'outil maison, body
structure en sections **Fixed / Ignored / Deferred / Resolutions added / Resolutions removed**).
Le skill **ne fait jamais confiance au body** : il recoupe chaque affirmation contre des
sources independantes (API Dependabot, advisory GHSA, lockfile resolu reellement).

**Le skill ne merge JAMAIS.** Si l'audit est **PASS**, il coche les checkboxes du body et
approuve la PR, puis affiche le lien pour un **squash & merge manuel**. Si l'audit n'est pas
PASS, il s'arrete au rapport sans aucune action sortante.

## Usage

```
/sec-pr <PR_ID>            # demande le repo
/sec-pr <PR_ID> <owner/repo>
```

Ou en langage naturel : "verifie la PR de securite #1606", "audite la PR Dependabot 1606".

## Prerequis

- `gh` authentifie avec acces aux Dependabot alerts du repo (`gh auth status`).
- Un clone local du repo cible (pour le worktree + install).
- Le gestionnaire de paquets du repo installe (yarn / npm / pnpm).

---

## Phase 0 — Cible

### Repo

Demander via AskUserQuestion (sauf si fourni en argument) :

```
Question: "Sur quel repository se trouve cette PR de securite ?"
Options:
- "frontend (employer/employer)"
- "backend (employer/employer-server)"
- "agent (employer/agent-nodejs)"
- "Autre repo employer"
```

### Clone local

Resoudre le chemin du clone dans cet ordre :

1. **cwd** : si `git -C "$PWD" remote get-url origin` matche `<owner>/<repo>` → utiliser le cwd.
2. Sinon **`~/work/<repo-name>`** (convention locale, ex. `~/work/agent-nodejs`).
3. Sinon **demander le chemin** via AskUserQuestion.

```bash
REPO="employer/<repo>"
REPO_NAME="${REPO##*/}"
ORIGIN="$(git -C "$PWD" remote get-url origin 2>/dev/null)"
case "$ORIGIN" in
  *"$REPO"*) CLONE="$PWD" ;;
  *) [ -d "$HOME/work/$REPO_NAME/.git" ] && CLONE="$HOME/work/$REPO_NAME" ;;
esac
# si $CLONE vide → demander le chemin
```

---

## Phase 1 — Comprehension de la PR

```bash
gh pr view <PR_ID> --repo "$REPO" \
  --json title,body,state,headRefName,baseRefName,url,statusCheckRollup,mergeable

gh pr diff <PR_ID> --repo "$REPO"
```

Du **body**, extraire (pour les recouper ensuite, pas pour les croire) :
- Table **Fixed** : numero d'alerte, package, ecosystem, From→To, severite, type de change (bump direct vs resolution).
- Table **Resolutions added** : pin + chaine parente + fichier + forme (scoped/global).
- Table **Resolutions removed** : entree retiree + version cible annoncee.
- Section **Ignored** : numero d'alerte + justification (preuve citee).
- Section **Deferred** : numeros d'alerte + age annonce.

Du **diff**, noter les changements reels dans `package.json` (deps directes, blocs `resolutions`)
et dans le lockfile (versions resolues, blocs supprimes/fusionnes).

Presenter un resume court : titre, branche, nb d'alertes par section, etat mergeable.

---

## Phase 2 — Sources de verite independantes

Pour **chaque** numero d'alerte des sections Fixed ET Ignored, croiser **deux** sources :

```bash
# 1) Alerte Dependabot du repo
gh api repos/$REPO/dependabot/alerts/<N> --jq '{
  number, state,
  package: .security_vulnerability.package.name,
  severity: .security_vulnerability.severity,
  vulnerable_range: .security_vulnerability.vulnerable_version_range,
  first_patched: .security_vulnerability.first_patched_version.identifier,
  ghsa: .security_advisory.ghsa_id
}'

# 2) Advisory officiel GHSA (source independante de Dependabot)
gh api advisories/<GHSA_ID> --jq '{
  ghsa: .ghsa_id, summary, severity,
  vulnerabilities: [.vulnerabilities[] | {pkg: .package.name, vulnerable: .vulnerable_version_range, patched: .first_patched_version}]
}'
```

Regles :
- La **patched version de reference** = `first_patched_version` de l'alerte Dependabot.
- Confirmer qu'elle **coincide** avec le GHSA (meme package). Si divergence → noter en **À INVESTIGUER**.
- Ignorer la version "To" annoncee dans le body : seule la patched des sources fait foi.
- `state: open` cote Dependabot est **normal** avant merge (Dependabot ferme apres merge sur la base). Ne pas confondre avec un echec.

---

## Phase 3 — Worktree isole + install reel

Toute la verification lockfile se fait dans un **git worktree dedie**, jamais dans le clone actif.

### 3a. Creer le worktree + detecter le gestionnaire de paquets

```bash
BRANCH="<headRefName de la PR>"
WT="$(mktemp -d)/sec-pr-<PR_ID>"

git -C "$CLONE" fetch origin "$BRANCH"
git -C "$CLONE" worktree add "$WT" "origin/$BRANCH"

cd "$WT"
if   [ -f yarn.lock ];          then PM=yarn; LOCK=yarn.lock;            INSTALL="yarn install --frozen-lockfile"; WHY="yarn why";
elif [ -f package-lock.json ];  then PM=npm;  LOCK=package-lock.json;    INSTALL="npm ci"; WHY="npm ls";
elif [ -f pnpm-lock.yaml ];     then PM=pnpm; LOCK=pnpm-lock.yaml;       INSTALL="pnpm install --frozen-lockfile"; WHY="pnpm why";
fi
echo "$WT" > /tmp/sec-pr-wt.txt   # memoriser le chemin entre appels Bash
```

### 3b. Aligner Node + installer — DANS UN SEUL APPEL BASH

> ⚠️ **Critique : nvm ne persiste PAS entre deux appels Bash** (chaque appel = shell neuf).
> `source nvm.sh`, `nvm use` et `$INSTALL` **doivent etre dans le meme bloc**, sinon
> `node --version` retombe sur la version systeme et l'engine echoue a nouveau.
> Idem pour chaque `yarn why` ulterieur : re-sourcer nvm en tete de chaque commande.

L'install echoue souvent sur `engine "node" is incompatible` (ex. `semantic-release@25`
exige `^22.14 || >=24.10`). On **aligne** Node sur l'engine, on ne le contourne pas.

```bash
WT="$(cat /tmp/sec-pr-wt.txt)"; cd "$WT"
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"                 # OBLIGATOIRE en tete de bloc

if [ -f .nvmrc ]; then
  nvm install && nvm use           # respecte .nvmrc (cas employer standard)
else
  # engines.node racine = souvent un range. Prendre la 1re X.Y.Z satisfaisante.
  NODE_REQ="$(node -p "require('./package.json').engines?.node || ''" 2>/dev/null)"
  NODE_PIN="$(printf '%s' "$NODE_REQ" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [ -n "$NODE_PIN" ] && nvm install "$NODE_PIN" && nvm use "$NODE_PIN"
fi

node --version                     # tracer la version effective
$INSTALL                           # install gele, dans le MEME shell
echo "INSTALL_EXIT=$?"             # <-- le verdict d'install se lit ICI, pas dans les logs
```

> nvm absent (`nvm.sh` introuvable) : ne pas bloquer. Tenter `$INSTALL` tel quel ;
> si echec sur l'engine → fallback statique (ci-dessous).

### 3c. Juger le succes de l'install — sur l'EXIT CODE, pas sur les logs

> ⚠️ Un `yarn install` peut **afficher des erreurs et reussir quand meme**. Cas observe :
> module natif **optionnel** (`cpu-features` / node-gyp) qui echoue a compiler — yarn
> imprime `error ... node-gyp` PUIS `info This module is OPTIONAL, you can safely ignore`
> PUIS `Done in Ns`. **Ce n'est PAS un echec.**
>
> Regle : l'install est **reussie** si `INSTALL_EXIT == 0` ET `node_modules/` existe et est peuple.
> Ne jamais conclure "install echouee" sur la seule presence du mot `error` dans la sortie.

```bash
WT="$(cat /tmp/sec-pr-wt.txt)"; cd "$WT"
[ -d node_modules ] && [ "$(ls -A node_modules | head -1)" ] && echo "node_modules OK" || echo "node_modules ABSENT/vide"
```

### 3d. Fallback statique (seulement si install vraiment KO)

> Si `INSTALL_EXIT != 0` (hors module optionnel) ou `node_modules` absent — lockfile non gele,
> registry indispo, env incomplet : ne pas bloquer tout l'audit. Basculer sur une verification
> **statique du `$LOCK`** (grep des blocs) et marquer ces points "verifie statiquement, install non rejoue".
> Ne **jamais** utiliser `--ignore-engines` : on aligne Node, on ne contourne pas l'engine.

### Nettoyage obligatoire en fin de run (meme en cas d'erreur)

```bash
git -C "$CLONE" worktree remove --force "$WT"
rm -f /tmp/sec-pr-wt.txt
```

---

## Phase 4 — Verifier les "Fixed"

Pour chaque alerte Fixed :

1. **Diff** : confirmer que le `package.json` (dep directe) ou le bloc `resolutions` bumpe
   vers une version/un pin **>= patched** (Phase 2).
2. **Resolution scoped** : pour les deps transitives, verifier que le pin satisfait la patched
   (ex. `fast-uri: ^3.1.2` >= patched `3.1.2` et `3.1.1`).
3. **Lockfile resolu** (dans le worktree) : confirmer la **version reellement resolue** >= patched.

```bash
# rappel : re-sourcer nvm pour que yarn why tourne sous le bon Node
WT="$(cat /tmp/sec-pr-wt.txt)"; cd "$WT"; . "$HOME/.nvm/nvm.sh"; nvm use >/dev/null 2>&1
$WHY <package>                 # arbre reel
grep -nE "^<package>@" "$LOCK" # blocs + ranges fusionnes
```

> ⚠️ **Piege de lecture du lockfile.** L'en-tete d'un bloc liste les **cles de range**, pas la
> version resolue. Ex. `ip-address@10.1.0, ^10.0.1, ^10.1.1:` suivi de `version "10.2.0"` →
> la version reellement installee est **10.2.0**, PAS 10.1.0. Toujours lire la ligne
> `version "X.Y.Z"` juste sous l'en-tete (ou la ligne `Found "pkg@X.Y.Z"` de `yarn why`),
> jamais les nombres de l'en-tete.

4. **Chaine parente plausible** : pour une resolution scoped (`**/<parent>/<pkg>`), confirmer
   dans le lock que `<parent>` declare bien une dependance sur `<pkg>` couverte par le pin.
5. **Aucun bloc vulnerable residuel** : verifier qu'il ne reste pas une copie ancienne du
   package a une version dans le range vulnerable.

```bash
# nb de blocs distincts pour le package (idealement fusionnes)
grep -cE "^<package>@" "$LOCK"
# aucune version vulnerable residuelle (adapter le motif a la version vuln)
grep -n "<package>-<version_vuln>" "$LOCK" || echo "aucun residu"
```

Verdict par alerte : **Corrige** si (resolution/diff >= patched) ET (lock resolu >= patched)
ET (chaine parente coherente) ET (aucun residu vulnerable). Sinon **FAIL** ou **À INVESTIGUER**.

---

## Phase 5 — Verifier les "Resolutions removed"

Le body affirme chaque retrait **redondant** : le range naturel resout deja >= la version cible.

Pour chaque entree retiree, **dans le lock du worktree** :

```bash
$WHY <package>
grep -nE "^<package>@" "$LOCK"
```

- Confirmer que `<package>` resout bien **>= la version cible annoncee** (ex. `ip-address >= 10.1.1`,
  `hono >= 4.12.18`, `uuid >= 13.0.1`).
- La preuve de redondance = la branche resout deja a une version saine **sans** l'entree.
  (On ne re-teste pas en retirant l'entree : couteux et inutile, l'entree est deja absente du diff.)

Verdict : **OK** si version resolue >= cible ; sinon **À INVESTIGUER** (le retrait a peut-etre
reintroduit une version basse).

---

## Phase 6 — Ignored (re-verifier la preuve)

Pour chaque alerte Ignored, **reproduire** la preuve citee dans le body plutot que la croire.

Cas typique "chemin de code vulnerable inatteignable" :
- Identifier les methodes/fonctions vulnerables nommees dans l'advisory GHSA (Phase 2).
- Verifier dans le **code source** qu'aucune n'est appelee :

```bash
grep -rnE "<methode_vuln_1>|<methode_vuln_2>" "$CLONE"/packages/*/src "$CLONE"/packages/*/test \
  || echo "aucun appel aux methodes vulnerables"
```

- Verifier aussi l'hypothese de version hoistee si citee (ex. "10.2.0 >= patched 10.1.1") via le lock.

Classer : **justification credible** (preuve reproduite) / **douteuse** (preuve non reproductible → À INVESTIGUER).

---

## Phase 7 — Deferred (surfacer)

Pas de re-verification de fond. Lister les alertes Deferred et **confirmer l'age < 7j** :

```bash
# age en jours = (now - created_at). Ne pas se fier au "Nd" du body (souvent perime).
gh api repos/$REPO/dependabot/alerts/<N> \
  --jq '{number, created_at, package: .security_vulnerability.package.name}'
```

Calculer l'age reel par rapport a la date du jour (donnee en contexte). Signaler — **sans
bloquer le verdict** — toute alerte "deferred" qui a en realite **> 7 jours** : le body a pu
etre redige plusieurs jours avant la review (ex. body annonce "6d" mais l'alerte a 8j au moment
du run → devrait etre traitee au prochain passage). C'est un point de vigilance, pas un FAIL.

---

## Phase 8 — CI

```bash
gh pr view <PR_ID> --repo "$REPO" --json statusCheckRollup
```

- Tous les checks pertinents (lint, build, tests par package) doivent etre `SUCCESS`.
- `SKIPPED` sur Release/Publish/Macroscope est **normal** sur une PR de securite.
- Tout `FAILURE`/`PENDING` non explique → bloque le verdict global.

---

## Phase 9 — Rapport & verdict

Sortie conversationnelle uniquement (pas de fichier). Structure :

```markdown
## Verification PR #<ID> — <titre>

### CI
<verte / details des checks en echec>

### Fixed
| Alerte | Pkg | Patched (Dependabot/GHSA) | Action PR | Lock resolu | Chaine parente | Verdict |
|---|---|---|---|---|---|---|
| #N | ws | 8.20.1 / 8.20.1 | dep ^8.20.1 | 8.21.0 | n/a (directe) | ✅ Corrige |
| ... |

### Resolutions added
<pin / parent confirme dans le lock / verdict>

### Resolutions removed
| Entree retiree | Version cible | Version resolue | Verdict |
|---|---|---|---|
| **/socks/ip-address | 10.1.1 | 10.2.0 | ✅ redondant |

### Ignored
<alerte / preuve reproduite / credible|douteuse>

### Deferred
<liste + age confirme>

### Verdict global : PASS | FAIL | À INVESTIGUER
<1-2 phrases : la PR est-elle mergeable ? Quels points humains restent ?>
```

Regles de verdict :
- **PASS** : toutes les Fixed corrigees (lock resolu >= patched, parents coherents, zero residu),
  resolutions removed confirmees redondantes, Ignored credibles, CI verte.
- **FAIL** : au moins une Fixed non corrigee (lock < patched, ou residu vulnerable), ou CI en echec.
- **À INVESTIGUER** : divergence de sources, preuve Ignored non reproductible, ou install non rejouable.

---

## Phase 10 — Actions post-validation (UNIQUEMENT si verdict == PASS)

> Si le verdict est **FAIL** ou **À INVESTIGUER** : **n'executer AUCUNE** de ces actions.
> Presenter le rapport et s'arreter. Les actions ci-dessous supposent un audit 100% PASS.

Ordre strict : (1) cocher les cases du body → (2) approuver → (3) afficher le lien. **Jamais de merge.**

### 10.1 — Cocher toutes les checkboxes des tables du body

Les tables du body contiennent des cases `- [ ]` (colonnes **Done** / **Dismissed**).
Une fois tout valide, les passer a `- [x]` et reposter le body.

```bash
# recuperer le body brut
BODY="$(gh pr view <PR_ID> --repo "$REPO" --json body --jq .body)"
# cocher toutes les cases non cochees (gere "- [ ]" et "[ ]" en cellule de table)
CHECKED="$(printf '%s' "$BODY" | sed -E 's/- \[ \]/- [x]/g; s/\| \[ \] \|/| [x] |/g')"
# verifier le diff avant d'envoyer
diff <(printf '%s' "$BODY") <(printf '%s' "$CHECKED")
# reposter
printf '%s' "$CHECKED" | gh pr edit <PR_ID> --repo "$REPO" --body-file -
```

> Ne cocher QUE les cases des tables Fixed/Ignored (et autres tables du body). Ne pas inventer
> de contenu, ne pas toucher au reste du markdown. Verifier le `diff` avant le `gh pr edit`.

### 10.2 — Approuver la PR (sans commentaire)

```bash
gh pr review <PR_ID> --repo "$REPO" --approve
```

### 10.3 — Afficher le lien pour squash & merge manuel

Le merge reste **manuel et humain**. Afficher clairement l'URL :

```
✅ PR auditee PASS, cases cochees, approuvee.
👉 Squash & merge manuel : <url de la PR>
```

> Demander confirmation a l'utilisateur **avant** 10.1/10.2 si le contexte de permissions
> l'exige (ces deux etapes sont des actions sortantes qui modifient la PR sur GitHub).

---

## Principes

1. **Zero confiance dans le body** — chaque affirmation est recoupee contre Dependabot + GHSA + lock reel.
2. **Isolation** — worktree dedie, nettoye ; jamais de mutation du clone actif.
3. **Preuve > assertion** — pour Ignored, reproduire le grep ; pour Fixed, lire le lock resolu.
4. **`state: open` n'est pas un echec** — Dependabot ferme apres merge.
5. **Actions sortantes seulement si PASS** — cocher + approuver uniquement apres audit complet vert.
6. **Jamais de merge automatique** — le squash & merge reste une action humaine ; le skill s'arrete au lien.
5. **Read-only sortant** — aucune action sur la PR ni le remote.

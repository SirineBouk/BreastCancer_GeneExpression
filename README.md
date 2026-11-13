# Analyse de l'expression génétique dans le cancer du sein

## 1. Présentation du projet

Ce projet a pour objectif d'identifier les gènes dont les niveaux d'expression diffèrent de manière statistiquement significative entre les tissus mammaires tumoraux et les tissus mammaires normaux.

L'analyse repose sur le jeu de données GSE15852, disponible dans la base de données GEO (Gene Expression Omnibus) du NCBI.

Le projet est réalisé dans le cadre du module de programmation système. Un pipeline automatisé, développé en Bash et Python, permet de télécharger les données, de les préparer, d'effectuer l'analyse statistique et de produire les résultats.

## 2. Question de recherche

Quels gènes présentent des niveaux d'expression différents entre les tissus mammaires tumoraux et les tissus mammaires normaux dans cette étude ?

L'objectif est de comparer les profils d'expression des deux types de tissus afin d'identifier les gènes présentant des différences significatives.

## 3. Jeu de données

Le jeu de données utilisé est **GSE15852**, intitulé :

*Expression data from human breast tumors and their paired normal tissues.*

Il est disponible sur la plateforme GEO du NCBI :

https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE15852

Informations principales :

- Identifiant GEO : GSE15852
- Organisme : Homo sapiens
- Maladie étudiée : cancer du sein
- Plateforme : GPL96 — Affymetrix Human Genome U133A Array
- Nombre d'échantillons : 86
- Échantillons tumoraux : 43
- Échantillons normaux : 43
- Organisation : 43 paires de tissus tumoraux et normaux provenant des mêmes patients.

Le jeu de données comprend une archive de données brutes ainsi que des valeurs d'expression déjà traitées fournies par GEO.

**Remarque sur les données :** le pipeline utilise les valeurs d'expression traitées disponibles sur GEO pour l'analyse statistique. Il ne réalise pas une nouvelle normalisation RMA à partir des fichiers CEL. Les fichiers bruts sont téléchargés et extraits dans le cadre de la gestion des données du projet.

## 4. Organisation du dépôt

L'organisation du projet est la suivante :

```
BreastCancer_GeneExpression/
│
├── run.sh                  # Lance le pipeline
│
├── config/
│   └── config.sh           # Paramètres du projet
│
├── scripts/
│   ├── setup.sh            # Prépare l'environnement
│   ├── download.sh         # Télécharge les données
│   ├── extract.sh          # Extrait les données
│   ├── prepare_data.sh     # Prépare les données
│   ├── analyze.py          # Analyse les données
│   ├── validate.sh         # Vérifie les résultats
│   └── archive.sh          # Archive les résultats
│
├── tests/
│   └── test_analysis.py    # Tests de l'analyse
│
├── cron/
│   └── projet_maladie.cron # Tâche planifiée
│
├── requirements.txt        # Dépendances Python
├── SOURCES.md              # Sources des données
├── README.md               # Guide du projet
├── LIEN_GIT.txt            # Lien Git et commit final
└── .gitignore              # Fichiers ignorés par Git
```

Certains dossiers sont créés automatiquement pendant l'exécution du pipeline :

- `data/` : contient les données téléchargées, extraites et préparées.
- `results/` : contient les tableaux, les figures et les archives des résultats.
- `logs/` : contient les journaux d'exécution.

Les données volumineuses et les fichiers générés ne sont pas inclus dans le dépôt Git. Ils sont créés localement lors de l'exécution du pipeline.

## 5. Prérequis

Le projet est destiné à être exécuté dans un environnement Linux, notamment Ubuntu.

Les outils nécessaires sont :

- Bash
- Python 3
- pip
- curl ou wget
- tar
- gzip
- sha256sum
- Les commandes standard Linux utilisées par les scripts : grep, sed, awk, cut, sort et uniq.

Git est également nécessaire pour récupérer le dépôt.

Les bibliothèques Python utilisées sont indiquées dans `requirements.txt`.

## 6. Installation

### 6.1. Récupération du projet

Cloner le dépôt :

```
git clone https://github.com/SirineBouk/BreastCancer_GeneExpression.git
```

Entrer dans le dossier du projet :

```
cd BreastCancer_GeneExpression
```

### 6.2. Installation des prérequis système

Avant d'exécuter le pipeline, installer les outils nécessaires sur Ubuntu :

```
sudo apt update
sudo apt install bash python3 python3-venv python3-pip curl tar gzip coreutils grep sed gawk git
```

Ces outils sont nécessaires pour :

- `bash` : exécuter les scripts shell.
    
- `python3` : exécuter les scripts Python.
    
- `python3-venv` : créer l'environnement virtuel `.venv`.
    
- `python3-pip` : installer les bibliothèques Python.
    
- `curl` : télécharger les données GEO.
    
- `git` : cloner le dépôt du projet.
    
- `tar` et `gzip` : extraire les archives téléchargées.
    
- `coreutils` : fournir notamment `sha256sum`, `cut`, `sort` et `uniq`.
    
- `grep`, `sed` et `gawk` : effectuer les opérations de traitement de texte utilisées par les scripts.
    

Les commandes système nécessaires sont vérifiées automatiquement par le script `setup.sh` avant le lancement du pipeline.

### 6.3. Configuration de l'environnement Python

Le projet utilise un environnement virtuel Python nommé `.venv`.

Lors de l'exécution normale du pipeline, les opérations suivantes sont effectuées automatiquement :

1. Vérification de la disponibilité de Python 3 et de `venv`.
    
2. Création de l'environnement virtuel `.venv` s'il n'existe pas.
    
3. Installation des bibliothèques Python indiquées dans `requirements.txt`.
    

**Aucune création ou activation manuelle de l'environnement virtuel n'est normalement nécessaire.**

#### En cas de problème avec l'environnement virtuel

Si le pipeline affiche une erreur liée à `.venv`, à `pip` ou à une bibliothèque Python manquante, suivre les étapes suivantes depuis la racine du projet :

1. Vérifier que les prérequis Python sont installés :
    

```
sudo apt install python3 python3-venv python3-pip
```

2. Créer l'environnement virtuel s'il n'existe pas :
    

```
python3 -m venv .venv
```

3. Activer l'environnement virtuel :
    

```
source .venv/bin/activate
```

4. Installer les dépendances :
    

```
python -m pip install -r requirements.txt
```

5. Relancer le pipeline :
    

```
./run.sh
```

Pour quitter l'environnement virtuel après utilisation :

```
deactivate
```

### 6.4. Donner les droits d'exécution

Donner les droits d'exécution aux scripts shell :

```
chmod +x run.sh
chmod +x scripts/*.sh
```

Cette opération permet d'exécuter directement les scripts du projet.

## 7. Exécution du pipeline

Le point d'entrée du projet est le fichier `run.sh`, qui coordonne automatiquement les différentes étapes du pipeline.

Depuis la racine du dépôt, exécuter :

```
./run.sh
```

Cette commande lance automatiquement le pipeline, y compris la configuration de l'environnement Python et l'installation des dépendances si nécessaire.

#### **Remarque en cas de problème de permission :**

Si l'exécution de `./run.sh` affiche le message `Permission denied`, cela signifie que le fichier ne possède probablement pas les droits d'exécution nécessaires.

Accorder ces droits avec la commande suivante :

```
chmod +x run.sh
```

Puis relancer le pipeline :

```
./run.sh
```

**Alternative :** il est également possible de lancer le script directement avec Bash, sans avoir besoin des droits d'exécution sur `run.sh` :

```
bash run.sh
```

#### **Remarque en cas d'erreur liée à l'environnement virtuel Python :**

Si le pipeline affiche une erreur liée à `.venv`, à `pip` ou aux bibliothèques Python, consulter la section **6.3. Configuration de l'environnement Python**, qui présente la procédure de configuration manuelle permettant de résoudre ce problème.


Pour afficher l'aide :

```
./run.sh -h
```

Pour demander le recalcul des fichiers dérivés :

```
./run.sh -f
```

L'option `-f` concerne les fichiers préparés et les résultats. Elle ne doit pas supprimer les données brutes téléchargées.

Le pipeline doit être lancé depuis la racine du projet afin que les chemins et les fichiers de configuration soient correctement retrouvés.

## 8. Étapes du pipeline

L'exécution de `run.sh` coordonne les étapes suivantes :

### 8.1. Préparation de l'environnement

Le script prépare les dossiers nécessaires au fonctionnement du projet et vérifie la disponibilité des outils et des dépendances.

### 8.2. Téléchargement des données

Les fichiers nécessaires à l'analyse sont téléchargés depuis GEO.

Les sommes de contrôle SHA-256 sont utilisées pour vérifier l'intégrité des fichiers téléchargés.

Les fichiers déjà présents et correctement vérifiés peuvent être réutilisés afin d'éviter des téléchargements inutiles.

### 8.3. Extraction des données

L'archive des données brutes est vérifiée puis extraite.

La matrice GEO compressée est également décompressée si nécessaire.

### 8.4. Préparation des données

Cette étape permet notamment de :

- Extraire les valeurs d'expression nécessaires à l'analyse.
- Associer les échantillons à leur type de tissu.
- Identifier les échantillons tumoraux et normaux.
- Vérifier les correspondances entre les 43 paires.
- Associer les identifiants de sondes aux gènes à partir de l'annotation GPL96.
- Préparer les fichiers nécessaires à l'analyse statistique.

### 8.5. Analyse statistique

Le script Python effectue la comparaison des niveaux d'expression entre les tissus tumoraux et normaux en tenant compte de l'organisation appariée des échantillons.

Les résultats statistiques sont enregistrés dans des fichiers exploitables.

### 8.6. Tests et validation

Des tests automatiques vérifient le fonctionnement des traitements Python.

Une étape de validation contrôle la présence et la structure des fichiers produits.

### 8.7. Archivage

Les tableaux et les figures générés sont regroupés dans une archive datée au format TAR.GZ.

## 9. Fichiers produits

Après l'exécution du pipeline, les dossiers et fichiers suivants sont générés automatiquement :

```
data/
├── raw/
│   ├── checksums.sha256
│   ├── GSE15852_RAW.tar
│   ├── GSE15852_series_matrix.txt.gz
│   ├── GSE15852_series_matrix.txt
│   ├── GPL96.annot.gz
│   └── extracted/                 # Fichiers extraits
│
└── processed/
    ├── sample_metadata.csv        # Métadonnées des échantillons
    ├── expression_matrix.csv      # Matrice d'expression préparée
    └── probe_annotation.csv       # Annotation des sondes

results/
├── tables/
│   └── differentially_expressed_genes.csv  # Résultats statistiques
│
├── figures/
│   └── volcano_plot.png                   # Graphique Volcano
│
└── archive/
    └── results_DATE_HEURE.tar.gz           # Archive datée des résultats

logs/
└── run_DATE_HEURE.log             # Journal horodaté de l'exécution
```

L'environnement Python `.venv/` est également créé automatiquement à la racine du projet. Il contient les dépendances nécessaires à l'analyse.

Les noms des journaux et des archives contiennent la date et l'heure de leur création. Les archives et les journaux des exécutions précédentes sont conservés.

## 10. Planification automatique avec Cron

Cron est un planificateur de tâches sous Linux qui permet d'exécuter automatiquement le pipeline à une date et une heure définies.

Le fichier `cron/projet_maladie.cron` contient un exemple de configuration permettant de lancer le pipeline chaque lundi à 02 h 00.

**Remarque :** Cron est indépendant de `run.sh`. Il n'est pas exécuté automatiquement par le pipeline ; il permet de programmer son lancement.

### 10.1. Installation de Cron

Sur Ubuntu, vérifiez d'abord si la commande `crontab` est disponible :

```
command -v crontab
```

Si la commande n'est pas disponible, installez Cron :

```
sudo apt update
sudo apt install cron
```

Activez et démarrez ensuite le service :

```
sudo systemctl enable --now cron
```

### 10.2. Activation de la tâche

Avant d'activer la tâche, vérifiez que le pipeline fonctionne correctement avec `./run.sh` et que le dossier `logs/` existe.

Ouvrez le fichier `cron/projet_maladie.cron` et vérifiez que le chemin absolu vers `run.sh` correspond à l'emplacement réel de votre projet.

Pour ajouter la tâche au planificateur Cron, exécutez :

```
crontab -e
```

Copiez la ligne de configuration du fichier `cron/projet_maladie.cron`, ajoutez-la dans l'éditeur, puis enregistrez le fichier.

Pour vérifier que la tâche est enregistrée :

```
crontab -l
```

### 10.3. Consultation des journaux

Les sorties et les erreurs de l'exécution planifiée sont enregistrées dans :

```
cat logs/cron.log
```

Les journaux permettent de suivre les exécutions et d'identifier d'éventuelles erreurs.

**Remarque :** L'utilisation de Cron est indépendante de l'exécution manuelle du pipeline avec `./run.sh`.

## 11. Reproductibilité et dépannage

Le pipeline utilise plusieurs mécanismes pour faciliter son exécution et détecter les erreurs :

- Vérification de la présence des outils nécessaires.
- Vérification de l'intégrité des fichiers téléchargés avec SHA-256.
- Utilisation d'un environnement Python isolé.
- Gestion des erreurs dans les scripts Bash.
- Journaux d'exécution horodatés.
- Tests automatiques du traitement Python.
- Validation des fichiers générés.
- Archivage des résultats.

En cas de problème, vérifier les points suivants :

**Le téléchargement échoue :**
- Vérifier la connexion Internet.
- Vérifier que les fichiers GEO sont accessibles.
- Vérifier l'espace disque disponible.

**Une bibliothèque Python manque :**
- Activer l'environnement virtuel.
- Réexécuter `pip install -r requirements.txt`.

**Le pipeline ne trouve pas un fichier :**
- Vérifier que le projet a été cloné correctement.
- Vérifier que les scripts et les fichiers de configuration sont présents.
- Vérifier que la commande est exécutée depuis la racine du dépôt.

**Une erreur apparaît pendant l'analyse :**
- Consulter les journaux dans `logs/`.
- Vérifier les fichiers préparés dans `data/processed/`.
- Vérifier que les échantillons tumoraux et normaux sont correctement associés.

## 12. Répartition du travail

| Membre (GitHub)                                | Rôle                    | Fichiers concernés                                                                                | Travail réalisé                                                                           |
| ---------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| [@ambaramiira](https://github.com/ambaramiira) | Intégration et système  | `run.sh`, `config/config.sh`, `scripts/setup.sh`                                                  | Configuration de l'environnement, script principal et intégration du pipeline.            |
| [@Mariane-Isl](https://github.com/Mariane-Isl) | Acquisition des données | `scripts/download.sh`, `scripts/extract.sh`, `SOURCES.md`                                         | Téléchargement, vérification, extraction et documentation des sources.                    |
| [@SirineBouk](https://github.com/SirineBouk/)  | Préparation des données | `scripts/prepare_data.sh`,`README.md`                                                             | Préparation des métadonnées, de la matrice d'expression et des annotations.               |
| [@melilin-afk](https://github.com/melilin-afk) | Analyse scientifique    | `scripts/analyze.py`                                                                              | Analyse statistique, comparaison des échantillons et génération des résultats et figures. |
| [@its-imene](https://github.com/its-imene)     | Qualité et livraison    | `scripts/validate.sh`, `scripts/archive.sh`, `tests/test_analysis.py`, `cron/projet_maladie.cron` | Tests, validation, archivage, configuration cron et documentation.                        |


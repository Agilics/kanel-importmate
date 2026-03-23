# KANEL - ImportMate

Outil d'import de donnees CSV vers Salesforce, sans code. L'utilisateur cree un projet, charge un fichier CSV, mappe les colonnes vers les champs Salesforce, applique des transformations si besoin, valide les donnees, puis lance l'import. Le tout via une interface guidee en 6 etapes.

Package Salesforce (managed) destine a l'AppExchange. API v58.0.

---

## Les 6 etapes de l'import

| Etape | Quoi | Composant principal |
|-------|------|---------------------|
| 1. Projet | Creer ou selectionner un projet d'import (nom, objet cible) | `createProjectComponent` |
| 2. Source de donnees | Charger un CSV ou construire une requete SOQL | `csvUploader` / `soqlBuilder` |
| 3. Mapping | Associer chaque colonne CSV a un champ Salesforce (auto-map, lookup, drag & drop) | `fieldMapper` |
| 4. Transformations | Appliquer des regles sur les valeurs : majuscule, minuscule, booleen, masque email/telephone, concatenation | `transformationPage` |
| 5. Validation (Dry Run) | Tester l'import sans rien sauvegarder : format, picklist, champs requis, lookups | `dryRunValidator` |
| 6. Execution | Lancer l'import reel avec suivi en temps reel via Platform Event | `executionCmp` |

En plus de l'assistant d'import, l'application propose :
- **Dashboard** : KPI globaux (projets, taux de succes, records importes, planifications actives)
- **Historique** : liste des executions passees avec filtres, export Excel, details par ligne
- **Statistiques** : graphiques (volume par jour, taux de succes, repartition par statut, top projets)
- **Planification** : programmer des imports automatiques (quotidien, hebdomadaire, mensuel)

---

## Architecture

### Vue d'ensemble

```
LWC (43 composants)
       |
  Controllers Apex (8 classes @AuraEnabled)
       |
  Services (14 classes - logique metier)
       |
  Repositories (8 classes - acces donnees SOQL/DML)
       |
  Objets custom Salesforce (8 objets + 1 Platform Event)
```

Le code suit le pattern **Controller -> Service -> Repository**. Les controllers exposent les methodes `@AuraEnabled`, les services contiennent la logique metier, les repositories gerent les requetes SOQL et les operations DML.

### Backend Apex

```
force-app/main/default/classes/
├── controllers/          # 8 classes - point d'entree pour les LWC
│   ├── BatchExecutionController
│   ├── DashboardController
│   ├── DryRunController
│   ├── FieldMappingController
│   ├── ImportProjectController
│   ├── QueryBuilderController
│   ├── ScheduleController
│   └── TransformationController
│
├── services/             # 14 classes - logique metier
│   ├── ExecutionService          # orchestration de l'import
│   ├── FieldMappingService       # gestion du mapping
│   ├── TransformationService     # application des regles
│   ├── ObjectMetadataService     # describe des objets SF
│   ├── LookupResolver            # resolution des lookups
│   ├── RowValidator              # validation ligne par ligne
│   ├── RollbackValidationService # dry run avec savepoint
│   ├── ProjectService
│   ├── ScheduleService
│   ├── QueryBuilderService
│   ├── ImportBatchService
│   ├── ImportLogService
│   ├── ErrorLogService
│   └── PublisherService          # envoi de Platform Events
│
├── repositories/         # 8 classes - couche donnees
│
├── asynch/               # traitements asynchrones
│   ├── PreProcessBatch           # parse JSON + transformations + lookups
│   ├── ImportDmlBatch            # DML d'insertion
│   ├── CleanupStagingRowBatch    # nettoyage des StagingRow
│   ├── StagingCleanupBatch
│   ├── StagingCleanupScheduler
│   └── ScheduleJob               # job planifie natif SF
│
├── utils/                # utilitaires + transformations
│   ├── BooleanTransformation
│   ├── UpperCaseTransformation
│   ├── LowerCaseTransformation
│   ├── EmailMaskTransformation
│   ├── PhoneMaskTransformation
│   ├── ConcatenationTransformation
│   ├── ImportUtils
│   ├── SecurityUtils
│   ├── TransformationUtils
│   └── ValidationUtils
│
├── exceptions/           # 7 exceptions custom
├── interfaces/           # ITransformationRule
├── types/                # DashboardStats, ImportMateEnum
├── statics/              # Constants
└── test/                 # 48 classes de test
```

### Frontend LWC (43 composants)

Le composant racine est `mainComponent`. Il affiche un stepper et charge les sous-composants selon l'etape courante.

Composants cles par ecran :

| Ecran | Composants |
|-------|-----------|
| Navigation | `mainComponent`, `stepperComponent`, `sideBarCmp`, `appHeaderCmp`, `backbutton` |
| Projet | `createProjectComponent`, `selectProjectComponent`, `projectCard`, `projectFormComponent`, `importProjectRecentComponent` |
| Source CSV | `csvUploader`, `dataSource`, `dataSourceCard`, `dataSourceSelector` |
| Source SOQL | `soqlBuilder` |
| Mapping | `fieldMapper`, `fieldMappingTable`, `mappingPreview` |
| Transformations | `transformationPage`, `transformationMapperList`, `transformationCardComponent`, `transformationPreviewModal`, `transformationSaveModal`, `transformationFieldTabs` |
| Validation | `dryRunValidator` |
| Execution | `executionCmp`, `executionCard`, `importResults` |
| Dashboard | `dashboardCmp` |
| Historique | `importHistory`, `importStatistics` |
| Planification | `scheduleCreatorComponent`, `scheduleJobsComponent`, `scheduleRegisterModal`, `scheduledSchedules` |

### Modele de donnees

```
ImportProject__c                    # projet d'import (nom, objet cible, actif)
  └── FieldMapping__c               # mapping colonne CSV -> champ SF (lookup config, version)
        └── TransformationRule__c    # regle de transformation (type, parametres, ordre)
  └── Schedule__c                   # planification (frequence, prochaine execution)
  └── ImportExecution__c            # une execution (statut, phase, compteurs, job ID)
        └── StagingRow__c           # ligne brute CSV en JSON (zone de transit)
        └── ImportLog__c            # log par ligne (erreur, warning, info)
        └── ErrorLog__c             # log systeme (exception, stack trace)

ImportStatusEvent__e                # Platform Event pour le suivi temps reel
```

### Pipeline d'import (ce qui se passe cote serveur)

1. **Staging** : le LWC envoie les lignes CSV par paquets de 2 000 vers `StagingRow__c`
2. **PreProcessBatch** (200 lignes/batch) : parse le JSON, applique les transformations, resout les lookups
3. **ImportDmlBatch** (25 lignes/batch) : insere les records dans l'objet cible
4. **Nettoyage** : `StagingCleanupBatch` supprime les `StagingRow__c` de plus de 2 jours

Le suivi en temps reel se fait via le Platform Event `ImportStatusEvent__e` (ExecutionId, Status, Progress, Message).

Trois modes selon le volume :
- **Sync** : 50 lignes ou moins, traitement direct
- **SmallBatch** : jusqu'a 5 000 lignes
- **FullPipeline** : au-dela de 5 000 lignes, pipeline complet staging -> preprocess -> DML

---

## Securite

- **Permission Set** : `ImportMate_Admin` — acces complet (CRUD) sur les 8 objets custom + toutes les classes Apex
- **SecurityUtils** : verification `isAccessible`, `isCreateable`, `isDeletable` sur les objets
- Controllers en `with sharing` (respect des regles de partage)

---

## CI/CD

Pipeline GitHub Actions (`.github/workflows/cicd.yml`) :

```
PR vers develop     -> Validation (deploy check)
Merge sur develop   -> Deploy en org UAT
Push sur main       -> Creation du package + install en org subscriber
```

Authentification par JWT vers les orgs Salesforce.

---

## Stack technique

| Quoi | Detail |
|------|--------|
| Backend | Apex (API 58.0) |
| Frontend | Lightning Web Components (43 composants) |
| Tests | Apex Tests (48 classes) + Jest (`@salesforce/sfdx-lwc-jest`) |
| Linter | ESLint (`@salesforce/eslint-config-lwc`) |
| Formatter | Prettier + `prettier-plugin-apex` |
| Git hooks | Husky + lint-staged (format + lint au commit) |
| CI/CD | GitHub Actions |

---

## Installation

### Pre-requis
- Salesforce CLI (`@salesforce/cli`)
- Node.js + npm
- Un org Salesforce (Developer, Sandbox, ou Scratch)

### Setup local

```bash
# Cloner le repo
git clone <url-du-repo>
cd kanel-importmate

# Installer les dependances
npm install

# Deployer sur un scratch org
sf org create scratch -f config/project-scratch-def.json -a importmate
sf project deploy start -o importmate

# Assigner le permission set
sf org assign permset -n ImportMate_Admin -o importmate
```

### Lancer les tests

```bash
# Tests unitaires LWC
npm run test:unit

# Tests Apex (sur l'org)
sf apex run test -o importmate --wait 10
```

---

## Structure du projet

```
kanel-importmate/
├── .github/workflows/        # Pipeline CI/CD
├── config/                   # Scratch org definition
├── force-app/main/default/
│   ├── classes/              # Apex (52 classes prod + 48 tests)
│   ├── lwc/                  # 43 composants Lightning
│   ├── objects/              # 8 objets custom + 1 Platform Event
│   ├── labels/               # ~350 labels custom (FR)
│   ├── permissionsets/       # ImportMate_Admin
│   └── staticresources/     # Logo
├── sfdx-project.json
├── package.json
└── jest.config.js
```

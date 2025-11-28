# Composant TransformationSaveFormModal

## Description

Ce composant LWC (Lightning Web Component) permet de **créer et d'appliquer des règles de transformation** en une seule action. Il s'agit d'un modal qui offre une interface utilisateur intuitive pour configurer différents types de transformations de données.

## Fonctionnalités

### Types de transformations supportées

- **ConcatenationTransformation** : Concatène 1 à 3 champs avec un séparateur personnalisable
- **EmailMasking** : Masque les adresses email avec un domaine personnalisé
- **PhoneMask** : Masque les numéros de téléphone
- **UpperCaseTransformation** : Convertit en majuscules
- **LowerCaseTransformation** : Convertit en minuscules

### Flux de travail

1. **Sélection du mapping** : Choisir le mapping de champ sur lequel appliquer la transformation
2. **Choix du type** : Sélectionner le type de transformation souhaité
3. **Configuration** : Remplir les paramètres spécifiques (champs, séparateur, domaine, etc.)
4. **Ordre d'exécution** : Définir l'ordre d'application (1-3)
5. **Sauvegarde et application** : Créer la règle et la tester immédiatement

## Utilisation

### Ouverture du modal

```javascript
import TransformationSaveFormModal from 'c/transformationSaveFormModal';

// Dans votre composant parent
async openTransformationModal() {
    const result = await TransformationSaveFormModal.open({
        size: 'medium',
        projectId: this.projectId  // ID du projet
    });
    
    if (result && result.success) {
        console.log('Règle créée avec ID:', result.ruleId);
        console.log('Valeur transformée:', result.transformedValue);
        // Rafraîchir vos données si nécessaire
    }
}
```

### Propriétés

| Propriété | Type | Requis | Description |
|-----------|------|--------|-------------|
| `projectId` | String | Oui | ID du projet auquel associer la règle |

### Valeurs de retour

Le modal retourne un objet avec :
- `success` : Boolean - Indique si la règle a été créée avec succès
- `ruleId` : String - ID de la règle créée
- `transformedValue` : String - Valeur résultant du test de transformation

## Structure des fichiers

```
transformationSaveFormModal/
├── transformationSaveFormModal.html         # Template du modal
├── transformationSaveFormModal.js           # Logique JavaScript
├── transformationSaveFormModal.css          # Styles personnalisés
├── transformationSaveFormModal.js-meta.xml  # Métadonnées du composant
└── __tests__/                               # Tests unitaires
```

## Configuration par type de transformation

### ConcatenationTransformation

**Champs requis :**
- Champs sources (1 à 3)
- Séparateur (Tab, Comma, Space, Semi Comma, New line)

**Exemple :**
```
Champs: FirstName, LastName
Séparateur: Space
Résultat: "John Doe"
```

### EmailMasking

**Champs requis :**
- Domaine (ex: sandbox.com)

**Exemple :**
```
Domaine: test.example.com
Valeur originale: john.doe@real.com
Résultat: john.doe@test.example.com
```

### PhoneMask

**Configuration automatique :**
- Préserve le code pays par défaut

## Méthodes Apex utilisées

Le composant s'appuie sur les méthodes Apex suivantes :

1. **`createRule`** (TransformationController)
   - Crée la règle de transformation
   - Recharge la règle avec ses relations

2. **`applyTransformations`** (TransformationController)
   - Applique la transformation sur une ligne de test
   - Retourne la valeur transformée

3. **`getPickListValues`** (TransformationController)
   - Récupère les types de transformation disponibles

4. **`getAllMappingsByProjectId`** (FieldMappingController)
   - Récupère tous les mappings du projet

## Validation

Le formulaire valide :
- Présence d'un mapping sélectionné
- Présence d'un type de règle
- Pour ConcatenationTransformation : 1 à 3 champs sélectionnés
- Pour EmailMasking : domaine non vide

## Messages d'erreur

Le composant affiche des toasts informatifs :
- ✅ **Succès** : Affiche les détails de la transformation testée
- ❌ **Erreur** : Affiche le message d'erreur détaillé

## Exemple de résultat

Après création réussie :
```
Succès
Règle créée et testée avec succès !
Type: ConcatenationTransformation
Champ: FullName
Test: "(vide)" → "John Doe"
```

## Notes techniques

- Le composant hérite de `LightningModal` pour le comportement modal
- Utilise `@wire` pour charger les données réactives
- Gère l'affichage conditionnel des champs selon le type
- Teste automatiquement la règle après création

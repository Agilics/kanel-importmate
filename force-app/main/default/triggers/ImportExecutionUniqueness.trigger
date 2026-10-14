trigger ImportExecutionUniqueness on ImportExecution__c (before insert, before update) {
  // ============================================================
    // 1. Statuts considérés comme actifs
    // ============================================================
    Set<String> activeStatuses = new Set<String>{
        Constants.EXECUTION_STATUS_PENDING,
        Constants.EXECUTION_STATUS_IN_PROGRESS,
        Constants.EXECUTION_STATUS_SUSPENDED
    };

    // ============================================================
    // 2. Récupération des projets concernés
    // ============================================================
    Set<Id> projectIds = new Set<Id>();

    for (ImportExecution__c ie : Trigger.new) {
        if (ie.Project__c != null && activeStatuses.contains(ie.Status__c)) {
            // Exclure les exécutions de type 'Scheduled' de la règle d'unicité
            // car le bulkExecute peut créer plusieurs exécutions Scheduled pour un même projet
            if (ie.Type__c == Constants.EXECUTION_TYPE_SCHEDULED) {
                continue;
            }
            projectIds.add(ie.Project__c);
        }
    }

    if (projectIds.isEmpty()) {
        return;
    }

    // ============================================================
    // 3. Recherche des exécutions actives déjà présentes en base
    // ============================================================
    Map<Id, ImportExecution__c> existingActiveByProject =
        new Map<Id, ImportExecution__c>();

    for (ImportExecution__c existing : [
        SELECT Id, Project__c, Status__c
        FROM ImportExecution__c
        WHERE Project__c IN :projectIds
        AND Status__c IN :activeStatuses
    ]) {
        /*
         * En cas de plusieurs lignes existantes pour un même projet,
         * on conserve la première trouvée.
         */
        if (!existingActiveByProject.containsKey(existing.Project__c)) {
            existingActiveByProject.put(existing.Project__c, existing);
        }
    }

    // ============================================================
    // 4. Détection des doublons dans le batch courant
    // ============================================================
    Map<Id, ImportExecution__c> activeInCurrentBatchByProject =
        new Map<Id, ImportExecution__c>();

    for (ImportExecution__c ie : Trigger.new) {

        // Seules les exécutions actives doivent être contrôlées
        if (ie.Project__c == null || !activeStatuses.contains(ie.Status__c)) {
            continue;
        }

        // --------------------------------------------------------
        // 4.a. Vérification d'un doublon déjà présent dans Trigger.new
        // --------------------------------------------------------
        if (activeInCurrentBatchByProject.containsKey(ie.Project__c)) {
            ImportExecution__c duplicate =
                activeInCurrentBatchByProject.get(ie.Project__c);

            /*
             * Lors d'un update, on autorise la même ligne à être
             * présente dans le traitement.
             */
            if (ie.Id == null || duplicate.Id == null || ie.Id != duplicate.Id) {
                ie.addError(
                    'Un ImportExecution actif existe déjà dans ce lot pour le projet : ' +
                    ie.Project__c +
                    '. Un seul ImportExecution actif est autorisé par projet.'
                );
                continue;
            }
        } else {
            activeInCurrentBatchByProject.put(ie.Project__c, ie);
        }

        // --------------------------------------------------------
        // 4.b. Vérification des données déjà présentes en base
        // --------------------------------------------------------
        if (existingActiveByProject.containsKey(ie.Project__c)) {

            ImportExecution__c existing =
                existingActiveByProject.get(ie.Project__c);

            /*
             * Lors d'un update, si l'enregistrement trouvé en base
             * est exactement celui qu'on est en train de modifier,
             * on l'autorise.
             */
            if (ie.Id != null && existing.Id == ie.Id) {
                continue;
            }

            ie.addError(
                'Un ImportExecution actif existe déjà pour le projet : ' +
                ie.Project__c +
                ' (Id : ' + existing.Id +
                '). Veuillez clôturer ou annuler cette exécution avant d\'en créer une nouvelle.'
            );
        }
    }

}
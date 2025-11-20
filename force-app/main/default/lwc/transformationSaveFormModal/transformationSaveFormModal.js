import { track, wire, api } from 'lwc';
import LightningModal from 'lightning/modal';
import TRANSFORMATION_OBJECT from "@salesforce/schema/TransformationRule__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import RULE_TYPE_FIELD from "@salesforce/schema/TransformationRule__c.RuleType__c"; 
import getPickListValues from "@salesforce/apex/TransformationController.getPickListValues";
import getAllMappingsByProjectId from "@salesforce/apex/FieldMappingController.getAllMappingsByProjectId";
import applyTransformations from "@salesforce/apex/TransformationController.applyTransformations";
import createRule from "@salesforce/apex/TransformationController.createRule";

export default class TransformationSaveFormModal extends LightningModal {
    @api projectId;
    @api mappingVersion;
    @track sourceField = "";
    @track targetField = "";
    @track separator;
    @track selectedRuleType = ""; // Correction du nom
    @track parameters;
    @track order = 1;
    @track ruleTypeOptions = [];
    @track fieldMappingOptions = [];
    @track isSeparatorVisible = false ;    // Nouvelles propriétés pour le template
    @track fieldMappingId = "";
    @track ruleTypeHelp = "";
    @track exampleParameters = "";
    @track testValue = "";
    @track testResult = null;
    @track isSaveDisabled = true;
    @track sourceFieldOptions = [];  
    @track transformations = [];
  
    // Gestionnaire pour Field Mapping
    handleFieldMappingChange(event) {
      this.fieldMappingId = event.detail.value;
      this.validateForm();
    }

  //affichage du champs de texte Parameter__c
  get isParameterVisible() {
    return this.selectedRuleType === 'PhoneMask' || this.selectedRuleType === 'EmailMask' || this.selectedRuleType === "Concatenation";
  }

      // Sauvegarde de la transformation
    async handleSaveTransformation() {
        if (this.isSaveDisabled) return;
      
        const transformationData = {
            fieldMappingId: this.fieldMappingId,
            ruleType: this.selectedRuleType,
           // parameters: JSON.stringify(this.parameters),
            order: parseInt(this.order, 10),
            projectId: this.projectId
        };

       const savedRule = await createRule({ transformationData: transformationData })
            .then(result => {
                this.showToast('Succès', 'Règle de transformation créée', 'success');
                this.close('success');
            })
            .catch(error => {
                console.error('Erreur création règle:', error);
                this.showToast('Erreur', 'Erreur lors de la création', 'error');
            });
        // appliquer une transformation
        this.handleParametersToFormatJson(savedRule,)
    }

   
 
    //appliquer transformation
   async handleApplyTransformation(transformation) {
       if (String.isNotBlank(this.fieldMappingId) && String.isNotBlank(this.selectedRuleType)) {
           this.parameters = this.handleParametersToFormatJson(this.selectedRuleType,this.separator,this.sourceField);
          
           const rowData = JSON.deserializeUntyped(this.parameters); // Convertion du JSON en Map
            //const ruleByMappingId = 
           const result = applyTransformations(
               this.fieldMappingId,
               this.rowData,

           );
    }  
   }
    
     // Génération du JSON des paramètres selon le type de règle
    handleParametersToFormatJson(ruleType, separator, fields) {
        try {
            // Contrôles basiques et nécessaires
            if (!ruleType) {
                throw this.showToast('Error','Rule type not defined.','error');
            }

            if (!Array.isArray(fields) || fields.length === 0) {
                throw this.showToast('Error','Fields are required!','error');

            }

            // Séparateur: un seul caractère max
            if (ruleType === 'Concatenation') {
                if (!separator || separator.length !== 1) {
                    throw new Error('Le séparateur doit être un unique caractère.');
                }
            }

            // Définition commune 
            let params = {
                type: ruleType,
                fields: fields
            };

            // Ajout des attributs spécifiques selon la transformation
            switch (ruleType) {
                case 'Concatenation':
                    params.separator = separator;
                    params.targetType = "concatenation";
                    break;

                case 'UpperCase':
                    // TODO :paramètres supplémentaires
                    params.targetType = "uppercase";
                    break;

                case 'PhoneMask':
                    // TODO: options si nécessaire
                    break;

                case 'EmailMask':
                    // Idem, extensible si besoin
                    break;

                default:
                    throw this.showToast('Error','Type de règle non supporté.','error');
            }

            return params;

        } catch (error) {
                this.showToast('Erreur JSON', error.message, 'error');
        }
    }


    // Gestionnaire pour Rule Type
    handleRuleTypeChange(event) {
        this.selectedRuleType = event.detail.value;
        //visibilité du séparateur transformation concaténation
        if (event.detail.value === 'Concatenation') {
            this.isSeparatorVisible = true;
        }
        this.updateRuleTypeHelp();
        this.validateForm();
    }

    // Gestionnaire pour Parameters
    handleParametersChange(event) {
        this.parameters = event.detail.value;
        this.validateForm();
    }

    // Gestionnaire pour Order
    handleOrderChange(event) {
        this.order = event.detail.value;
        this.validateForm();
    }

    // Gestionnaire pour Test Value
    handleTestValueChange(event) {
        this.testValue = event.detail.value;
    }

    // Validation du formulaire
    validateForm() {
        this.isSaveDisabled = !(
        this.fieldMappingId && 
        this.selectedRuleType && 
        this.parameters &&
        this.selectedColumns.length > 0 &&
        this.order
        );
    }

    // Mise à jour de l'aide selon le type de règle
    updateRuleTypeHelp() {
        switch(this.selectedRuleType) {
            case 'UPPERCASE':
                this.ruleTypeHelp = 'Convertit le texte en majuscules';
                this.exampleParameters = '{"option": "all"}';
                break;
            case 'LOWERCASE':
                this.ruleTypeHelp = 'Convertit le texte en minuscules';
                this.exampleParameters = '{}';
                break;
            case 'TRIM':
                this.ruleTypeHelp = 'Supprime les espaces au début et à la fin';
                this.exampleParameters = '{}';
                break;
            default:
                this.ruleTypeHelp = '';
                this.exampleParameters = '';
        }
    }

   

    // Insertion de template
    handleInsertTemplate() {
        this.parameters = '{\n  "key": "value"\n}';
    }
  

  
    // Fermeture du modal
    handleCancel() {
        this.close('cancel');
    }

    // Wire pour les mappings
    @wire(getAllMappingsByProjectId, {projectId: "$projectId" })
    wiredMappings({ data, error }) {
        if (data) {
            this.fieldMappingOptions = data.map(m => ({
                label: m.sourceColumn,
                value: m.sourceColumn,
                id:m.id
            }));
          
          this.sourceFieldOptions = data.map(m => ({
              label: m.targetField,
              value: m.targetField
          }));

        } else if (error) {
            console.error("Erreur récupération FieldMapping :", error?.body?.message);
            this.showToast("Erreur", "Impossible de charger les mappings"+error?.body.message, "error");
        }
    }

    // Wire pour les picklist values
    @wire(getPickListValues, {
        objectApiName: TRANSFORMATION_OBJECT.objectApiName,
        fieldApiName: RULE_TYPE_FIELD.fieldApiName
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.ruleTypeOptions = Object.entries(data).map(([label, value]) => ({
                label,
                value
            }));
        } else if (error) {
            console.error("Erreur récupération picklist rule : ", error);
            this.showToast("Error", error?.body?.message || "Erreur lors de la récupération des valeurs", "error");
        }
    }

    handleSourceFieldsChange(event) {
      this.selectedColumns = event.detail.value;
      this.validateForm();
    }

  
    // Affichage toast
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: "dismissable"
        });
        this.dispatchEvent(event);
    }
}
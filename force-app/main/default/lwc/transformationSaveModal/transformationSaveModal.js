/**
 * @Last Modification: 01-28-2026
 * @Last Modification By : Mouhamed NIANG
 * Modifications :
 * - add boolean value for boolean transformation prevent duplicate rules
 * - ReadOnly Field Mapping SourceField -> TargetField
 * - add update rule method
 */
import { wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import TRANSFORMATION_OBJECT from '@salesforce/schema/TransformationRule__c'; 
import LightningModal from 'lightning/modal';
import RULE_TYPE_FIELD from '@salesforce/schema/TransformationRule__c.RuleType__c';
import getRuleById from '@salesforce/apex/TransformationController.getRuleById';
import createRule from '@salesforce/apex/TransformationController.createRule'; 
import getPickListValues from '@salesforce/apex/TransformationController.getPickListValues';
import getAllMappingsByProjectId from '@salesforce/apex/FieldMappingController.getAllMappingsByProjectId';
import doesTransformationExist from '@salesforce/apex/TransformationController.doesTransformationExist';
import updateRule from '@salesforce/apex/TransformationController.updateRule';

export default class TransformationSaveModal extends LightningModal {
    @api projectId; 
    @api mappingId;  
    @api mapping;

    //target value for boolean 
    @track booleanValue = false;

    initialRuleType;
    hasLoadedRule = false;

 

    // Propriétés réactives
    @track ruleType ; 
    selectedColumns = []; // IDs sélectionnés dans le dual-listbox
    @track separator = '';
    fields = []; // Noms de champs finaux ['firstname', 'lastname']
    targetField = '';
    @track targetValue;
    parameters = '{}';
    @track isBooleanTransformation = false;
    @track phone; 
    mappingIdToFieldMap = new Map();
    ruleTypeOptions = [];
    fieldMappingOptions = [];
    targetFieldOptions = [];

    separatorOptions = [
        { label: 'Tab', value: '\t' },
        { label: 'Comma', value: ',' },
        { label: 'Space', value: ' ' },
        { label: 'Semi Comma', value: ';' },
        { label: 'New line', value: '\n' }
    ];

    @api isEdit = false; // vrai si on édite une règle existante

    @api existingRuleId;

    @wire(getRuleById, { ruleId: '$existingRuleId' })
    wiredExistingRuleById({ data, error }) {
    if (data) {
        this.isEdit = true;
        this.existingRule = data;

        console.log('Existing rule loaded:', JSON.stringify(data));
        
        this.targetValue = data.TargetValue__c;
        this.mappingId = data.FieldMapping__c;
        
        this.mapping = {
            sourceColumn: data.FieldMapping__r?.SourceColumn__c || '',
            targetField: data.FieldMapping__r?.TargetField__c || ''
        };

        // Parameters
        let params = {};
        try {
            params = data.Parameters__c ? JSON.parse(data.Parameters__c) : {};
        } catch {
            params = {};
        } 

        this.separator = params.separator || ',';
        
        // Si les options de picklist sont déjà chargées, assigner le ruleType maintenant
        if (this.ruleTypeOptions.length > 0 && !this.hasLoadedRule) {
            this.hasLoadedRule = true;
            
            const ruleTypeFromDB = data.RuleType__c;
            console.log('Rule Type from DB:', ruleTypeFromDB);

            const match = this.ruleTypeOptions.find(opt => {
                console.log('Comparaison:', opt.value, '===', ruleTypeFromDB);
                return opt.value === ruleTypeFromDB || opt.label === ruleTypeFromDB;
            });
           
            console.log('Match trouvé:', match);
            this.ruleType = match ? match.value : ruleTypeFromDB;
            console.log('Rule Type assigné:', this.ruleType);
        }
        
        // Gérer le cas Boolean Transformation
        if (data.RuleType__c === 'BooleanTransformation') {
            this.isBooleanTransformation = true;
            if (params.trueValues && params.trueValues.length > 0) {
                this.booleanValue = true;
            } else if (params.falseValues && params.falseValues.length > 0) {
                this.booleanValue = false;
            }
        }

        this.fields = data.SourceFields__c
            ? data.SourceFields__c.split(this.separator)
            : [];

        this.syncSelectedColumns();
    }

    if (error) {
        console.error('Erreur chargement rule', error);
        this.toastErr('Impossible de charger la règle');
    }
}
    
    syncSelectedColumns() {
        if (!this.existingRule || !this.mappingIdToFieldMap.size || !this.fields.length) {
            return;
        }

        this.selectedColumns = this.fields
            .map(f =>
                [...this.mappingIdToFieldMap.entries()]
                    .find(([_, v]) => v === f)?.[0]
            )
            .filter(Boolean);
        
        console.log('Synchronized selected columns:', this.selectedColumns);
    }

    get ruleTypeLabel() {
        if (!this.ruleType) {
            return '';
        }
        
        // Trouver le label correspondant à la valeur
        const option = this.ruleTypeOptions.find(opt => opt.label === this.existingRule.RuleType__c );
        return option ? option.label : this.ruleType;
    }

    loadRuleData(data) {
        if (this.hasLoadedRule) {
            return;
        }
        
        this.hasLoadedRule = true;
        
        console.log('=== LOADING RULE DATA ===');
        console.log('Rule Type from DB:', data.RuleType__c);
        console.log('Available options:', JSON.stringify(this.ruleTypeOptions));
        
        // Vérifier que la valeur existe dans les options
        const valueExists = this.ruleTypeOptions.some(opt => opt.value === data.RuleType__c);
        console.log('Value exists in options?', valueExists);
        
        if (!valueExists) {
            console.error('RuleType not found in options!');
            console.log('Looking for:', data.RuleType__c);
            console.log('Available values:', this.ruleTypeOptions.map(o => o.value));
        }
        
        // Utiliser setTimeout pour forcer le rafraîchissement
        setTimeout(() => {
            this.ruleType = data.RuleType__c;
            console.log('Rule Type assigned (after timeout):', this.ruleType);
        }, 100);
        
        this.targetValue = data.TargetValue__c;
        
        // Récupérer le mappingId depuis la règle existante
        this.mappingId = data.FieldMapping__c;
        
        // Récupérer le mapping complet pour l'affichage
        this.mapping = {
            sourceColumn: data.FieldMapping__r?.SourceColumn__c || '',
            targetField: data.FieldMapping__r?.TargetField__c || ''
        };

        // Parameters
        let params = {};
        try {
            params = data.Parameters__c ? JSON.parse(data.Parameters__c) : {};
        } catch {
            params = {};
        }

        this.separator = params.separator || ',';
        
        // Gérer le cas Boolean Transformation
        if (data.RuleType__c === 'BooleanTransformation') {
            this.isBooleanTransformation = true;
            if (params.trueValues && params.trueValues.length > 0) {
                this.booleanValue = true;
            } else if (params.falseValues && params.falseValues.length > 0) {
                this.booleanValue = false;
            }
        }

        this.fields = data.SourceFields__c
            ? data.SourceFields__c.split(this.separator)
            : [];

        this.syncSelectedColumns();
        
        console.log('=== RULE DATA LOADED ===');
    }

    
    

    get modalLabel(){
        return this.isEdit ? 'Edit Rule' : 'Add New Rule';
    } 
    
    // ------------------------
    // Handlers UI
    // ------------------------
     get mappingInfo() {
        if (!this.mapping) {
            return '';
        }
        
        const source = this.mapping.sourceColumn || '';
        const target = this.mapping.targetField || '';
        
        return `${source} → ${target}`;
    }

     

    handleFieldMappingChange(event) {
        this.mappingId = event.detail.value;
        console.log('Mapping sélectionné - ID:', this.mappingId);
    }

    handleSourceFieldsChange(event) {
        // event.detail.value contient les IDs sélectionnés
        this.selectedColumns = event.detail.value;
        
        // Convertir les IDs en noms de champs
        this.fields = this.selectedColumns
            .map(id => this.mappingIdToFieldMap.get(id))
            .filter(Boolean); // Enlever les undefined
        
        console.log('IDs sélectionnés:', this.selectedColumns);
        console.log('Champs convertis:', this.fields);
    }

    handleRuleTypeChange(event) {
        this.ruleType = event.detail.value;
        if(this.ruleType === 'BooleanTransformation' || this.ruleType === 'Boolean Transformation' ){
            this.isBooleanTransformation = true;
            this.targetValue = this.booleanValue;
        }else {
            this.isBooleanTransformation = false;
        }
        console.log('Type de règle sélectionné:', this.ruleType);
    }

    handleSeparatorChange(event) {
        this.separator = event.detail.value;
        console.log('Séparateur sélectionné:', this.separator);
    }
 
    handleTargetValueChange(event) {
        this.targetValue = event.detail.value;
    }

    handleDomainChange(event) {
        this.domain = event.detail.value;
    }

    handleBooleanValueChange(event){
       this.booleanValue = event.target.checked;
        console.log( this.booleanValue );
    }
 
    
    handleCancel() {
        this.resetState();
        this.close({ success: false });
    }

    resetState() { 
        // Réinitialiser toutes les propriétés
        this.ruleType = '';
        this.initialRuleType = '';
        this.existingRule = null;
        this.isEdit = false;
        this.hasLoadedRule = false;
        this.fields = [];
        this.existingRuleId = null;
        this.selectedColumns = [];
        this.isBooleanTransformation = false;
        this.booleanValue = false;
        this.separator = '';
        this.targetValue = '';
        this.mappingId = null;
        this.mapping = null;
        this.parameters = '{}';
    

        //reset UI
       this.template.querySelectorAll(".rounded-input").forEach((input) => {
        input.value = "";
        });
    }



    // ------------------------
    // Validation Last Update on 01-14-2026
    // ------------------------

    validateForm() {

        if (!this.mappingId) {
            return this.toastErr(' Field mapping\'s required  ');
        }

        if (!this.ruleType) {
            return this.toastErr('Rule type\'s required .Please choose one rule ');
        }

        if ((!this.fields || this.fields.length === 0) && this.ruleType === 'Concatenation') {
            return this.toastErr('Source fields\'s required .Please choose one source field ');
        }

        switch (this.ruleType) {
            case 'Concatenation':
                if (this.fields.length > 3) {
                    return this.toastErr('Maximum for concatenation  is 3 source fields ');
                }
                if (!this.separator) {
                    return this.toastErr('Please select a separator ');
                }
                break;

            case 'EmailMasking':
                if (!this.domain) {
                    return this.toastErr('Please select a domain');
                }
                if (this.fields.length === 0) {
                    return this.toastErr('Email is required');
                }
                break; 
            default:
                break
        }

        return true;
    }

    // ------------------------
    // Sauvegarde last Update on 01-16-2026
    // ------------------------
    
    
    async handleSaveTransformation(event) { 
        try{
           
            if (!this.validateForm()) {
                return;
            }

             // Extraire sourceColumn et targetField depuis le mapping
            const sourceColumn = this.mapping?.sourceColumn || '';
            const targetField = this.mapping?.targetField || '';

            const hasRuleExist = await doesTransformationExist({
                projectId: this.projectId,
                sourceColumn: sourceColumn,
                targetField: targetField,
                ruleType: this.ruleType.replaceAll(' ', '')
            });
 
           
            if (hasRuleExist) {
                this.close({
                    success: false,
                    message: 'Rule already exists',
                    variant: 'warning'
                });
                return;
            }
        
            this.parameters = this.prepareParameters(this.fields, this.separator,this.booleanValue);
            const payload = {
                projectId: this.projectId,
                mappingId: this.mappingId,
                ruleType: this.ruleType.replaceAll(' ',''),
                parameters: this.parameters,
                Field: this.fields.join(this.separator.toString()), //source fields here
                targetValue: this.targetValue, 
            }; 
        
            const rule = await createRule(payload);
            this.resetState();
            const ruleId = rule.Id; 
   
            this.close({
                success: true,
                ruleId: rule.Id,
                message:'Rule created successfully'
            });
           
  
             
        } catch (error) {
            console.error('Error creating rule:', error);
             this.close({
                success: false,
                message: error.body?.message || error.message || 'Unknown error',
                variant: 'error'
            });
        }
    }

     

    //mise à jour 
    async handleUpdateRule() {
        try {
            if (!this.validateForm()) {
                return;
            }

            this.parameters = this.prepareParameters(this.fields, this.separator, this.booleanValue);
            
            const payload = {
                ruleId: this.existingRuleId,
                projectId: this.projectId,
                mappingId: this.mappingId,
                ruleType: this.ruleType.replaceAll(' ', ''),
                parameters: this.parameters,
                Field: this.fields.join(this.separator.toString()),
                targetValue: this.targetValue,
            };

            await updateRule(payload);

            this.resetState();
           

            this.close({
                success: true,
                ruleId: this.existingRuleId,
                message: 'Rule updated successfully'
            });

        } catch (error) {
            console.error('Error updating rule:', error);
            this.close({
                success: false,
                message: error.body?.message || error.message || 'Unknown error',
                variant: 'error'
            });
        }
    }

    // ------------------------
    // Paramètres JSON
    // ------------------------

    prepareParameters(fields, separator ,booleanValue) {
        const type = this.ruleType.replaceAll(' ','');
        if (!type) {
            console.warn('ruleType absent, difficile de deviner ce que tu veux vraiment.');
            return JSON.stringify({});
        }

        let params = {};

        switch (type) {

            case 'Concatenation':
                params = {
                    targetType: 'concatenation',
                    fields: fields || [],
                    separator: separator || '\t'
                };
                break;

            case 'EmailMask': 
                params = {
                    targetType: 'email'
                };

                // on enlève les champs undefined
                Object.keys(params).forEach(k => params[k] === undefined && delete params[k]);
                break;
            
            case 'UpperCaseTransformation':
                params = {
                    targetType : 'uppercase'
                };
                break;

            case 'LowerCaseTransformation':
                params = {
                    targetType : 'lowercase'
                };
                break;
            case 'PhoneMask':
                params = {
                    targetType: 'phone',
                    preserveCountryCode: true
                };
                break;

            case 'BooleanTransformation':
                params = {
                    targetType: 'boolean',
                    trueValues: booleanValue  ? ['yes', 'true', '1'] : [],
                    falseValues: !booleanValue ?  ['no', 'false', '0'] : []
                };
                break;

            default:
                params = {};
            }

        console.log('Paramètres préparés:', params);
        return JSON.stringify(params);
    }

    // ------------------------
    // Toast helpers
    // ------------------------

    toastErr(msg) {
        this.showToast('Erreur', msg, 'error');
        return false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ------------------------
    // Wire: Picklist + Mappings
    // ------------------------
  
    

    @wire(getPickListValues, {
        objectApiName: TRANSFORMATION_OBJECT.objectApiName,
        fieldApiName: RULE_TYPE_FIELD.fieldApiName
    })
    wiredPicklistValues({ data, error }) {
        if (data) { 
            
            this.ruleTypeOptions = Object.entries(data).map(([value, label]) => ({
                label,
                value
            }));

             // assigner ruleType seulement si on a déjà une règle existante
         /*  if (this.existingRule) {
               this.hasLoadedRule = true;
               this.initialRuleType = this.existingRule.RuleType__c;
               
            console.log('exist rule value', this.initialRuleType)


                const match = this.ruleTypeOptions.find(
                    opt => {
                        console.log('Comparaison:', opt.label, this.initialRuleType);
                        return opt.label === this.initialRuleType;
                    }
               );
              
               console.log('match', match);

                this.ruleType = match ? match.value : this.initialRuleType;
            }*/

            console.log('Types de règles chargés:', this.ruleTypeOptions);
        } else if (error) {
            console.error('Erreur chargement types de règles:', error);
          //  this.toastErr('Impossible de charger les types de règles');
        }
    }

    @wire(getAllMappingsByProjectId, { projectId: '$projectId' })
    wiredMappings({ data, error }) {
        if (data) {
            console.log('Mappings reçus:', data);
            // Construire la Map ID -> targetField
            data.forEach(m => {
                // Stocker le targetField en minuscules si nécessaire
                const fieldName = m.targetField; // ou m.targetField.toLowerCase() pour minuscules
                this.mappingIdToFieldMap.set(m.id, fieldName);
            });
            
            console.log('Map créée:', this.mappingIdToFieldMap);
            this.syncSelectedColumns();
            // Options pour le combobox "Mapping Field"
            this.fieldMappingOptions = data.map(m => ({
                label: `${m.targetField} → ${m.sourceField || m.targetField }`,
                value: m.id
            }));
            
            // Options pour le dual-listbox "Targert Fields"
            this.targetFieldOptions = this.deDuplicateByLabel(
                data.map(m => ({
                    label: m.targetField,
                    value: m.id
                }))
            );
            
            console.log('Options mapping chargées:', this.fieldMappingOptions);
            console.log('Options champs sources chargées:', this.targetFieldOptions);
            
        } else if (error) {
            console.error('Erreur chargement mappings:', error);
            this.toastErr('Impossible de charger les mappings');
        }
    }

    // ------------------------
    // Getters
    // ------------------------

    get showConcatenationFields() {
        return this.ruleType === 'Concatenation';
    }

    get showEmailMaskingFields() {
        return this.ruleType === 'Email Masking' ||  this.ruleType === 'EmailMasking';
    }

    get showPhoneMaskField(){
        return this.ruleType === 'Phone Mask' || this.ruleType === 'PhoneMask';
    }

    get selectedFieldsCount() {
        return this.fields.length;
    }
    
    // Supprimer les doublons par label
    deDuplicateByLabel(options) {
        const seen = new Set();
        return options.filter(option => {
            if (seen.has(option.label)) {
                return false;
            }
            seen.add(option.label);
            return true;
        });
    }

    

    // ------------------------
// Gestion centralisée des erreurs
// ------------------------
handleError(error) {
    let errorMessage = 'Erreur inconnue';
    
    if (error.body) {
        if (error.body.message) {
            errorMessage = error.body.message;
        } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
            errorMessage = error.body.pageErrors[0].message;
        } else if (error.body.fieldErrors) {
            errorMessage = JSON.stringify(error.body.fieldErrors);
        }
        } else if (error.message) {
            errorMessage = error.message;
        }
        this.showToast('Erreur', errorMessage, 'error');
    }
}
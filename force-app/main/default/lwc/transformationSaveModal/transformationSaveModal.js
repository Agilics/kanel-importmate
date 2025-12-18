import { wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { log } from 'lightning/logger';
import TRANSFORMATION_OBJECT from '@salesforce/schema/TransformationRule__c'; 
import LightningModal from 'lightning/modal';
import RULE_TYPE_FIELD from '@salesforce/schema/TransformationRule__c.RuleType__c';

import createRule from '@salesforce/apex/TransformationController.createRule';
import applyTransformations from '@salesforce/apex/TransformationController.applyTransformations';
import getPickListValues from '@salesforce/apex/TransformationController.getPickListValues';
import getAllMappingsByProjectId from '@salesforce/apex/FieldMappingController.getAllMappingsByProjectId';

export default class TransformationSaveModal extends LightningModal {
    @api projectId;
    @api label;
    @api mappingId;  
    @api mapping;

    //target value for boolean 
    @track booleanValue = false;

    // Propriétés réactives
    ruleType = ''; 
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

    // ------------------------
    // Handlers UI
    // ------------------------
    get mappingInfo(){
        return `${this.mapping.version} -> ${this.mapping.sourceColumn} `
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
        this.close({ success: false });
    }

    // ------------------------
    // Validation
    // ------------------------

    validateForm() {
        console.log('=== VALIDATION ===');
        console.log('mappingId:', this.mappingId);
        console.log('ruleType:', this.ruleType);
        console.log('fields:', this.fields);
        console.log('separator:', this.separator);

        if (!this.mappingId) {
            return this.toastErr('Veuillez sélectionner un mapping de champ');
        }

        if (!this.ruleType) {
            return this.toastErr('Veuillez sélectionner un type de règle');
        }

        if ((!this.fields || this.fields.length === 0) && this.ruleType === 'Concatenation') {
            return this.toastErr('Veuillez sélectionner au moins un champ source');
        }

        switch (this.ruleType) {
            case 'Concatenation':
                if (this.fields.length > 3) {
                    return this.toastErr('Sélectionnez 3 champs maximum pour la concaténation');
                }
                if (!this.separator) {
                    return this.toastErr('Veuillez sélectionner un séparateur');
                }
                break;

            case 'EmailMasking':
                if (!this.domain) {
                    return this.toastErr('Veuillez spécifier un domaine pour le masquage email');
                }
                if (this.fields.length === 0) {
                    return this.toastErr('Veuillez sélectionner un champ email');
                }
                break;
    
        }

        return true;
    }

    // ------------------------
    // Sauvegarde
    // ------------------------
    
    
    async handleSaveTransformation() { 
        try{
           
            if (!this.validateForm()) {
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

            console.log('Payload envoyé:', JSON.stringify(payload, null, 2));
        
           
            const rule = await createRule(payload);
            const ruleId = rule.Id; 
            
            this.close(ruleId);
            
           this.showToast('Success', 'Rule added successfully with record ID:\t'+ ruleId , 'success');
           
        }catch(error){
           this.handleError(error); 
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
            console.log('Types de règles chargés:', this.ruleTypeOptions);
        } else if (error) {
            console.error('Erreur chargement types de règles:', error);
            this.toastErr('Impossible de charger les types de règles');
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
            
            // Options pour le combobox "Mapping Field"
            this.fieldMappingOptions = data.map(m => ({
                label: `${m.targetField} → ${m.sourceField || m.version}`,
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
/**
 * @Last Modification: 09-02-2026
 * @Last Modification By : Mouhamed NIANG
 * Modifications :
 * - add boolean value for boolean transformation prevent duplicate rules
 * - ReadOnly Field Mapping SourceField -> TargetField
 * - add update rule method
 * - Update UI/UX
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

    //target value for boolean 
    @track booleanValue = false;
 
    hasLoadedRule = false;

    @api mapping = { sourceColumn: '', targetField: '' };

    // Propriétés réactives
    @track ruleType;
    selectedColumns = []; // IDs sélectionnés dans le dual-listbox
    @track separator = '';
    fields = []; // Noms des targetFields['firstname', 'lastname']
    targetFields = [];
    @track targetValue;
    parameters = '{}';
    @track isBooleanTransformation = false;
    @track phone;
    @track domain;
    mappingIdToFieldMap = new Map(); // map: ID -> targetField (string)
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
            
            this.targetValue = data.TargetValue__c || '';
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
        
            // Charger les fields depuis Parameters.Fields
            if (params.Fields && Array.isArray(params.Fields) && params.Fields.length > 0) {
                this.fields = params.Fields;
            } else if (data.SourceFields__c) {
                this.fields = data.SourceFields__c.split(',').map(f => f.trim());
            } else {
                this.fields = [];
            }

            console.log('Fields chargés:', this.fields);

            // Si les options de picklist sont déjà chargées, assigner le ruleType maintenant
            if (this.ruleTypeOptions.length > 0 && !this.hasLoadedRule) {
                this.hasLoadedRule = true;
            
                const ruleTypeFromDB = data.RuleType__c;
                console.log('Rule Type from DB:', ruleTypeFromDB);

                const match = this.ruleTypeOptions.find(opt => {
                    return opt.value === ruleTypeFromDB || opt.label === ruleTypeFromDB;
                });
           
                this.ruleType = match ? match.value : ruleTypeFromDB;
            }
    
            this.getFieldsForBooleanTransformation(data, params);
            
            // Synchroniser selectedColumns après le chargement de la Map
            this.syncSelectedColumnsFromFields();
        }

        if (error) {
            console.error('Erreur chargement rule', error);
            this.toastErr('Impossible de charger la règle');
        }
    }

    getFieldsForBooleanTransformation(data, params) {
        // Gérer le cas Boolean Transformation
        if (data.RuleType__c === 'BooleanTransformation') {
            this.isBooleanTransformation = true;
            
            console.log('Boolean Transformation détectée');
            console.log('Parameters:', params);
            console.log('trueValues:', params.trueValues);
            console.log('falseValues:', params.falseValues);
            
            //  Logique corrigée pour déterminer booleanValue
            if (params.trueValues && params.trueValues.length > 0) {
                this.booleanValue = true;
                console.log('booleanValue = true (trueValues présents)');
            } else if (params.falseValues && params.falseValues.length > 0) {
                this.booleanValue = false;
                console.log('booleanValue = false (falseValues présents)');
            } else {
                // Valeur par défaut si aucune liste n'est remplie
                this.booleanValue = false;
                console.log('booleanValue = false (par défaut)');
            }
            
            console.log('Final booleanValue:', this.booleanValue);
        } else {
            this.isBooleanTransformation = false;
        }
    }
    
    syncSelectedColumnsFromFields() {
        if (!this.fields || this.fields.length === 0 || this.mappingIdToFieldMap.size === 0) {
            console.log('Pas de fields ou map vide, skip sync');
            return;
        }

        // Convertir les noms de champs en IDs
        this.selectedColumns = this.fields
            .map(fieldName => {
                // Trouver l'ID correspondant au nom du champ
                const entry = [...this.mappingIdToFieldMap.entries()]
                    .find(([id, mappedFieldName]) => mappedFieldName === fieldName);
                return entry ? entry[0] : null;
            })
            .filter(Boolean);
        
        console.log('selectedColumns synchronisés depuis fields:', this.selectedColumns);
        console.log('fields source:', this.fields);
    }

    get ruleTypeLabel() {
        if (!this.ruleType) {
            return '';
        }
        
        // Trouver le label correspondant à la valeur
        const option = this.ruleTypeOptions.find(opt => opt.label === this.existingRule?.RuleType__c);
        return option ? option.label : this.ruleType;
    }

    get modalLabel() {
        return this.isEdit ? 'Edit Rule' : 'Add New Rule';
    }
    
    // ------------------------
    // Handlers UI
    // ------------------------

    get source() {
        return this.mapping?.sourceColumn ?? '';
    }

    get target() {
        return this.mapping?.targetField ?? '';
    }

    get preSelectedColumns() {
        // Si on est en mode édition, utiliser selectedColumns existant
        if (this.isEdit && this.selectedColumns.length > 0) {
            return this.selectedColumns;
        }
        
        // Sinon, pré-sélectionner le targetField du mapping actuel
        if (this.mappingId) {
            // Trouver l'ID correspondant au targetField du mapping
            const targetId = [...this.mappingIdToFieldMap.entries()]
                .find(([id, fieldName]) => fieldName === this.target)?.[0];
            
            return targetId ? [targetId] : [];
        }
        
        return [];
    }

    handleFieldMappingChange(event) {
        this.mappingId = event.detail.value;
        console.log('Mapping sélectionné - ID:', this.mappingId);
    }

    handleTargetFieldsChange(event) {
        // event.detail.value contient les IDs sélectionnés
        this.selectedColumns = event.detail.value;
        
        // Convertir les IDs en targetFields (noms de champs)
        this.fields = this.selectedColumns
            .map(id => {
                const fieldName = this.mappingIdToFieldMap.get(id);
                return fieldName || null;
            })
            .filter(Boolean);
        
        console.log('IDs sélectionnés:', this.selectedColumns);
        console.log('Champs convertis:', this.fields);
    }

    handleRuleTypeChange(event) {
        this.ruleType = event.detail.value;
        const ruleTypeValue = this.ruleType.replaceAll(' ', '');
        if (ruleTypeValue === 'BooleanTransformation' || ruleTypeValue.includes('Boolean')) {
            this.isBooleanTransformation = true;
            //  Ne pas écraser booleanValue lors de l'édition
            if (!this.isEdit) {
                this.booleanValue = false; // Valeur par défaut pour nouvelle règle
            }
        } else {
            this.isBooleanTransformation = false;
        }
        console.log('Type de règle :', this.ruleType);
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

    handleBooleanValueChange(event) {
        this.booleanValue = event.target.checked;
        console.log(this.booleanValue);
    }
 
    handleCancel() {
        this.resetState();
        this.close({ success: false });
    }

    disconnectedCallback() {
        // Appelé quand le composant est détruit (modal fermé)
        this.resetState();
    }

    resetState() {
        // Réinitialiser toutes les propriétés
        this.ruleType = '';
        this.existingRule = null;
        this.isEdit = false;
        this.hasLoadedRule = false;
        this.fields = [];
        this.targetFields = [];
        this.existingRuleId = null;
        this.selectedColumns = [];
        this.isBooleanTransformation = false;
        this.booleanValue = false;
        this.separator = '';
        this.targetValue = '';
        this.mappingId = null;
        this.parameters = '{}';
        this.domain = '';
        this.phone = '';
        
        this.mapping = {
            sourceColumn: '',
            targetField: ''
        };

        // Reset UI
        Promise.resolve().then(() => {
            const inputs = this.template.querySelectorAll(".rounded-input");
            if (inputs && inputs.length > 0) {
                inputs.forEach((input) => {
                    input.value = "";
                });
            }
        
            const comboboxes = this.template.querySelectorAll("lightning-combobox");
            if (comboboxes && comboboxes.length > 0) {
                comboboxes.forEach((combo) => {
                    combo.value = null;
                });
            }
        });
    }

    // ------------------------
    // Validation Last Update on 01-14-2026
    // ------------------------

    validateForm(fields) {
        if (!this.mappingId) {
            return this.toastErr('Field mapping\'s required');
        }

        if (!this.ruleType) {
            return this.toastErr('Rule type\'s required. Please choose one rule');
        }

        if ((!Array.isArray(fields) || fields.length === 0) && this.ruleType === 'Concatenation') {
            return this.toastErr('Source fields\'s required. Please choose at least two source field');
        }

        switch (this.ruleType) {
            case 'Concatenation':
                if (fields.length === 0) {
                    return this.toastErr('Source fields\'s required. Please choose two or three source fields');
                }
                if (fields.length > 3) {
                    return this.toastErr('Maximum for concatenation is 3 source fields');
                }
                if (!this.separator) {
                    return this.toastErr('Please select a separator');
                }
                break;

            case 'EmailMasking':
                if (!this.domain) {
                    return this.toastErr('Please select a domain');
                }
                if (fields.length === 0) {
                    return this.toastErr('Email is required');
                }
                break; 
            default:
                break;
        }

        return true;
    }

    // ------------------------
    // Sauvegarde last Update on 09-02-2026
    // ------------------------
    
    async handleSaveTransformation(event) { 
        try {
            const ruleTypeValue = this.ruleType.replaceAll(' ', '');
            
            if (!this.validateForm(this.selectedColumns)) {
                return;
            }

            // Extraire sourceColumn et targetField depuis le mapping
            const sourceColumn = this.mapping?.sourceColumn || '';
            const targetField = this.mapping?.targetField || '';

            // CORRECTION: Convertir les IDs en noms de champs
            const targetFieldsArray = this.selectedColumns.map(id => {
                return this.mappingIdToFieldMap.get(id);
            }).filter(Boolean);

            // Pour Concatenation, utiliser le tableau de noms de champs
            // Pour les autres types, utiliser le targetField du mapping
            const Fields = ruleTypeValue === 'Concatenation' ? targetFieldsArray : [targetField];

            console.log('Fields à sauvegarder:', Fields);

            const hasRuleExist = await doesTransformationExist({
                projectId: this.projectId,
                sourceColumn: this.source,
                targetField: this.target,
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
        
            this.parameters = this.prepareParameters(Fields, this.separator, this.booleanValue);
            
            const payload = {
                projectId: this.projectId,
                mappingId: this.mappingId,
                ruleType: this.ruleType.replaceAll(' ', ''),
                parameters: this.parameters, 
                sourceFields: sourceColumn,
                Field: Fields,
                targetValue: this.targetValue, 
            }; 

            console.log('Create payload:', JSON.stringify(payload));
        
            const rule = await createRule(payload);
            const ruleId = rule.Id;
            
            this.resetState();
   
            this.close({
                success: true,
                ruleId: ruleId,
                message: 'Rule created successfully'
            });
             
        } catch (error) {
            console.error('Error creating rule:', error);
            this.resetState();
            this.close({
                success: false,
                message: error.body?.message || error.message || 'Unknown error',
                variant: 'error'
            });
        }
    }

    // ------------------------
    // Mise à jour 
    // ------------------------
    async handleUpdateRule() {
        try {
            const ruleTypeValue = this.ruleType.replaceAll(' ', '');
            
            if (!this.validateForm(this.selectedColumns)) {
                return;
            }

            const sep = ',';

            // CORRECTION: Conversion en liste des champs cibles
            const targetFields = this.selectedColumns.map(id => {
                return this.mappingIdToFieldMap.get(id);
            }).filter(Boolean);
            
            // Pour Concatenation, joindre les champs avec virgule
            const sourceFields = ruleTypeValue === 'Concatenation' 
                ? targetFields.join(',')
                : this.source;
            
            this.parameters = this.prepareParameters(targetFields, sep, this.booleanValue);
            
            const payload = {
                ruleId: this.existingRuleId,
                projectId: this.projectId,
                mappingId: this.mappingId,
                ruleType: this.ruleType.replaceAll(' ', ''),
                sourceFields: sourceFields,
                parameters: this.parameters,
                Fields: targetFields.length > 0 ? targetFields : [this.target],
                targetValue: this.targetValue,
            };

            console.log('Update payload:', JSON.stringify(payload));
            
            const savedRuleId = this.existingRuleId;
            await updateRule(payload);

            this.resetState();

            this.close({
                success: true,
                ruleId: savedRuleId,
                message: 'Rule updated successfully'
            });

        } catch (error) {
            console.error('Error updating rule:', error);
            this.resetState();
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

    prepareParameters(fields, separator, booleanValue) {
        const type = this.ruleType.replaceAll(' ', '');
        if (!type) {
            console.warn('ruleType absent');
            return JSON.stringify({});
        }

        let params = {};
        // Normalisation: si fields est une string unique, le transformer en tableau
        if (fields && !Array.isArray(fields)) {
            fields = [fields];
        }

        switch (type) {
            case 'Concatenation':
                params = {
                    targetType: 'concatenation',
                    Fields: fields || [],
                    separator: separator || '\t'
                };
                break;

            case 'EmailMask': 
                params = {
                    targetType: 'email',
                    domain: this.domain,
                    Fields: fields,
                };
                Object.keys(params).forEach(k => params[k] === undefined && delete params[k]);
                break;
            
            case 'UppercaseTransformation':
                params = {
                    targetType: 'uppercase',
                    Fields: fields
                };
                break;

            case 'LowercaseTransformation':
                params = {
                    targetType: 'lowercase',
                    Fields: fields
                };
                break;
                
            case 'PhoneMask':
                params = {
                    targetType: 'phone',
                    Fields: fields,
                    preserveCountryCode: true
                };
                break;

            case 'BooleanTransformation':
                params = {
                    targetType: 'boolean',
                    trueValues: booleanValue ? ['yes', 'true', '1'] : [],
                    falseValues: !booleanValue ? ['no', 'false', '0'] : [],
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
        }
    }

    @wire(getAllMappingsByProjectId, { projectId: '$projectId' })
    wiredMappings({ data, error }) {
        if (data) {
            console.log('Mappings reçus:', data);
            
            // CORRECTION: Stocker directement le nom du champ (string)
            data.forEach(m => {
                this.mappingIdToFieldMap.set(m.id, m.targetField);
            });
            
            console.log('Map créée:', this.mappingIdToFieldMap);
            
            // Synchroniser après avoir chargé la Map
            if (this.isEdit && this.fields.length > 0) {
                this.syncSelectedColumnsFromFields();
            }
            
            // Options pour le combobox "Mapping Field"
            this.fieldMappingOptions = data.map(m => ({
                label: `${m.targetField} → ${m.sourceField || m.targetField}`,
                value: m.id
            }));
            
            // Options pour le dual-listbox "Target Fields"
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
        return this.ruleType === 'Email Masking' || this.ruleType === 'EmailMasking';
    }

    get showPhoneMaskField() {
        return this.ruleType === 'Phone Mask' || this.ruleType === 'PhoneMask';
    }

    get selectedFieldsCount() {
        return this.preSelectedColumns.length;
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
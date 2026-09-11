/**
 * @Last Modification: 02-24-2026
 * @Last Modification By : NDEYE KHADY  NIANG
 * Modifications :
 * - Full Custom Labels integration (i18n)
 * - Picklist + Separator values translated via Custom Labels
 * - Fixed ESLint no-api-reassignments via internal copies _mapping, _mappingId, _isEdit
 */
import { wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import { refreshApex } from '@salesforce/apex';
import TRANSFORMATION_OBJECT from '@salesforce/schema/TransformationRule__c'; 
import LightningModal from 'lightning/modal';
import RULE_TYPE_FIELD from '@salesforce/schema/TransformationRule__c.RuleType__c';
import getRuleById from '@salesforce/apex/TransformationController.getRuleById';
import createRule from '@salesforce/apex/TransformationController.createRule';
import getPickListValues from '@salesforce/apex/TransformationController.getPickListValues';
import getAllMappingsByProjectId from '@salesforce/apex/FieldMappingController.getAllMappingsByProjectId';
import doesTransformationExist from '@salesforce/apex/TransformationController.doesTransformationExist';
import updateRule from '@salesforce/apex/TransformationController.updateRule';

// ===== Custom Labels — existing =====
import LABEL_SOURCE_COLUMN from '@salesforce/label/c.IM_TR_SourceColumn';
import LABEL_TARGET_FIELD from '@salesforce/label/c.IM_TR_TargetField';
import LABEL_ERROR_TITLE from '@salesforce/label/c.IM_TR_Error_Title';

// ===== Custom Labels — Modal =====
import LABEL_MODAL_ADD_RULE from '@salesforce/label/c.IM_TR_Modal_AddRule';
import LABEL_MODAL_EDIT_RULE from '@salesforce/label/c.IM_TR_Modal_EditRule';
import LABEL_MODAL_SECTION_MAPPING from '@salesforce/label/c.IM_TR_Modal_SectionMapping';
import LABEL_MODAL_SECTION_RULES from '@salesforce/label/c.IM_TR_Modal_SectionRules';
import LABEL_MODAL_RULE_TYPE from '@salesforce/label/c.IM_TR_Modal_RuleType';
import LABEL_MODAL_SELECT_OPTION from '@salesforce/label/c.IM_TR_Modal_SelectOption';
import LABEL_MODAL_SOURCE_FIELDS from '@salesforce/label/c.IM_TR_Modal_SourceFields';
import LABEL_MODAL_SOURCE_LABEL from '@salesforce/label/c.IM_TR_Modal_SourceLabel';
import LABEL_MODAL_SELECTED_LABEL from '@salesforce/label/c.IM_TR_Modal_SelectedLabel';
import LABEL_MODAL_SELECT_FIELDS_HELP from '@salesforce/label/c.IM_TR_Modal_SelectFieldsHelp';
import LABEL_MODAL_ON from '@salesforce/label/c.IM_TR_Modal_On';
import LABEL_MODAL_SEPARATOR from '@salesforce/label/c.IM_TR_Modal_Separator';
import LABEL_MODAL_CHOOSE_BOOLEAN from '@salesforce/label/c.IM_TR_Modal_ChooseBoolean';
import LABEL_MODAL_BOOLEAN_VALUE from '@salesforce/label/c.IM_TR_Modal_BooleanValue';
import LABEL_MODAL_YES from '@salesforce/label/c.IM_TR_Modal_Yes';
import LABEL_MODAL_NO from '@salesforce/label/c.IM_TR_Modal_No';
import LABEL_MODAL_CANCEL from '@salesforce/label/c.IM_TR_Modal_Cancel';
import LABEL_MODAL_SAVE_RULE from '@salesforce/label/c.IM_TR_Modal_SaveRule';
import LABEL_MODAL_UPDATE_RULE from '@salesforce/label/c.IM_TR_Modal_UpdateRule';

// ===== Custom Labels — Separator options =====
import LABEL_SEP_TAB from '@salesforce/label/c.IM_TR_Sep_Tab';
import LABEL_SEP_COMMA from '@salesforce/label/c.IM_TR_Sep_Comma';
import LABEL_SEP_SPACE from '@salesforce/label/c.IM_TR_Sep_Space';
import LABEL_SEP_SEMICOMMA from '@salesforce/label/c.IM_TR_Sep_SemiComma';
import LABEL_SEP_NEWLINE from '@salesforce/label/c.IM_TR_Sep_NewLine';

// ===== Custom Labels — Picklist values =====
import LABEL_PICKLIST_BOOLEAN from '@salesforce/label/c.IM_TR_Picklist_BooleanTransformation';
import LABEL_PICKLIST_CONCATENATION from '@salesforce/label/c.IM_TR_Picklist_Concatenation';
import LABEL_PICKLIST_EMAIL_MASK from '@salesforce/label/c.IM_TR_Picklist_EmailMask';
import LABEL_PICKLIST_PHONE_MASK from '@salesforce/label/c.IM_TR_Picklist_PhoneMask';
import LABEL_PICKLIST_LOWERCASE from '@salesforce/label/c.IM_TR_Picklist_LowercaseTransformation';
import LABEL_PICKLIST_UPPERCASE from '@salesforce/label/c.IM_TR_Picklist_UppercaseTransformation';

const PICKLIST_LABEL_MAP = {
    BooleanTransformation: LABEL_PICKLIST_BOOLEAN,
    Concatenation: LABEL_PICKLIST_CONCATENATION,
    EmailMask: LABEL_PICKLIST_EMAIL_MASK,
    PhoneMask: LABEL_PICKLIST_PHONE_MASK,
    LowercaseTransformation: LABEL_PICKLIST_LOWERCASE,
    UppercaseTransformation: LABEL_PICKLIST_UPPERCASE,
    'Boolean Transformation': LABEL_PICKLIST_BOOLEAN,
    'Email Mask': LABEL_PICKLIST_EMAIL_MASK,
    'Phone Mask': LABEL_PICKLIST_PHONE_MASK,
    'Lowercase Transformation': LABEL_PICKLIST_LOWERCASE,
    'Uppercase Transformation': LABEL_PICKLIST_UPPERCASE,
    Boolean_Transformation: LABEL_PICKLIST_BOOLEAN,
    Email_Mask: LABEL_PICKLIST_EMAIL_MASK,
    Phone_Mask: LABEL_PICKLIST_PHONE_MASK,
    Lowercase_Transformation: LABEL_PICKLIST_LOWERCASE,
    Uppercase_Transformation: LABEL_PICKLIST_UPPERCASE,
};

export default class TransformationSaveModal extends LightningModal {

    // ===== @api — lecture seule, jamais réassignées =====
    @api projectId;
    @api existingRuleId;
    @api isEdit = false;
    @api mappingId;
    @api mapping = { sourceColumn: '', targetField: '' };

    // ===== Copies internes mutables (fix ESLint no-api-reassignments) =====
    @track _isEdit = false;
    @track _mapping = { sourceColumn: '', targetField: '' };
    @track _mappingId = null;

    @track booleanValue = false;
    hasLoadedRule = false;
    existingRule = null;

    @track ruleType;
    selectedColumns = [];
    @track separator = '';
    fields = [];
    targetFields = [];
    @track targetValue;
    parameters = '{}';
    @track isBooleanTransformation = false;
    @track phone;
    @track domain;
    mappingIdToFieldMap = new Map();
    ruleTypeOptions = [];
    fieldMappingOptions = [];
    targetFieldOptions = [];
    wiredResultToRefresh;

    separatorOptions = [
        { label: LABEL_SEP_TAB, value: '\t' },
        { label: LABEL_SEP_COMMA, value: ',' },
        { label: LABEL_SEP_SPACE, value: ' ' },
        { label: LABEL_SEP_SEMICOMMA, value: ';' },
        { label: LABEL_SEP_NEWLINE, value: '\n' }
    ];

    labels = {
        sourceColumn: LABEL_SOURCE_COLUMN,
        targetField: LABEL_TARGET_FIELD,
        sectionMapping: LABEL_MODAL_SECTION_MAPPING,
        sectionRules: LABEL_MODAL_SECTION_RULES,
        ruleType: LABEL_MODAL_RULE_TYPE,
        selectOption: LABEL_MODAL_SELECT_OPTION,
        sourceFields: LABEL_MODAL_SOURCE_FIELDS,
        sourceLabel: LABEL_MODAL_SOURCE_LABEL,
        selectedLabel: LABEL_MODAL_SELECTED_LABEL,
        selectFieldsHelp: LABEL_MODAL_SELECT_FIELDS_HELP,
        onLabel: LABEL_MODAL_ON,
        separator: LABEL_MODAL_SEPARATOR,
        chooseBooleanValue: LABEL_MODAL_CHOOSE_BOOLEAN,
        booleanValueLabel: LABEL_MODAL_BOOLEAN_VALUE,
        yes: LABEL_MODAL_YES,
        no: LABEL_MODAL_NO,
        cancel: LABEL_MODAL_CANCEL,
        saveRule: LABEL_MODAL_SAVE_RULE,
        updateRule: LABEL_MODAL_UPDATE_RULE,
    };

    // ===== Lifecycle =====
    connectedCallback() {
        this._isEdit = this.isEdit;
        this._mappingId = this.mappingId;
        this._mapping = this.mapping ? { ...this.mapping } : { sourceColumn: '', targetField: '' };
    }

    // ===== Getters =====
    get modalLabel() {
        return this._isEdit ? LABEL_MODAL_EDIT_RULE : LABEL_MODAL_ADD_RULE;
    }

    // Exposé au template (les props @track avec _ sont accessibles depuis le HTML)
    get isEditMode() {
        return this._isEdit;
    }

    get source() {
        return this._mapping?.sourceColumn ?? '';
    }

    get target() {
        return this._mapping?.targetField ?? '';
    }

    get preSelectedColumns() {
        if (this._isEdit && this.selectedColumns.length > 0) return this.selectedColumns;
        if (this._mappingId) {
            const targetId = [...this.mappingIdToFieldMap.entries()]
                .find(([, fieldName]) => fieldName === this.target)?.[0];
            return targetId ? [targetId] : [];
        }
        return [];
    }

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

    get ruleTypeOptionsWithSelected() {
        return this.ruleTypeOptions.map(o => ({ ...o, isSelected: o.value === this.ruleType }));
    }

    get separatorOptionsWithSelected() {
        return this.separatorOptions.map(o => ({ ...o, isSelected: o.value === this.separator }));
    }

    get targetFieldOptionsWithSelected() {
        return this.targetFieldOptions.map(o => ({ ...o, isSelected: this.preSelectedColumns.includes(o.value) }));
    }

    get booleanDisplayLabel() {
        return this.booleanValue ? this.labels.yes : this.labels.no;
    }

    // ===== Wire: charger règle existante =====
    @wire(getRuleById, { ruleId: '$existingRuleId' })
    wiredExistingRuleById(result) {
        this.wiredResultToRefresh = result;
        const { data, error } = result;

        if (data) {
            // copies internes — pas de réassignation des @api
            this._isEdit = true;
            this.existingRule = data;
            this.targetValue = data.TargetValue__c || '';
            this._mappingId = data.FieldMapping__c;
            this._mapping = {
                sourceColumn: data.FieldMapping__r?.SourceColumn__c || '',
                targetField: data.FieldMapping__r?.TargetField__c || ''
            };

            let params = {};
            try {
                params = data.Parameters__c ? JSON.parse(data.Parameters__c) : {};
            } catch {
                params = {};
            }

            this.separator = params.separator || ',';

            if (params.Fields && Array.isArray(params.Fields) && params.Fields.length > 0) {
                this.fields = params.Fields;
            } else if (data.SourceFields__c) {
                this.fields = data.SourceFields__c.split(',').map(f => f.trim());
            } else {
                this.fields = [];
            }

            this.syncRuleType(data);
            this.getFieldsForBooleanTransformation(data, params);
            this.syncSelectedColumnsFromFields();
        }

        if (error) {
            console.error('Erreur chargement rule', error);
            this.toastErr('Impossible de charger la règle');
        }
    }

    syncRuleType(existingRule) {
        if (existingRule && this.ruleTypeOptions.length > 0 && !this.hasLoadedRule) {
            const ruleTypeFromDB = existingRule.RuleType__c;
            const match = this.ruleTypeOptions.find(opt =>
                opt.value === ruleTypeFromDB || opt.label === ruleTypeFromDB
            );
            if (match) {
                this.ruleType = match.value;
                this.hasLoadedRule = true;
            }
        }
    }

    getFieldsForBooleanTransformation(data, params) {
        if (data.RuleType__c === 'BooleanTransformation') {
            this.isBooleanTransformation = true;
            this.booleanValue = !!(params.trueValues && params.trueValues.length > 0);
        } else {
            this.isBooleanTransformation = false;
        }
    }

    syncSelectedColumnsFromFields() {
        if (!this.fields || this.fields.length === 0 || this.mappingIdToFieldMap.size === 0) return;
        this.selectedColumns = this.fields
            .map(fieldName => {
                const entry = [...this.mappingIdToFieldMap.entries()]
                    .find(([, mapped]) => mapped === fieldName);
                return entry ? entry[0] : null;
            })
            .filter(Boolean);
    }

    // ===== Handlers =====
    handleFieldMappingChange(event) {
        this._mappingId = event.detail.value;
    }

    handleTargetFieldsChange(event) {
        this.selectedColumns = Array.from(event.target.selectedOptions).map(o => o.value);
        this.fields = this.selectedColumns
            .map(id => this.mappingIdToFieldMap.get(id) || null)
            .filter(Boolean);
    }

    handleRuleTypeChange(event) {
        this.ruleType = event.target.value ?? event.detail?.value ?? '';
        const val = this.ruleType.replaceAll(' ', '');
        if (val === 'BooleanTransformation' || val.includes('Boolean')) {
            this.isBooleanTransformation = true;
            if (!this._isEdit) this.booleanValue = false;
        } else {
            this.isBooleanTransformation = false;
        }
    }

    handleSeparatorChange(event) { this.separator = event.target.value ?? event.detail?.value ?? ''; }
    handleTargetValueChange(event) { this.targetValue = event.detail.value; }
    handleDomainChange(event) { this.domain = event.detail.value; }
    handleBooleanValueChange(event) { this.booleanValue = event.target.checked; }

    handleCancel() {
        this.resetState();
        this.close();
    }

    disconnectedCallback() {
        this.resetState();
    }

    @api
    resetState() {
        this.ruleType = undefined;
        this.existingRule = null;
        this._isEdit = false;
        this.hasLoadedRule = false;
        this.fields = [];
        this.selectedColumns = [];
        this.isBooleanTransformation = false;
        this.booleanValue = false;
        this.separator = '';
        this.targetValue = '';
        this._mappingId = null;
        this.domain = '';
        this.phone = '';
        this._mapping = { sourceColumn: '', targetField: '' };

        // Native elements re-render reactively from reset state — no DOM manipulation needed
    }

    // ===== Validation =====
    validateForm(fields) {
        if (!this._mappingId) return this.toastErr("Field mapping's required");
        if (!this.ruleType) return this.toastErr("Rule type's required. Please choose one rule");
        if ((!Array.isArray(fields) || fields.length === 0) && this.ruleType === 'Concatenation') {
            return this.toastErr("Source fields's required. Please choose at least two source field");
        }
        switch (this.ruleType) {
            case 'Concatenation':
                if (fields.length === 0) return this.toastErr('Please choose two or three source fields');
                if (fields.length > 3) return this.toastErr('Maximum for concatenation is 3 source fields');
                if (!this.separator) return this.toastErr('Please select a separator');
                break;
            case 'EmailMasking':
                if (!this.domain) return this.toastErr('Please select a domain');
                if (fields.length === 0) return this.toastErr('Email is required');
                break;
            default:
                break;
        }
        return true;
    }

    // ===== Save =====
    async handleSaveTransformation() {
        try {
            const ruleTypeValue = this.ruleType.replaceAll(' ', '');
            if (!this.validateForm(this.selectedColumns)) return;

            const targetField = this._mapping?.targetField || '';
            const targetFieldsArray = this.selectedColumns
                .map(id => this.mappingIdToFieldMap.get(id))
                .filter(Boolean);
            const Fields = ruleTypeValue === 'Concatenation' ? targetFieldsArray : [targetField];

            const hasRuleExist = await doesTransformationExist({
                projectId: this.projectId,
                sourceColumn: this.source,
                targetField: this.target,
                ruleType: ruleTypeValue
            });

            if (hasRuleExist) {
                this.close({ success: false, message: 'Rule already exists', variant: 'warning' });
                return;
            }

            this.parameters = this.prepareParameters(Fields, this.separator, this.booleanValue);

            const payload = {
                projectId: this.projectId,
                mappingId: this._mappingId,
                ruleType: ruleTypeValue,
                parameters: this.parameters,
                sourceFields: this._mapping?.sourceColumn || '',
                Field: Fields,
                targetValue: this.targetValue,
            };

            const rule = await createRule(payload);
            this.resetState();
            this.close({ success: true, ruleId: rule.Id, message: 'Rule created successfully' });

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

    // ===== Update =====
    async handleUpdateRule() {
        try {
            const ruleTypeValue = this.ruleType.replaceAll(' ', '');
            if (!this.validateForm(this.selectedColumns)) return;

            const targetFields = this.selectedColumns
                .map(id => this.mappingIdToFieldMap.get(id))
                .filter(Boolean);
            const sourceFields = ruleTypeValue === 'Concatenation' ? targetFields.join(',') : this.source;
            this.parameters = this.prepareParameters(targetFields, ',', this.booleanValue);

            const payload = {
                ruleId: this.existingRuleId,
                projectId: this.projectId,
                mappingId: this._mappingId,
                ruleType: ruleTypeValue,
                sourceFields: sourceFields,
                parameters: this.parameters,
                Fields: targetFields.length > 0 ? targetFields : [this.target],
                targetValue: this.targetValue,
            };

            const savedRuleId = this.existingRuleId;
            await updateRule(payload);
            await refreshApex(this.wiredResultToRefresh);
            this.resetState();
            this.close({ success: true, ruleId: savedRuleId, message: 'Rule updated successfully' });

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

    // ===== Parameters =====
    prepareParameters(fields, separator, booleanValue) {
        const type = this.ruleType.replaceAll(' ', '');
        if (!type) return JSON.stringify({});
        let f = fields;
        if (f && !Array.isArray(f)) f = [f];

        switch (type) {
            case 'Concatenation':
                return JSON.stringify({ targetType: 'concatenation', Fields: f || [], separator: separator || '\t' });
            case 'EmailMask':
                return JSON.stringify({ targetType: 'email', domain: this.domain, Fields: f });
            case 'UppercaseTransformation':
                return JSON.stringify({ targetType: 'uppercase', Fields: f });
            case 'LowercaseTransformation':
                return JSON.stringify({ targetType: 'lowercase', Fields: f });
            case 'PhoneMask':
                return JSON.stringify({ targetType: 'phone', Fields: f, preserveCountryCode: true });
            case 'BooleanTransformation':
                return JSON.stringify({
                    targetType: 'boolean',
                    trueValues: booleanValue ? ['yes', 'true', '1'] : [],
                    falseValues: !booleanValue ? ['no', 'false', '0'] : [],
                });
            default:
                return JSON.stringify({});
        }
    }

    toastErr(msg) {
        this.showToast(LABEL_ERROR_TITLE, msg, 'error');
        return false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ===== Wire: Picklist =====
    @wire(getPickListValues, {
        objectApiName: TRANSFORMATION_OBJECT.objectApiName,
        fieldApiName: RULE_TYPE_FIELD.fieldApiName
    })
    wiredPicklistValues({ data, error }) {
        if (data) {
            this.ruleTypeOptions = Object.keys(data).map(apiValue => ({
                value: apiValue,
                label: PICKLIST_LABEL_MAP[apiValue] ||
                       PICKLIST_LABEL_MAP[apiValue.replaceAll('_', '')] ||
                       PICKLIST_LABEL_MAP[apiValue.replaceAll(' ', '')] ||
                       apiValue
            }));
        } else if (error) {
            console.error('Erreur chargement types de regles:', error);
        }
    }

    // ===== Wire: Mappings =====
    @wire(getAllMappingsByProjectId, { projectId: '$projectId' })
    wiredMappings({ data, error }) {
        if (data) {
            data.forEach(m => this.mappingIdToFieldMap.set(m.id, m.targetField));
            if (this._isEdit && this.fields.length > 0) this.syncSelectedColumnsFromFields();
            this.fieldMappingOptions = data.map(m => ({
                label: `${m.targetField} → ${m.sourceField || m.targetField}`,
                value: m.id
            }));
            this.targetFieldOptions = this.deDuplicateByLabel(
                data.map(m => ({ label: m.targetField, value: m.id }))
            );
        } else if (error) {
            console.error('Erreur chargement mappings:', error);
            this.toastErr('Impossible de charger les mappings');
        }
    }

    deDuplicateByLabel(options) {
        const seen = new Set();
        return options.filter(option => {
            if (seen.has(option.label)) return false;
            seen.add(option.label);
            return true;
        });
    }

    handleError(error) {
        let errorMessage = 'Erreur inconnue';
        if (error.body) {
            if (error.body.message) errorMessage = error.body.message;
            else if (error.body.pageErrors?.length > 0) errorMessage = error.body.pageErrors[0].message;
            else if (error.body.fieldErrors) errorMessage = JSON.stringify(error.body.fieldErrors);
        } else if (error.message) {
            errorMessage = error.message;
        }
        this.showToast(LABEL_ERROR_TITLE, errorMessage, 'error');
    }
}
/**
 * @author : Mouhamed NIANG
 * @date : 09/02/2026 
 * @Modification : 
 *  - Integrated Custom Labels for i18n
 *  - Picklist values translated via IM_TR_Picklist_* labels
 */
import { LightningElement, api, wire, track } from "lwc";
import TransformationModal from 'c/transformationSaveModal';
import LightningConfirm from 'lightning/confirm';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchProjetById from '@salesforce/apex/ImportProjectController.searchProjetById'; 
import getRulesByProjectId from "@salesforce/apex/TransformationController.getRulesByProjectId";
import deleteTransformationById from "@salesforce/apex/TransformationController.deleteTransformationById";
import { refreshApex } from '@salesforce/apex';

// ===== Custom Labels — Page =====
import LABEL_TITLE from '@salesforce/label/c.IM_TR_Title';
import LABEL_SUBTITLE from '@salesforce/label/c.IM_TR_Subtitle';
import LABEL_NO_RULE from '@salesforce/label/c.IM_TR_NoRule';
import LABEL_BACK_TO_MAPPING from '@salesforce/label/c.IM_TR_BackToMapping';
import LABEL_SAVE_AS_TEMPLATE from '@salesforce/label/c.IM_TR_SaveAsTemplate';
import LABEL_CONTINUE_TO_VALIDATION from '@salesforce/label/c.IM_TR_ContinueToValidation';
import LABEL_SOURCE_COLUMN from '@salesforce/label/c.IM_TR_SourceColumn';
import LABEL_UNKNOWN_FIELD from '@salesforce/label/c.IM_TR_UnknownField';
import LABEL_ERROR_TITLE from '@salesforce/label/c.IM_TR_Error_Title';
import LABEL_WARNING_TITLE from '@salesforce/label/c.IM_TR_Warning_Title';
import LABEL_DELETE_SUCCESS_TITLE from '@salesforce/label/c.IM_TR_DeleteSuccess_Title';
import LABEL_DELETE_SUCCESS_MESSAGE from '@salesforce/label/c.IM_TR_DeleteSuccess_Message';
import LABEL_DELETE_CONFIRM_LABEL from '@salesforce/label/c.IM_TR_DeleteConfirm_Label';
import LABEL_DELETE_CONFIRM_MESSAGE from '@salesforce/label/c.IM_TR_DeleteConfirm_Message';
import LABEL_ERROR_CREATE_RULE from '@salesforce/label/c.IM_TR_Error_CreateRule';
import LABEL_ERROR_DELETE_RULE from '@salesforce/label/c.IM_TR_Error_DeleteRule';

// ===== Custom Labels — Picklist values =====
import LABEL_PICKLIST_BOOLEAN from '@salesforce/label/c.IM_TR_Picklist_BooleanTransformation';
import LABEL_PICKLIST_CONCATENATION from '@salesforce/label/c.IM_TR_Picklist_Concatenation';
import LABEL_PICKLIST_EMAIL_MASK from '@salesforce/label/c.IM_TR_Picklist_EmailMask';
import LABEL_PICKLIST_PHONE_MASK from '@salesforce/label/c.IM_TR_Picklist_PhoneMask';
import LABEL_PICKLIST_LOWERCASE from '@salesforce/label/c.IM_TR_Picklist_LowercaseTransformation';
import LABEL_PICKLIST_UPPERCASE from '@salesforce/label/c.IM_TR_Picklist_UppercaseTransformation';

const DEFAULT_PAGE_SIZE = 4;

export default class TransformationPage extends LightningElement {
  isWarningBadge = true;
  @api projectId; 
  @wire(searchProjetById, { projectId: "$projectId" }) selectedProject; 
  @track transformationsByMappingId = [];
  wiredTransformationResults = [];
  _wiredResult;
  @track mappingId;
  @track showMappings = false; 
  status;

  pageIndex = 1;
  pageSize = DEFAULT_PAGE_SIZE;
  activeTransformationTab = "all";

  labels = {
    title: LABEL_TITLE,
    subtitle: LABEL_SUBTITLE,
    noRule: LABEL_NO_RULE,
    backToMapping: LABEL_BACK_TO_MAPPING,
    saveAsTemplate: LABEL_SAVE_AS_TEMPLATE,
    continueToValidation: LABEL_CONTINUE_TO_VALIDATION,
  };

  @wire(getRulesByProjectId, { projectId: '$projectId' })
  wiredTransformations(result) {
    this._wiredResult = result;
    const { error, data } = result;

    if (data) {
      this.wiredTransformationResults = data.map(rule => {
        const iconConfig = this.getIconConfig(rule.RuleType__c);
        const category = this.getCategory(rule.RuleType__c); 
        return {
          id: rule.Id,
          rule: rule.RuleType__c,
          category,
          displayTitle: iconConfig.title,
          displaySubtitle: `${LABEL_SOURCE_COLUMN} : ${rule.FieldMapping__r.SourceColumn__c ?? LABEL_UNKNOWN_FIELD} → ${rule.FieldMapping__r?.TargetField__c ?? LABEL_UNKNOWN_FIELD}`,
          iconName: iconConfig.icon,
          iconBoxClass: iconConfig.boxClass,
          headIconClass: iconConfig.iconClass,
          showOrder: rule.Order__c ? true : false,
          order: rule.Order__c, 
          targetField: rule.FieldMapping__r.TargetField__c,
          formattedRules: this.formatRuleContent(rule),
        };
      });
    } else if (error) {
      console.error('Erreur chargement transformations:', error);
      this.wiredTransformationResults = [];
      this.showToast(LABEL_ERROR_TITLE, error?.body?.message || LABEL_ERROR_CREATE_RULE, 'error');
    }
  }

  getCategory(ruleType) {
    if (!ruleType) return 'other';
    const t = ruleType.toLowerCase();
    if (t.includes('boolean')) return 'boolean';
    if (t.includes('upper') || t.includes('lower') || t.includes('concatenate') || t.includes('concatenation')) return 'case';
    if (t.includes('email') || t.includes('phone') || t.includes('mask')) return 'mask';
    return 'other';
  }

  get filteredTransformations() {
    if (!this.wiredTransformationResults) return [];
    if (this.activeTransformationTab === 'all') return this.wiredTransformationResults;
    return this.wiredTransformationResults.filter(t => t.category === this.activeTransformationTab);
  }

  get pagedTransformations() {
    const start = (this.pageIndex - 1) * this.pageSize;
    return this.filteredTransformations.slice(start, start + this.pageSize);
  }

  async handleAddTransformation(event) {  
    try {
      this.refreshTransformations();
      const result = await TransformationModal.open({ 
        size: 'medium',
        description: 'Ce modal permet la création de nouvelle règle transformation avec les mappings',
        projectId: this.projectId,
        targetObject: this.selectedProject?.data?.TargetObject__c, 
        mappingId: event.detail.mappingId,
        mapping: event.detail.mapping,
        isEdit: false,
      });

      if (!result) return;

      if (result.success) {
        await refreshApex(this._wiredResult);
        this.showToast(LABEL_DELETE_SUCCESS_TITLE, result.message, 'success');
      }
    } catch (error) {
      console.error('Erreur lors de la création:', error);
      this.showToast(LABEL_ERROR_TITLE, error.message || LABEL_ERROR_CREATE_RULE, 'error');
    }
  }

  async refreshTransformations() {
    if (this._wiredResult) await refreshApex(this._wiredResult);
  }

  handleNextStep() {
    this.dispatchEvent(new CustomEvent('next', { detail: { transformationId: this.transformationId } }));
  }

  handlePrevious() {
    this.dispatchEvent(new CustomEvent("previous"));
  }

  handleTransformationChange(event) {
    this.activeTransformationTab = event.detail.activetab; 
    this.pageIndex = 1;
  }

  resetPaginationIfNeeded() {
    const total = this.filteredTransformations.length;
    const maxPage = Math.max(1, Math.ceil(total / this.pageSize));
    if (this.pageIndex > maxPage) this.pageIndex = maxPage;
  }

  // ✅ getIconConfig utilise les Custom Labels traduits pour les titres
  getIconConfig(type) {
    switch(type) {
      case 'EmailMask':
        return {
          title: LABEL_PICKLIST_EMAIL_MASK,
          icon: 'utility:email',
          boxClass: 'box-icon is-centered email-card-icon-box',
          iconClass: 'icon is-centered custom-icon-email'
        };
      case 'PhoneMask':
        return {
          title: LABEL_PICKLIST_PHONE_MASK,
          icon: 'utility:call',
          boxClass: 'box-icon is-centered phone-card-icon-box',
          iconClass: 'icon is-centered custom-icon-phone'
        };
      case 'Concatenation':
        return {
          title: LABEL_PICKLIST_CONCATENATION,
          icon: 'utility:merge',
          boxClass: 'box-icon is-centered lead-card-icon-box',
          iconClass: 'icon is-centered custom-icon-product_transfer'
        };
      case 'LowercaseTransformation':
        return {
          title: LABEL_PICKLIST_LOWERCASE,
          icon: 'utility:text',
          boxClass: 'box-icon is-centered lead-card-icon-box',
          iconClass: 'icon is-centered custom-icon-product_transfer'
        };
      case 'UppercaseTransformation':
        return {
          title: LABEL_PICKLIST_UPPERCASE,
          icon: 'utility:display_rich_text',
          boxClass: 'box-icon is-centered lead-card-icon-box',
          iconClass: 'icon is-centered custom-icon-product_transfer'
        };
      default:
        return {
          title: LABEL_PICKLIST_BOOLEAN,
          icon: 'utility:settings',
          boxClass: 'box-icon is-centered lead-card-icon-box',
          iconClass: 'icon is-centered custom-icon-product_transfer'
        };
    }
  }

  formatRuleContent(rule) {
    const parsed = rule.Parameters__c ? JSON.parse(rule.Parameters__c) : {};
    return Object.entries(parsed).map(([key, value]) => ({ label: `${key}: ${value}` }));
  }

  get iconName() {
    return this.showMappings ? 'utility:add' : 'utility:hide';
  } 

  handleShowMappings() {
    this.showMappings = !this.showMappings;
    return this.showMappings;
  }

  handleBackToMapping() {
    this.dispatchEvent(new CustomEvent("previous"));
  }

  handlePageChange(event) {
    const { pageIndex, showingFrom, showingTo } = event.detail;
    this.pageIndex = pageIndex;
    this.showingFrom = showingFrom;
    this.showingTo = showingTo;
  }

  async handleEditTransformation(event) {
    try {
      const existingRuleId = event.detail.ruleId; 
      const ruleType = this._wiredResult.data.find(rule => rule.Id === existingRuleId)?.RuleType__c; 
      const modalSize = (ruleType === 'Concatenation' || ruleType === 'BooleanTransformation') ? 'large' : 'small';

      const result = await TransformationModal.open({
        size: modalSize,
        description: 'Ce modal permet la modification de règle transformation avec les mappings',
        projectId: this.projectId,
        targetObject: this.selectedProject?.data?.TargetObject__c,
        mappingId: event.detail.mappingId,
        mapping: event.detail.mapping,
        isEdit: true,
        existingRuleId: existingRuleId
      });

      if (!result || result === 'okay') return;

      if (result.success) {
        await refreshApex(this._wiredResult);
        this.showToast(LABEL_DELETE_SUCCESS_TITLE, result.message, 'success');
      } else if (result.message) {
        this.showToast(LABEL_WARNING_TITLE, result.message, result.variant || 'warning');
      }
    } catch (error) {
      console.error('Erreur lors de la modification:', error);
      this.showToast(LABEL_ERROR_TITLE, error.message || LABEL_ERROR_CREATE_RULE, 'error');
    }
  }

  async handleTransformationDelete(event) {
    try { 
      const ruleId = event.detail; 
      const isConfirm = await LightningConfirm.open({
        message: LABEL_DELETE_CONFIRM_MESSAGE,
        variant: "header",
        label: LABEL_DELETE_CONFIRM_LABEL, 
        theme: 'warning'
      }); 
      
      if (!isConfirm) return;

      await deleteTransformationById({ transformationId: ruleId });
      await refreshApex(this._wiredResult);
      this.resetPaginationIfNeeded();

      this.dispatchEvent(new ShowToastEvent({
        title: LABEL_DELETE_SUCCESS_TITLE,
        message: LABEL_DELETE_SUCCESS_MESSAGE,
        variant: 'success'
      }));
      
    } catch (error) { 
      console.error('Error deleting transformation rule:', error);
      this.dispatchEvent(new ShowToastEvent({
        title: LABEL_ERROR_TITLE,
        message: error.body?.message || LABEL_ERROR_DELETE_RULE,
        variant: 'error'
      }));
    }
  }

  get isTransformation() { 
    return this.wiredTransformationResults?.length > 0;
  }

  get hasTransformations() { 
    return this.filteredTransformations.length > 0;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}